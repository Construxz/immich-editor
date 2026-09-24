package io.github.construxz.photoeditor

import kotlin.math.abs
import kotlin.math.ln
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.roundToInt

/**
 * "Optimieren" (D-70): reads a photo and sets the existing adjustments — nothing generated.
 * The formulas mirror [Renderer]: black and white point stretch the tones, brightness is a gamma
 * on the midtones, warmth and tint scale R/B and G in linear light. A well exposed, neutral photo
 * gets nothing.
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

        // Levels: the darkest and brightest 0.5 % halfway toward black and white (Renderer:
        // 0.15 × value) — a flat but fine photo stays close, a dark one still gets the full range.
        val blackPoint = ((lo - 0.02) / 0.15 * 0.5).coerceIn(0.0, 1.0)
        val whitePoint = ((0.98 - hi) / 0.15 * 0.5).coerceIn(0.0, 1.0)
        val bp = 0.15 * blackPoint
        val wp = 1 - 0.15 * whitePoint

        // Brightness (Renderer: c^(2^−b)): only a median outside 0.35 … 0.6 moves, halfway-ish.
        val m = ((luma[n / 2] - bp) / (wp - bp)).coerceIn(0.01, 0.99)
        val target = m.coerceIn(0.35, 0.6)
        val brightness = (-log2(ln(target) / ln(m)) * 0.7).coerceIn(-0.6, 0.6)

        // White balance over the gray pixels, only outside a natural range: R/B 1.0 … 1.25
        // (neutral to sunny warm), G 0.95 … 1.1 of the R-B mean — plain gray world would cool a
        // warm evening. Beyond the range, back to its edge (Renderer: R × (1 + 0.15 w),
        // B × (1 − 0.15 w), G × (1 − 0.15 t)). Fewer than 5 % gray pixels: colours stay.
        var warmth = 0.0; var tint = 0.0
        if (grays >= n * 0.05) {
            val k = (r / b).coerceIn(1.0, 1.25) * b / r // R/B must change by this factor
            warmth = ((k - 1) / (0.15 * (1 + k))).coerceIn(-0.6, 0.6)
            val green = g / ((r + b) / 2)
            tint = ((1 - green.coerceIn(0.95, 1.1) / green) / 0.15).coerceIn(-0.6, 0.6)
        }

        return mapOf(
            "blackPoint" to blackPoint, "whitePoint" to whitePoint, "brightness" to brightness,
            "warmth" to warmth, "tint" to tint,
        ).mapValues { (it.value * 100).roundToInt() / 100.0 }.filterValues { abs(it) >= 0.03 }
    }

    private fun linear(c: Double) = if (c <= 0.04045) c / 12.92 else ((c + 0.055) / 1.055).pow(2.4)
    private fun log2(x: Double) = ln(x) / ln(2.0)
}
