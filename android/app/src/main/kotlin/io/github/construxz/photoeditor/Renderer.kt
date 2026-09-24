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
 * The one renderer for preview and export (D-17): geometry and adjustments via AGSL on the GPU,
 * result as an sRGB bitmap. The gain map gets the same geometry ([gainmap]).
 */
object Renderer {
    /** Recipe adjustments (JSON key → uniform), each −1 … 1, 0 = unchanged (spec, stage 1). */
    val ADJUSTMENTS = mapOf(
        "brightness" to "brightness", "contrast" to "contrast", "whitePoint" to "whitePoint",
        "blackPoint" to "blackPoint", "highlights" to "highlights", "shadows" to "shadows",
        "saturation" to "saturation", "warmth" to "warmth", "tint" to "tint",
        "blueTones" to "blueTones", "vignette" to "vignette", "sharpness" to "sharpness",
        "pop" to "pop",
    )

    // Color values arrive in the target's color space (sRGB, not linear). All adjustments at 0 =
    // unchanged. Calibrated against Google Photos at ±1 on the test chart (tool/testchart.py,
    // D-73): most tone adjustments bend the luma L of the sRGB values and carry the colour along
    // as c − L, scaled by q — per channel would shift hues, Google's copies do not.
    private const val AGSL = """
        uniform shader image;
        uniform float2 size; // output in pixels
        uniform float brightness, contrast, whitePoint, blackPoint, highlights, shadows,
                      saturation, warmth, tint, blueTones, vignette, sharpness, pop;
        uniform shader guide;   // Pop: guided-filter a, b in red and green (Pop.guide)
        uniform shader lut;     // filter as a strip (Lut.bitmap)
        uniform float lutSize;  // grid points per axis
        uniform float lutStrength; // 0 = no filter

        // Trilinear: red and green by the bitmap filter within a slice, blue between two slices.
        float3 applyLut(float3 c) {
            float n = lutSize - 1.0, b = c.b * n, b0 = floor(b), b1 = min(b0 + 1.0, n);
            float2 rg = c.rg * n + 0.5;
            float3 lo = lut.eval(float2(b0 * lutSize + rg.x, rg.y)).rgb;
            float3 hi = lut.eval(float2(b1 * lutSize + rg.x, rg.y)).rgb;
            return mix(lo, hi, b - b0);
        }

        float3 toLinear(float3 c) {
            return mix(c / 12.92, pow((c + 0.055) / 1.055, float3(2.4)), step(0.04045, c));
        }
        float3 toSrgb(float3 c) {
            c = max(c, 0.0);
            return mix(c * 12.92, 1.055 * pow(c, float3(1.0 / 2.4)) - 0.055, step(0.0031308, c));
        }
        float luma(float3 c) { return dot(c, float3(0.2126, 0.7152, 0.0722)); }
        float hue(float3 c) { // 0 … 1
            float mx = max(c.r, max(c.g, c.b)), mn = min(c.r, min(c.g, c.b)), d = mx - mn;
            if (d < 1e-5) return 0.0;
            float h = mx == c.r ? mod((c.g - c.b) / d, 6.0) : mx == c.g ? (c.b - c.r) / d + 2.0 : (c.r - c.g) / d + 4.0;
            return h / 6.0;
        }
        // Raising (a > 0) pulls toward 1, lowering toward 0 — never past the edge.
        float3 push(float3 c, float a) { return a >= 0.0 ? c + a * (1.0 - c) : c + a * c; }
        // New luma [to] for [c] (luma [L]), colour scaled by [q].
        float3 relight(float3 c, float L, float to, float q) { return saturate(to + (c - L) * q); }
        // Factor of the one measured end: 1 at v = 0, [end] at |v| = 1.
        float q(float v, float minus, float plus) { return 1.0 + abs(v) * ((v < 0.0 ? minus : plus) - 1.0); }

        half4 main(float2 p) {
            float3 c = image.eval(p).rgb;

            // Sharpness: unsharp mask, radius relative to image size — preview like export.
            if (sharpness != 0.0) {
                float r = max(1.0, max(size.x, size.y) / 2000.0);
                float3 soft = (image.eval(p + float2(r, 0)).rgb + image.eval(p - float2(r, 0)).rgb
                              + image.eval(p + float2(0, r)).rgb + image.eval(p - float2(0, r)).rgb) * 0.25;
                c += (c - soft) * sharpness * 1.5;
            }
            c = saturate(c);

            // Pop: the detail above an edge-preserving blur (a·L + b) raised, plus a little colour.
            if (pop != 0.0) {
                float y = luma(c);
                float2 ab = guide.eval(p).rg;
                c = saturate(c + pop * 1.31 * (y - (ab.x * y + ab.y)));
            }

            // Warmth and tint: a shift strongest in the midtones, black and white stay.
            float L = luma(c);
            float w = pow(L, 1.55) * pow(1.0 - L, 1.19) / 0.1533;
            c = saturate(c + w * (warmth * float3(0.147, -0.021, -0.223) + tint * float3(0.143, -0.056, 0.13)));

            // Black point: lifts (< 0) or cuts (> 0) the shadows, white stays.
            L = luma(c);
            c = relight(c, L, L - blackPoint * (blackPoint < 0.0 ? 0.16 * pow(1.0 - L, 2.07) : 0.504 * pow(1.0 - L, 1.63)),
                        q(blackPoint, 0.768, 1.499));
            // White point: > 0 a straight gain that clips, < 0 dims the highlights, black stays.
            L = luma(c);
            c = relight(c, L, whitePoint >= 0.0 ? L * (1.0 + 0.328 * whitePoint) : L + 0.224 * whitePoint * pow(L, 1.975),
                        q(whitePoint, 0.746, 1.328));

            // Brightness: exposure in linear light, ±2.4 / 2.8 stops; brighter rolls off toward white.
            L = luma(c);
            float yl = toLinear(float3(L)).x, e = exp2(brightness * (brightness < 0.0 ? 2.419 : 2.796));
            yl = brightness < 0.0 ? yl * e : yl * e / (1.0 + yl * (e - 1.0));
            c = relight(c, L, toSrgb(float3(yl)).x, q(brightness, 0.681, 1.202));

            // Shadows and highlights: a bump in the dark or the bright tones, added to all channels.
            L = luma(c);
            c = saturate(c + shadows * 2.661 * L * pow(1.0 - L, 4.46));
            L = luma(c);
            c = saturate(c + highlights * 1.638 * pow(L, 4.525) * (1.0 - L));

            // Contrast: power curves on either side of 0.356, black and white stay.
            L = luma(c);
            float g = pow(contrast < 0.0 ? 0.793 : 1.843, abs(contrast));
            float to = L < 0.356 ? 0.356 * pow(L / 0.356, g) : 1.0 - 0.644 * pow((1.0 - L) / 0.644, g);
            c = relight(c, L, to, q(contrast, 0.898, 1.241));

            // Saturation: less toward the gray of the same luminance (linear light); more lifts
            // the dull colours more than the saturated ones.
            float gray = toSrgb(float3(luma(toLinear(c)))).x;
            float s = clamp(saturation + 0.07 * pop, -1.0, 1.0);
            float k = 1.0 + s * (s < 0.0 ? 1.0 : 1.27 * (1.0 - (max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b)))));
            c = saturate(gray + (c - gray) * k);

            // Blue tones: cyan to azure (184° ± 58°), saturation at the same maximum.
            float band = saturate((0.162 - abs(hue(c) - 0.511)) / 0.09);
            float mx = max(c.r, max(c.g, c.b));
            c = saturate(mx + (c - mx) * (1.0 + blueTones * (blueTones < 0.0 ? 0.5 : 0.72) * band));

            // Filter: a look over the adjusted image; the vignette stays on top.
            if (lutStrength > 0.0) c = mix(c, applyLut(saturate(c)), lutStrength);

            // Vignette: round in pixels, from the center over the half diagonal; darker (> 0) or
            // lighter (< 0). The strength mainly moves where it starts.
            float v = abs(vignette);
            float d = length(p - size * 0.5) / length(size * 0.5);
            float amount = 0.95 * (1.0 - pow(1.0 - v, 4.0)) * smoothstep(0.39 - 0.155 * v, 1.0, d);
            c = push(c, vignette < 0.0 ? amount : -amount);

            return half4(half3(saturate(c)), 1.0);
        }
    """

