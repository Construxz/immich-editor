package io.github.construxz.photoeditor

import android.graphics.Bitmap
import android.graphics.BitmapShader
import android.graphics.ColorSpace
import android.graphics.HardwareRenderer
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.RenderNode
import android.graphics.RuntimeShader
import android.graphics.Shader
import android.hardware.HardwareBuffer
import android.media.ImageReader
import org.json.JSONObject

/**
 * Der eine Renderer für Vorschau und Export (D-17): wendet das Rezept per AGSL auf der GPU an
 * und rendert in eine sRGB-Bitmap. Die Gain-Map hängt der Aufrufer an das Ergebnis.
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

    /** Rendert [quelle] mit [rezept] in [breite]×[hoehe]; das Ergebnis ist eine HARDWARE-Bitmap. */
    fun rendern(quelle: Bitmap, rezept: JSONObject, breite: Int, hoehe: Int): Bitmap {
        val bildShader = BitmapShader(quelle, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP).apply {
            filterMode = BitmapShader.FILTER_MODE_LINEAR
            setLocalMatrix(Matrix().apply {
                setScale(breite / quelle.width.toFloat(), hoehe / quelle.height.toFloat())
            })
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
}
