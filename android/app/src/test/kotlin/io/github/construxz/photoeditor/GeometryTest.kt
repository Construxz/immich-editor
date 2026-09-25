package io.github.construxz.photoeditor

import io.github.construxz.photoeditor.Geometry.Companion.transform
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.max

class GeometryTest {
    private val w = 400.0
    private val h = 200.0

    private fun point(g: Geometry, x: Double, y: Double): Pair<Double, Double> {
        val (px, py) = transform(g.matrix(w, h), x, y)
        return Math.round(px * 1e6) / 1e6 to Math.round(py * 1e6) / 1e6
    }

    @Test fun neutral() {
        val g = Geometry()
        assertTrue(g.isNeutral)
        assertEquals(0.0 to 0.0, point(g, 0.0, 0.0))
        assertEquals(w to h, point(g, w, h))
        assertEquals(w to h, g.output(w, h))
    }

    @Test fun foreignRecipeHeldToRanges() { // D-78: no giant bitmap from a crafted recipe
        val g = Geometry.from(org.json.JSONObject(
            """{"geometry":{"quarterTurns":-3,"angle":1000,"crop":[0,0,1000,1000]}}""",
        ))
        assertEquals(1, g.quarterTurns)
        assertEquals(45.0, g.angle, 0.0)
        assertEquals(listOf(0.0, 0.0, 1.0, 1.0), g.crop)
        val short = Geometry.from(org.json.JSONObject("""{"geometry":{"crop":[0.1,0.2]}}"""))
        assertEquals(listOf(0.0, 0.0, 1.0, 1.0), short.crop)
        val fine = Geometry.from(org.json.JSONObject("""{"geometry":{"crop":[0.25,0,0.5,1]}}"""))
        assertEquals(listOf(0.25, 0.0, 0.5, 1.0), fine.crop)
    }

    @Test fun quarterTurnClockwise() {
        val g = Geometry(quarterTurns = 1)
        assertEquals(h to w, g.output(w, h))
        assertEquals(h to 0.0, point(g, 0.0, 0.0)) // top left → top right
        assertEquals(0.0 to w, point(g, w, h)) // bottom right → bottom left
    }

    @Test fun flipHorizontal() {
        val g = Geometry(flip = true)
        assertEquals(w to 0.0, point(g, 0.0, 0.0))
        assertEquals(0.0 to h, point(g, w, h))
    }

    @Test fun flipActsOnTheRotatedView() {
        // rotate first, then flip as seen: top left lands top left
        val g = Geometry(quarterTurns = 1, flip = true)
        assertEquals(0.0 to 0.0, point(g, 0.0, 0.0))
    }

    @Test fun crop() {
        val g = Geometry(crop = listOf(0.25, 0.5, 0.5, 0.5))
        assertEquals(200.0 to 100.0, g.output(w, h))
        assertEquals(0.0 to 0.0, point(g, 100.0, 100.0)) // crop corner → output origin
    }

    @Test fun straighteningLeavesNoEmptyCorners() {
        for (angle in listOf(-45.0, -10.0, 3.0, 30.0)) {
            val g = Geometry(angle = angle)
            val m = g.matrix(w, h)
            // output corners back into the source: they must lie inside the image
            val inv = inverse(m)
            for ((x, y) in listOf(0.0 to 0.0, w to 0.0, 0.0 to h, w to h)) {
                val (qx, qy) = transform(inv, x, y)
                assertTrue("$angle°: ($qx, $qy)", qx >= -1e-6 && qx <= w + 1e-6 && qy >= -1e-6 && qy <= h + 1e-6)
            }
            // and zoomed no more than needed: one corner lies on the edge
            val edge = listOf(0.0 to 0.0, w to 0.0, 0.0 to h, w to h).minOf { (x, y) ->
                val (qx, qy) = transform(inv, x, y); minOf(qx, w - qx, qy, h - qy)
            }
            assertEquals(0.0, max(edge, 0.0), 1e-6)
        }
    }

    @Test fun fromJson() {
        val g = Geometry.from(org.json.JSONObject("""{"v":1,"geometry":{"quarterTurns":3,"flip":true,"angle":-2.5,"crop":[0.1,0.2,0.3,0.4]}}"""))
        assertEquals(Geometry(3, true, -2.5, listOf(0.1, 0.2, 0.3, 0.4)), g)
    }

    @Test fun exifOrientationSetsUpright() {
        // stored 400×200, EXIF 6: shown as 200×400, top left lands top right
        val g = Geometry().afterExif(6)
        assertEquals(h to w, g.output(w, h))
        assertEquals(h to 0.0, point(g, 0.0, 0.0))
        // EXIF 5 (transpose): (x, y) → (y, x)
        assertEquals(50.0 to 10.0, point(Geometry().afterExif(5), 10.0, 50.0))
        // EXIF 7 (transverse): (x, y) → (h − y, w − x)
        assertEquals(150.0 to 390.0, point(Geometry().afterExif(7), 10.0, 50.0))
        assertEquals(Geometry(), Geometry().afterExif(1))
    }

    @Test fun userRotationAfterExif() {
        // EXIF 6 plus one user quarter turn = half turn of the stored image
        assertEquals(point(Geometry(quarterTurns = 2), 10.0, 50.0), point(Geometry(quarterTurns = 1).afterExif(6), 10.0, 50.0))
        // flipped original (EXIF 2), user rotates: what is seen rotates clockwise
        val seen = Geometry(quarterTurns = 1).afterExif(2)
        val expected = Geometry.multiply(Geometry.multiply(Geometry.translation(h / 2, w / 2), Geometry.rotation(90.0)),
            Geometry.multiply(Geometry.translation(-w / 2, -h / 2), Geometry(flip = true).matrix(w, h)))
        assertEquals(transform(expected, 10.0, 50.0).let { Math.round(it.first) to Math.round(it.second) },
            point(seen, 10.0, 50.0).let { Math.round(it.first) to Math.round(it.second) })
    }

    private fun inverse(m: DoubleArray): DoubleArray {
        val det = m[0] * m[4] - m[1] * m[3]
        val a = m[4] / det; val b = -m[1] / det; val c = -m[3] / det; val d = m[0] / det
        return doubleArrayOf(a, b, -(a * m[2] + b * m[5]), c, d, -(c * m[2] + d * m[5]), 0.0, 0.0, 1.0)
    }
}
