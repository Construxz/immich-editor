package io.github.construxz.photoeditor

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class OptimizeTest {
    /** 64×64: a gray ramp over the full range, [f] maps each gray (0 … 1) to r, g, b (0 … 1). */
    private fun image(f: (Double) -> Triple<Double, Double, Double>) = IntArray(64 * 64) { i ->
        val (r, g, b) = f((i % 64) / 63.0 * 0.96 + 0.02)
        fun c(v: Double) = (v.coerceIn(0.0, 1.0) * 255 + 0.5).toInt()
        (255 shl 24) or (c(r) shl 16) or (c(g) shl 8) or c(b)
    }

    @Test fun aGoodNeutralPhotoGetsNothing() {
        assertEquals(emptyMap<String, Double>(), Optimize.adjustments(image { Triple(it, it, it) }))
    }

    @Test fun aDarkPhotoGetsBrighter() {
        val a = Optimize.adjustments(image { Triple(it * 0.4, it * 0.4, it * 0.4) })
        assertTrue("$a", a.getValue("whitePoint") > 0.5)
        assertTrue("$a", a.getValue("brightness") > 0)
        assertTrue("$a", "warmth" !in a && "tint" !in a)
    }

    @Test fun aBlueCastGetsWarmer() {
        val a = Optimize.adjustments(image { Triple(it * 0.85, it, minOf(1.0, it * 1.15)) })
        assertTrue("$a", a.getValue("warmth") > 0.3)
    }

    @Test fun aGreenCastGetsTint() {
        val a = Optimize.adjustments(image { Triple(it * 0.9, it, it * 0.9) })
        assertTrue("$a", a.getValue("tint") > 0.2)
    }

    @Test fun aWarmEveningStaysWarm() {
        // R/B about 1.2 in linear light: sunny warm, within the natural range.
        val a = Optimize.adjustments(image { Triple(minOf(1.0, it * 1.04), it, it * 0.96) })
        assertTrue("$a", "warmth" !in a && "tint" !in a)
    }

    @Test fun aColourfulPhotoKeepsItsColours() {
        // Only saturated oranges (a sunset): no gray pixels, no white balance.
        val a = Optimize.adjustments(image { Triple(it, it * 0.5, it * 0.1) })
        assertTrue("$a", "warmth" !in a && "tint" !in a)
    }
}
