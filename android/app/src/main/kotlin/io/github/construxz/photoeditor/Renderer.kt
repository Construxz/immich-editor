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
 * Der eine Renderer für Vorschau und Export (D-17): Geometrie und Regler per AGSL auf der GPU,
 * Ergebnis als sRGB-Bitmap. Die Gain-Map bekommt dieselbe Geometrie ([gainmap]).
 */
object Renderer {
    /** Regler des Rezepts (JSON-Schlüssel → Uniform), je −1 … 1, 0 = unverändert (Spec, Stufe 1). */
    val REGLER = mapOf(
        "brightness" to "helligkeit", "contrast" to "kontrast", "whitePoint" to "weiss",
        "blackPoint" to "schwarz", "highlights" to "lichter", "shadows" to "tiefen",
        "saturation" to "saettigung", "warmth" to "waerme", "tint" to "faerbung",
        "blueTones" to "blau", "vignette" to "vignette", "sharpness" to "schaerfe",
    )

    // Farbwerte kommen im Farbraum des Ziels an (sRGB, nicht linear). Weißabgleich rechnet in
    // linearem Licht, Tonwerte in der wahrgenommenen Helligkeit. Alle Regler auf 0 = unverändert.
    private const val AGSL = """
        uniform shader bild;
        uniform float2 groesse; // Ausgabe in Pixeln
        uniform float helligkeit, kontrast, weiss, schwarz, lichter, tiefen,
                      saettigung, waerme, faerbung, blau, vignette, schaerfe;

        float3 zuLinear(float3 c) {
            return mix(c / 12.92, pow((c + 0.055) / 1.055, float3(2.4)), step(0.04045, c));
        }
        float3 zuSrgb(float3 c) {
            c = max(c, 0.0);
            return mix(c * 12.92, 1.055 * pow(c, float3(1.0 / 2.4)) - 0.055, step(0.0031308, c));
        }
        float luma(float3 c) { return dot(c, float3(0.2126, 0.7152, 0.0722)); }
        float farbton(float3 c) { // 0 … 1
            float mx = max(c.r, max(c.g, c.b)), mn = min(c.r, min(c.g, c.b)), d = mx - mn;
            if (d < 1e-5) return 0.0;
            float h = mx == c.r ? mod((c.g - c.b) / d, 6.0) : mx == c.g ? (c.b - c.r) / d + 2.0 : (c.r - c.g) / d + 4.0;
            return h / 6.0;
        }
        // Anheben (a > 0) zieht Richtung 1, Absenken Richtung 0 — nie über den Rand hinaus.
        float3 schieben(float3 c, float a) { return a >= 0.0 ? c + a * (1.0 - c) : c + a * c; }

        half4 main(float2 p) {
            float3 c = bild.eval(p).rgb;

            // Schärfe: Unscharfmaske, Radius relativ zur Bildgröße — Vorschau wie Export.
            if (schaerfe != 0.0) {
                float r = max(1.0, max(groesse.x, groesse.y) / 2000.0);
                float3 weich = (bild.eval(p + float2(r, 0)).rgb + bild.eval(p - float2(r, 0)).rgb
                              + bild.eval(p + float2(0, r)).rgb + bild.eval(p - float2(0, r)).rgb) * 0.25;
                c += (c - weich) * schaerfe * 1.5;
            }

            // Wärme und Färbung in linearem Licht.
            float3 l = zuLinear(saturate(c)) * float3(1.0 + 0.15 * waerme, 1.0 - 0.15 * faerbung, 1.0 - 0.15 * waerme);
            c = zuSrgb(l);

            // Weiß- und Schwarzpunkt.
            float sp = 0.15 * schwarz, wp = 1.0 - 0.15 * weiss;
            c = saturate((c - sp) / (wp - sp));

            // Helligkeit: Mitteltöne, Enden bleiben.
            c = pow(c, float3(exp2(-helligkeit)));

            // Spitzlichter und Schatten nach Luminanz.
            float L = luma(c);
            c = schieben(c, 0.35 * tiefen * (1.0 - smoothstep(0.0, 0.6, L)));
            c = schieben(c, 0.35 * lichter * smoothstep(0.4, 1.0, L));

            // Kontrast: S-Kurve (mehr) oder zur Mitte hin (weniger).
            c = kontrast >= 0.0 ? mix(c, c * c * (3.0 - 2.0 * c), kontrast) : 0.5 + (c - 0.5) * (1.0 + 0.6 * kontrast);

            // Sättigung; Blautöne nur um den Farbton Blau.
            L = luma(c);
            c = mix(float3(L), c, 1.0 + saettigung);
            float nahBlau = saturate(1.0 - abs(farbton(c) - 0.6) * 8.0);
            c = mix(float3(luma(c)), c, 1.0 + blau * nahBlau);

            // Vignette: Ecken dunkler (> 0) oder heller (< 0).
            float d = length((p / groesse - 0.5) * 2.0) / 1.41421356;
            c = schieben(c, -0.8 * vignette * smoothstep(0.35, 1.0, d));

            return half4(half3(saturate(c)), 1.0);
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
            setFloatUniform("groesse", breite.toFloat(), hoehe.toFloat())
            for ((schluessel, uniform) in REGLER) {
                setFloatUniform(uniform, rezept.optDouble(schluessel, 0.0).toFloat().coerceIn(-1f, 1f))
            }
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
