package io.github.construxz.photoeditor

import android.content.res.AssetManager
import android.graphics.Bitmap
import android.graphics.Color

/**
 * A 3D LUT from a `.cube` file: [size]³ RGB values 0 … 1, red varying fastest, then green,
 * then blue (Adobe's format; DOMAIN_MIN/MAX other than 0/1 is not supported).
 */
class Lut(val size: Int, val values: FloatArray) {
    /**
     * As a strip for the shader: [size] slices side by side, one per blue step; within a slice
     * x = red, y = green.
     */
    fun bitmap(): Bitmap {
        val pixels = IntArray(size * size * size)
        for (b in 0 until size) for (g in 0 until size) for (r in 0 until size) {
            val i = 3 * (r + size * (g + size * b))
            pixels[g * size * size + b * size + r] = Color.rgb(
                (values[i] * 255 + 0.5f).toInt(), (values[i + 1] * 255 + 0.5f).toInt(),
                (values[i + 2] * 255 + 0.5f).toInt(),
            )
        }
        return Bitmap.createBitmap(pixels, size * size, size, Bitmap.Config.ARGB_8888)
    }

    companion object {
        fun parse(text: String): Lut {
            var size = 0
            var values = FloatArray(0)
            var n = 0
            for (raw in text.lineSequence()) {
                val line = raw.trim()
                if (line.isEmpty() || line.startsWith("#")) continue
                val first = line[0]
                if (first.isDigit() || first == '-' || first == '.') {
                    for (v in line.split(' ', '\t')) {
                        if (v.isEmpty()) continue
                        require(n < values.size) { "more values than LUT_3D_SIZE allows" }
                        values[n++] = v.toFloat().coerceIn(0f, 1f)
                    }
                } else if (line.startsWith("LUT_3D_SIZE")) {
                    size = line.substringAfter("LUT_3D_SIZE").trim().toInt()
                    require(size in 2..64) { "LUT_3D_SIZE $size" }
                    values = FloatArray(3 * size * size * size)
                }
            }
            require(size > 0 && n == values.size) { "not a 3D LUT: size $size, $n values" }
            return Lut(size, values)
        }
    }
}

/** The built-in filters (assets/luts, from tool/make_luts.py), loaded once each. */
object Luts {
    lateinit var assets: AssetManager
    private val cache = mutableMapOf<String, Bitmap>()

    /** Strip and size of filter [id], or null if the app does not know it (newer recipe). */
    @Synchronized
    fun strip(id: String): Pair<Bitmap, Int>? {
        cache[id]?.let { return it to it.height }
        val lut = try {
            assets.open("luts/$id.cube").use { Lut.parse(it.reader().readText()) }
        } catch (_: java.io.IOException) {
            return null
        }
        return lut.bitmap().also { cache[id] = it } to lut.size
    }
}
