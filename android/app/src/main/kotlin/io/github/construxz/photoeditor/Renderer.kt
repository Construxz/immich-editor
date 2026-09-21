package io.github.construxz.photoeditor

import android.graphics.Bitmap
import android.graphics.BitmapShader
import android.graphics.Canvas
import android.graphics.ColorSpace
import android.graphics.Gainmap
import android.graphics.HardwareRenderer
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.RenderNode
import android.graphics.RuntimeShader
import android.graphics.Shader
import android.hardware.HardwareBuffer
import android.media.ExifInterface
import android.media.ImageReader
import org.json.JSONObject
import java.io.ByteArrayInputStream
import kotlin.math.max
import kotlin.math.roundToInt

/**
 * Der eine Renderer für Vorschau und Export (D-17): Geometrie und Rezept per AGSL auf der GPU,
 * Ergebnis als sRGB-Bitmap. Die Gain-Map bekommt dieselbe Geometrie ([gainmap]).
 */
object Renderer {
    // Farbwerte kommen im Farbraum des Ziels (sRGB, nicht linear) an — wie in M1 (D-12).
    private const val AGSL = """
        uniform shader bild;
        uniform float helligkeit;

        half4 main(float2 p) {
            half4 c = bild.eval(p);
            c.rgb = saturate(c.rgb + half(helligkeit * 128.0 / 255.0));
            return c;
        }
    """

    /** EXIF-Orientierung (1…8) des Originals; BitmapFactory richtet nicht selbst auf. */
    fun orientierung(original: ByteArray) = ExifInterface(ByteArrayInputStream(original))
        .getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)

    /** Rendert [quelle] mit Geometrie [geo] und [rezept]; das Ergebnis ist eine HARDWARE-Bitmap. */
    fun rendern(quelle: Bitmap, geo: Geometrie, rezept: JSONObject): Bitmap {
        val (breite, hoehe) = groesse(geo, quelle)
        val bildShader = BitmapShader(quelle, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP).apply {
            filterMode = BitmapShader.FILTER_MODE_LINEAR
            setLocalMatrix(matrix(geo, quelle))
        }
        val shader = RuntimeShader(AGSL).apply {
            setInputShader("bild", bildShader)
            setFloatUniform("helligkeit", rezept.optDouble("brightness", 0.0).toFloat())
        }

        val reader = ImageReader.newInstance(
            breite, hoehe, PixelFormat.RGBA_8888, 1,
            HardwareBuffer.USAGE_GPU_SAMPLED_IMAGE or HardwareBuffer.USAGE_GPU_COLOR_OUTPUT,
        )
        val knoten = RenderNode("bild").apply { setPosition(0, 0, breite, hoehe) }
        knoten.beginRecording().drawPaint(Paint().apply { this.shader = shader })
        knoten.endRecording()
        val renderer = HardwareRenderer().apply {
            setSurface(reader.surface)
            setContentRoot(knoten)
        }
        try {
            renderer.createRenderRequest().setWaitForPresent(true).syncAndDraw()
            reader.acquireNextImage().use { bild ->
                val puffer = bild.hardwareBuffer!!
                return Bitmap.wrapHardwareBuffer(puffer, ColorSpace.get(ColorSpace.Named.SRGB))!!
                    .also { puffer.close() }
            }
        } finally {
            renderer.destroy()
            reader.close()
        }
    }

    /**
     * Die Gain-Map [g] mit derselben Geometrie wie das Bild, in ihrer eigenen Auflösung. Klein
     * genug für die CPU; die HDR-Kennwerte bleiben, wie sie sind.
     */
    fun gainmap(g: Gainmap, geo: Geometrie): Gainmap {
        if (geo.istNeutral) return g
        val q = g.gainmapContents
        val (breite, hoehe) = groesse(geo, q)
        val ziel = Bitmap.createBitmap(breite, hoehe, q.config ?: Bitmap.Config.ARGB_8888)
        Canvas(ziel).drawBitmap(q, matrix(geo, q), Paint(Paint.FILTER_BITMAP_FLAG))
        return Gainmap(ziel).apply {
            g.ratioMin.let { setRatioMin(it[0], it[1], it[2]) }
            g.ratioMax.let { setRatioMax(it[0], it[1], it[2]) }
            g.gamma.let { setGamma(it[0], it[1], it[2]) }
            g.epsilonSdr.let { setEpsilonSdr(it[0], it[1], it[2]) }
            g.epsilonHdr.let { setEpsilonHdr(it[0], it[1], it[2]) }
            minDisplayRatioForHdrTransition = g.minDisplayRatioForHdrTransition
            displayRatioForFullHdr = g.displayRatioForFullHdr
        }
    }

    private fun groesse(geo: Geometrie, b: Bitmap): Pair<Int, Int> {
        val (w, h) = geo.ausgabe(b.width.toDouble(), b.height.toDouble())
        return max(1, w.roundToInt()) to max(1, h.roundToInt())
    }

    private fun matrix(geo: Geometrie, b: Bitmap) = Matrix().apply {
        setValues(geo.matrix(b.width.toDouble(), b.height.toDouble()).map { it.toFloat() }.toFloatArray())
    }
}