    private val NO_LUT = Bitmap.createBitmap(4, 2, Bitmap.Config.ARGB_8888)

    /** EXIF orientation (1…8) of the original; BitmapFactory does not set it upright itself. */
    fun orientation(original: ByteArray) = ExifInterface(ByteArrayInputStream(original))
        .getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)

    /** Renders [source] with geometry [geo] and [recipe]; the result is a HARDWARE bitmap. */
    fun render(source: Bitmap, geo: Geometry, recipe: JSONObject): Bitmap {
        val (width, height) = size(geo, source)
        val paint = paint(source, geo, recipe, width, height)
        return draw(width, height) { drawPaint(paint) }
    }

    /**
     * [source] once per recipe, in one pass — a GPU pass costs about 1 s to set up in the
     * emulator, the tiles themselves almost nothing. For the filter thumbnails.
     */
    fun renderTiles(source: Bitmap, geo: Geometry, recipes: List<JSONObject>): List<Bitmap> {
        val (width, height) = size(geo, source)
        val paints = recipes.map { paint(source, geo, it, width, height) }
        val strip = draw(width * recipes.size, height) {
            paints.forEachIndexed { i, p ->
                save(); translate(i * width.toFloat(), 0f)
                drawRect(0f, 0f, width.toFloat(), height.toFloat(), p)
                restore()
            }
        }
        val copy = strip.copy(Bitmap.Config.ARGB_8888, false).also { strip.recycle() }
        return recipes.indices.map { Bitmap.createBitmap(copy, it * width, 0, width, height) }
    }

    private fun paint(source: Bitmap, geo: Geometry, recipe: JSONObject, width: Int, height: Int): Paint {
        val imageShader = BitmapShader(source, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP).apply {
            filterMode = BitmapShader.FILTER_MODE_LINEAR
            setLocalMatrix(matrix(geo, source))
        }
        val shader = RuntimeShader(AGSL).apply {
            setInputShader("image", imageShader)
            setFloatUniform("size", width.toFloat(), height.toFloat())
            for ((key, uniform) in ADJUSTMENTS) {
                setFloatUniform(uniform, recipe.optDouble(key, 0.0).toFloat().coerceIn(-1f, 1f))
            }
            // An unknown filter (recipe from a newer app) is left out rather than failing.
            val filter = recipe.optJSONObject("filter")
            val strip = filter?.optString("id")?.let { Luts.strip(it) }
            val (lut, lutSize) = strip ?: (NO_LUT to 2)
            setInputShader("lut", BitmapShader(lut, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP).apply {
                filterMode = BitmapShader.FILTER_MODE_LINEAR
            })
            setFloatUniform("lutSize", lutSize.toFloat())
            setFloatUniform("lutStrength", if (strip == null) 0f else filter!!.optDouble("strength", 1.0).toFloat().coerceIn(0f, 1f))
            // Pop's coefficients on a small copy, laid over the image with the same geometry.
            val g = if (recipe.optDouble("pop", 0.0) != 0.0) Pop.guide(source) else NO_LUT
            setInputShader("guide", BitmapShader(g, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP).apply {
                filterMode = BitmapShader.FILTER_MODE_LINEAR
                setLocalMatrix(matrix(geo, source).apply { preScale(source.width / g.width.toFloat(), source.height / g.height.toFloat()) })
            })
        }
        return Paint().apply { this.shader = shader }
    }

    private fun draw(width: Int, height: Int, record: android.graphics.RecordingCanvas.() -> Unit): Bitmap {
        val reader = ImageReader.newInstance(
            width, height, PixelFormat.RGBA_8888, 1,
            HardwareBuffer.USAGE_GPU_SAMPLED_IMAGE or HardwareBuffer.USAGE_GPU_COLOR_OUTPUT,
        )
        val node = RenderNode("image").apply { setPosition(0, 0, width, height) }
        node.beginRecording().record()
        node.endRecording()
        val renderer = HardwareRenderer().apply {
            setSurface(reader.surface)
            setContentRoot(node)
        }
        try {
            renderer.createRenderRequest().setWaitForPresent(true).syncAndDraw()
            reader.acquireNextImage().use { image ->
                val buffer = image.hardwareBuffer!!
                return Bitmap.wrapHardwareBuffer(buffer, ColorSpace.get(ColorSpace.Named.SRGB))!!
                    .also { buffer.close() }
            }
        } finally {
            renderer.destroy()
            reader.close()
        }
    }

    /**
     * The gain map [g] with the same geometry as the image, at its own resolution. Small
     * enough for the CPU; the HDR parameters stay as they are.
     */
    fun gainmap(g: Gainmap, geo: Geometry): Gainmap {
        if (geo.isNeutral) return g
        val q = g.gainmapContents
        val (width, height) = size(geo, q)
        val target = Bitmap.createBitmap(width, height, q.config ?: Bitmap.Config.ARGB_8888)
        Canvas(target).drawBitmap(q, matrix(geo, q), Paint(Paint.FILTER_BITMAP_FLAG))
        return Gainmap(target).apply {
            g.ratioMin.let { setRatioMin(it[0], it[1], it[2]) }
            g.ratioMax.let { setRatioMax(it[0], it[1], it[2]) }
            g.gamma.let { setGamma(it[0], it[1], it[2]) }
            g.epsilonSdr.let { setEpsilonSdr(it[0], it[1], it[2]) }
            g.epsilonHdr.let { setEpsilonHdr(it[0], it[1], it[2]) }
            minDisplayRatioForHdrTransition = g.minDisplayRatioForHdrTransition
            displayRatioForFullHdr = g.displayRatioForFullHdr
        }
    }

    private fun size(geo: Geometry, b: Bitmap): Pair<Int, Int> {
        val (w, h) = geo.output(b.width.toDouble(), b.height.toDouble())
        return max(1, w.roundToInt()) to max(1, h.roundToInt())
    }

    private fun matrix(geo: Geometry, b: Bitmap) = Matrix().apply {
        setValues(geo.matrix(b.width.toDouble(), b.height.toDouble()).map { it.toFloat() }.toFloatArray())
    }
}
