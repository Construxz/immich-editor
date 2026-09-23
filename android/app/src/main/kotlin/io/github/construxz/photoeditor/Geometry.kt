package io.github.construxz.photoeditor

import org.json.JSONObject
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.sin

/**
 * Geometry of a recipe, in this order: quarter turns clockwise, flip (horizontal, as seen),
 * straighten by [angle] degrees with automatic zoom so no empty corners appear, finally [crop]
 * (x, y, width, height; 0…1 in the rotated frame).
 *
 * Pure math without Android classes — image and gain map get the same matrix (D-17).
 */
data class Geometry(
    val quarterTurns: Int = 0,
    val flip: Boolean = false,
    val angle: Double = 0.0,
    val crop: List<Double> = listOf(0.0, 0.0, 1.0, 1.0),
) {
    val isNeutral get() = quarterTurns % 4 == 0 && !flip && angle == 0.0 && crop == listOf(0.0, 0.0, 1.0, 1.0)

    /** Frame after the quarter turns, for a source [w]×[h]. */
    fun frame(w: Double, h: Double) = if (quarterTurns % 2 == 1) h to w else w to h

    /** Output size in source pixels. */
    fun output(w: Double, h: Double): Pair<Double, Double> {
        val (fw, fh) = frame(w, h)
        return fw * crop[2] to fh * crop[3]
    }

    /** Matrix source → output (3×3, row-major, for column vectors) for a source [w]×[h]. */
    fun matrix(w: Double, h: Double): DoubleArray {
        val (fw, fh) = frame(w, h)
        var m = translation(-w / 2, -h / 2)
        m = multiply(rotation(90.0 * (quarterTurns % 4)), m)
        if (flip) m = multiply(scaling(-1.0, 1.0), m)
        m = multiply(scaling(coverage(fw, fh), coverage(fw, fh)), m)
        m = multiply(rotation(angle), m)
        m = multiply(translation(fw / 2 - crop[0] * fw, fh / 2 - crop[1] * fh), m)
        return m
    }

    /** Zoom at which the image rotated by [angle] fully covers the frame [fw]×[fh]. */
    private fun coverage(fw: Double, fh: Double): Double {
        val a = Math.toRadians(abs(angle))
        return max((fw * cos(a) + fh * sin(a)) / fw, (fw * sin(a) + fh * cos(a)) / fh)
    }

    /**
     * Puts this geometry on top of the original's EXIF [orientation] (1…8): first the image is
     * set upright, then what the user set applies. A flip before a rotation reverses its
     * direction (F·R(q) = R(−q)·F).
     */
    fun afterExif(orientation: Int): Geometry {
        val (qb, fb) = when (orientation) {
            2 -> 0 to true
            3 -> 2 to false
            4 -> 2 to true
            5 -> 1 to true
            6 -> 1 to false
            7 -> 3 to true
            8 -> 3 to false
            else -> 0 to false
        }
        val q = (qb + if (fb) -quarterTurns else quarterTurns).mod(4)
        return copy(quarterTurns = q, flip = fb != flip)
    }

    companion object {
        fun from(recipe: JSONObject): Geometry {
            val g = recipe.optJSONObject("geometry") ?: return Geometry()
            val c = g.optJSONArray("crop")
            return Geometry(
                quarterTurns = g.optInt("quarterTurns", 0),
                flip = g.optBoolean("flip", false),
                angle = g.optDouble("angle", 0.0),
                crop = if (c == null) listOf(0.0, 0.0, 1.0, 1.0) else List(4) { c.getDouble(it) },
            )
        }

        fun translation(x: Double, y: Double) = doubleArrayOf(1.0, 0.0, x, 0.0, 1.0, y, 0.0, 0.0, 1.0)
        fun scaling(x: Double, y: Double) = doubleArrayOf(x, 0.0, 0.0, 0.0, y, 0.0, 0.0, 0.0, 1.0)

        /** Rotation by [degrees] clockwise (y points down). */
        fun rotation(degrees: Double): DoubleArray {
            val r = Math.toRadians(degrees)
            val c = cos(r)
            val s = sin(r)
            return doubleArrayOf(c, -s, 0.0, s, c, 0.0, 0.0, 0.0, 1.0)
        }

        fun multiply(a: DoubleArray, b: DoubleArray) = DoubleArray(9) { i ->
            val row = i / 3
            val col = i % 3
            a[row * 3] * b[col] + a[row * 3 + 1] * b[3 + col] + a[row * 3 + 2] * b[6 + col]
        }

        fun transform(m: DoubleArray, x: Double, y: Double) =
            (m[0] * x + m[1] * y + m[2]) to (m[3] * x + m[4] * y + m[5])
    }
}
