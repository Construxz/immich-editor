package io.github.construxz.photoeditor

import kotlin.math.abs
import kotlin.math.ln
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.roundToInt

/**
 * "Optimieren" (D-70): reads a photo and sets the existing adjustments — nothing generated.
 * The formulas mirror [Renderer] (D-73): black point bends the shadows, white point is a gain,
 * brightness an exposure in linear light, warmth and tint shift the midtones in sRGB. A well
 * exposed, neutral photo gets nothing.
 */
object Optimize {
    /** Adjustments (recipe key → −1 … 1) for sRGB pixels [argb] (a downscaled photo is enough). */
    fun adjustments(argb: IntArray): Map<String, Double> {
        val n = argb.size
        if (n == 0) return emptyMap()
        val luma = DoubleArray(n)
        var r = 0.0; var g = 0.0; var b = 0.0; var grays = 0
        for ((i, p) in argb.withIndex()) {
            val red = (p shr 16 and 255) / 255.0
            val green = (p shr 8 and 255) / 255.0
            val blue = (p and 255) / 255.0
            val l = 0.2126 * red + 0.7152 * green + 0.0722 * blue
            luma[i] = l
            // White balance only from nearly gray pixels, so a red sunset stays red.
            if (l in 0.15..0.9 && max(red, max(green, blue)) - min(red, min(green, blue)) < 0.2) {
                r += linear(red); g += linear(green); b += linear(blue); grays++
            }
        }
        luma.sort()
        val lo = luma[(n * 0.005).toInt()]
        val hi = luma[min(n - 1, (n * 0.995).toInt())]

        // Levels: the darkest and brightest 0.5 % halfway toward black and white — a flat but
        // fine photo stays close, a dark one still gets the full range.
        val blackPoint = ((lo - 0.02) / 2 / (0.504 * (1 - lo).pow(1.63))).coerceIn(0.0, 1.0)
        val whitePoint = ((0.98 - hi) / 2 / (0.328 * max(black(hi, blackPoint), 0.01))).coerceIn(0.0, 1.0)

        // Brightness: only a median outside 0.35 … 0.6 moves, most of the way.
        val m = (black(luma[n / 2], blackPoint) * (1 + 0.328 * whitePoint)).coerceIn(0.01, 0.99)
        val y = linear(m)
        val t = linear(m.coerceIn(0.35, 0.6))
        val brightness = (0.7 * when {
            t < y -> -log2(y / t) / 2.419
            t > y -> log2(t * (1 - y) / (y * (1 - t))) / 2.796
            else -> 0.0
        }).coerceIn(-0.6, 0.6)

        // White balance over the gray pixels, only outside a natural range: R/B 1.0 … 1.25
        // (neutral to sunny warm), G 0.95 … 1.1 of the R-B mean — plain gray world would cool a
        // warm evening. Beyond the range, back to its edge. Fewer than 5 % gray pixels: colours stay.
        var warmth = 0.0; var tint = 0.0
        if (grays >= n * 0.05) {
            val gray = doubleArrayOf(srgb(r / grays), srgb(g / grays), srgb(b / grays))
            fun shifted(w: Double, t: Double) = shift(gray, w, t).map(::linear)
            fun redBlue(w: Double) = shifted(w, 0.0).let { it[0] / it[2] }
            val k = redBlue(0.0)
            if (k !in 1.0..1.25) warmth = solve { redBlue(it) - k.coerceIn(1.0, 1.25) }
            fun green(t: Double) = shifted(warmth, t).let { it[1] / ((it[0] + it[2]) / 2) }
            val gr = green(0.0)
            if (gr !in 0.95..1.1) tint = solve { green(it) - gr.coerceIn(0.95, 1.1) }
            warmth = warmth.coerceIn(-0.6, 0.6); tint = tint.coerceIn(-0.6, 0.6)
        }

        return mapOf(
            "blackPoint" to blackPoint, "whitePoint" to whitePoint, "brightness" to brightness,
            "warmth" to warmth, "tint" to tint,
        ).mapValues { (it.value * 100).roundToInt() / 100.0 }.filterValues { abs(it) >= 0.03 }
    }

    /** Renderer's black point on luma [l]. */
    private fun black(l: Double, v: Double) = l - v * 0.504 * (1 - l).pow(1.63)

    /** Renderer's warmth [w] and tint [t] on the sRGB colour [c]. */
    private fun shift(c: DoubleArray, w: Double, t: Double): List<Double> {
        val l = (0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]).coerceIn(0.0, 1.0)
        val weight = l.pow(1.55) * (1 - l).pow(1.19) / 0.1533
        val d = doubleArrayOf(0.147 * w + 0.143 * t, -0.021 * w - 0.056 * t, -0.223 * w + 0.13 * t)
        return c.indices.map { (c[it] + weight * d[it]).coerceIn(0.0, 1.0) }
    }

    /** v in −1 … 1 where the monotone [f] crosses 0 (bisection; the nearer end if it does not). */
    private fun solve(f: (Double) -> Double): Double {
        var a = -1.0; var b = 1.0
        val rising = f(b) > f(a)
        repeat(30) { val m = (a + b) / 2; if ((f(m) < 0) == rising) a = m else b = m }
        return (a + b) / 2
    }

    private fun linear(c: Double) = if (c <= 0.04045) c / 12.92 else ((c + 0.055) / 1.055).pow(2.4)
    private fun srgb(c: Double) = if (c <= 0.0031308) c * 12.92 else 1.055 * c.pow(1 / 2.4) - 0.055
    private fun log2(x: Double) = ln(x) / ln(2.0)
}
