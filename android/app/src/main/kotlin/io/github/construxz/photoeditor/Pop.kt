package io.github.construxz.photoeditor

import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.ColorSpace
import android.util.Half
import java.nio.ShortBuffer
import kotlin.math.max
import kotlin.math.roundToInt

/**
 * "Pop" (D-75): local contrast like Google Photos — the detail above an edge-preserving blur
 * (guided filter) is raised, edges keep no halo. The filter runs on a small copy of the photo;
 * the renderer spreads its coefficients over the full image ("fast guided filter", He & Sun 2015),
 * so preview and export agree.
 */
object Pop {
    private const val EDGE = 512      // long edge of the small copy
    private const val RADIUS = 0.02   // of the long edge — measured against Google's copies
    private const val EPS = 0.01f

    /**
     * Guided filter of [y] (w × h, 0 … 1) on itself: per pixel a, b with blur ≈ a·y + b,
     * both already box-averaged — the renderer only interpolates them.
     */
    fun coefficients(y: FloatArray, w: Int, h: Int, r: Int, eps: Float): Pair<FloatArray, FloatArray> {
        val mean = box(y, w, h, r)
        val sq = box(FloatArray(y.size) { y[it] * y[it] }, w, h, r)
        val a = FloatArray(y.size) { val v = sq[it] - mean[it] * mean[it]; v / (v + eps) }
        val b = FloatArray(y.size) { mean[it] - a[it] * mean[it] }
        return box(a, w, h, r) to box(b, w, h, r)
    }

    /** a in red, b in green of a half-float bitmap the size of the small copy of [source]. */
    fun guide(source: Bitmap): Bitmap {
        val k = EDGE.toFloat() / max(source.width, source.height)
        val small = if (k >= 1f) source else
            Bitmap.createScaledBitmap(source, max(1, (source.width * k).roundToInt()), max(1, (source.height * k).roundToInt()), true)
        val sw = if (small.config == Bitmap.Config.HARDWARE) small.copy(Bitmap.Config.ARGB_8888, false) else small
        val w = sw.width; val h = sw.height
        val px = IntArray(w * h).also { sw.getPixels(it, 0, w, 0, 0, w, h) }
        val y = FloatArray(px.size) {
            val p = px[it]
            (0.2126f * Color.red(p) + 0.7152f * Color.green(p) + 0.0722f * Color.blue(p)) / 255f
        }
        val (a, b) = coefficients(y, w, h, max(1, (RADIUS * max(w, h)).roundToInt()), EPS)
        val one = Half.toHalf(1f)
        val buffer = ShortBuffer.allocate(w * h * 4)
        for (i in a.indices) buffer.put(Half.toHalf(a[i])).put(Half.toHalf(b[i])).put(0).put(one)
        // sRGB-encoded like the target, so the renderer reads a and b unconverted (F16 defaults to linear).
        return Bitmap.createBitmap(w, h, Bitmap.Config.RGBA_F16, true, ColorSpace.get(ColorSpace.Named.EXTENDED_SRGB))
            .apply { copyPixelsFromBuffer(buffer.rewind()) }
    }

    /** Mean over the (2r+1)² box, clamped at the borders — via running sums, O(n). */
    private fun box(v: FloatArray, w: Int, h: Int, r: Int): FloatArray {
        val tmp = FloatArray(v.size)
        for (y in 0 until h) runningMean(v, tmp, y * w, 1, w, r)
        val out = FloatArray(v.size)
        for (x in 0 until w) runningMean(tmp, out, x, w, h, r)
        return out
    }

    private fun runningMean(src: FloatArray, dst: FloatArray, start: Int, step: Int, n: Int, r: Int) {
        var sum = 0.0
        var count = 0
        for (i in 0..minOf(r, n - 1)) { sum += src[start + i * step]; count++ }
        for (i in 0 until n) {
            dst[start + i * step] = (sum / count).toFloat()
            val add = i + r + 1; val drop = i - r
            if (add < n) { sum += src[start + add * step]; count++ }
            if (drop >= 0) { sum -= src[start + drop * step]; count-- }
        }
    }
}
