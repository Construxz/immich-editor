package io.github.construxz.photoeditor

import android.graphics.Bitmap
import android.graphics.Color
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import kotlin.math.abs

/** The renderer on the GPU: neutral means unchanged, every adjustment acts in its direction. */
@RunWith(AndroidJUnit4::class)
class RendererTest {
    // 64×64: a horizontal gray ramp, a blue patch top right, an orange patch bottom left
    private val source = Bitmap.createBitmap(64, 64, Bitmap.Config.ARGB_8888).apply {
        for (y in 0 until 64) for (x in 0 until 64) {
            val g = x * 4
            setPixel(x, y, when {
                x >= 48 && y < 16 -> Color.rgb(40, 90, 200)
                x < 16 && y >= 48 -> Color.rgb(220, 140, 60)
                else -> Color.rgb(g, g, g)
            })
        }
    }

    private fun render(recipe: String, geo: Geometry = Geometry()) =
        Renderer.render(source, geo, JSONObject(recipe)).copy(Bitmap.Config.ARGB_8888, false)

    private fun channels(b: Bitmap, x: Int, y: Int) = b.getPixel(x, y).let { intArrayOf(Color.red(it), Color.green(it), Color.blue(it)) }
    private fun lightness(b: Bitmap, x: Int, y: Int) = channels(b, x, y).average()
    private fun chroma(b: Bitmap, x: Int, y: Int) = channels(b, x, y).let { it.max() - it.min() }

    init { Luts.assets = InstrumentationRegistry.getInstrumentation().targetContext.assets }

    @Test fun filterBlackAndWhiteIsGrayHalfStrengthHalfway() {
        val b = render("""{"filter":{"id":"bw@1","strength":1}}""")
        assertTrue(chroma(b, 56, 8) <= 3)
        assertTrue(chroma(b, 8, 56) <= 3)
        val half = render("""{"filter":{"id":"bw@1","strength":0.5}}""")
        assertEquals(chroma(source, 56, 8) / 2.0, chroma(half, 56, 8).toDouble(), 6.0)
        // The gray ramp stays where it was (LUT interpolation within 2 steps)
        for (x in listOf(4, 20, 36, 60)) assertEquals(lightness(source, x, 32), lightness(b, x, 32), 2.5)
    }

    @Test fun filterWarmAndUnknownFilter() {
        val warm = render("""{"filter":{"id":"warm@1","strength":1}}""")
        val a = channels(source, 32, 32); val n = channels(warm, 32, 32)
        assertTrue(n[0] > a[0] && n[2] < a[2])
        // A filter this app does not know (newer recipe) is left out
        val unknown = render("""{"filter":{"id":"later@9","strength":1}}""")
        assertEquals(lightness(source, 56, 8), lightness(unknown, 56, 8), 2.0)
        assertEquals(chroma(source, 56, 8).toDouble(), chroma(unknown, 56, 8).toDouble(), 2.0)
    }

    @Test fun neutralLeavesTheImageUnchanged() {
        val b = render("""{"v":1}""")
        var deviation = 0
        for (y in 0 until 64) for (x in 0 until 64) {
            val a = channels(source, x, y); val n = channels(b, x, y)
            for (i in 0..2) deviation = maxOf(deviation, abs(a[i] - n[i]))
        }
        assertTrue("largest deviation $deviation", deviation <= 2)
    }

    @Test fun brightnessLiftsMidtonesEndsStay() {
        val b = render("""{"brightness":0.5}""")
        assertTrue(lightness(b, 32, 32) > lightness(source, 32, 32) + 10)
        assertEquals(lightness(source, 0, 32), lightness(b, 0, 32), 2.0)
    }

    @Test fun contrastSpreads() {
        val b = render("""{"contrast":1}""")
        assertTrue(lightness(b, 12, 32) < lightness(source, 12, 32))
        assertTrue(lightness(b, 52, 32) > lightness(source, 52, 32))
    }

    @Test fun saturationMinusOneIsGray() {
        val b = render("""{"saturation":-1}""")
        assertTrue(chroma(b, 56, 8) <= 2)
        assertTrue(chroma(b, 8, 56) <= 2)
    }

    @Test fun blueTonesOnlyAffectBlue() {
        val b = render("""{"blueTones":-1}""")
        assertTrue(chroma(b, 56, 8) < chroma(source, 56, 8) - 20)
        assertEquals(chroma(source, 8, 56).toDouble(), chroma(b, 8, 56).toDouble(), 3.0)
    }

    @Test fun warmthMakesRedderAndLessBlue() {
        val b = render("""{"warmth":1}""")
        val a = channels(source, 32, 32); val n = channels(b, 32, 32)
        assertTrue(n[0] > a[0] && n[2] < a[2])
    }

    @Test fun shadowsAndHighlights() {
        assertTrue(lightness(render("""{"shadows":1}"""), 12, 32) > lightness(source, 12, 32) + 5)
        assertTrue(lightness(render("""{"highlights":-1}"""), 60, 32) < lightness(source, 60, 32) - 5)
    }

    @Test fun whiteAndBlackPoint() {
        assertTrue(lightness(render("""{"whitePoint":1}"""), 56, 32) > lightness(source, 56, 32))
        assertTrue(lightness(render("""{"blackPoint":1}"""), 8, 32) < lightness(source, 8, 32))
    }

    @Test fun vignetteDarkensTheCorners() {
        val b = render("""{"vignette":1}""")
        assertTrue(lightness(b, 63, 20) < lightness(source, 63, 20) - 10) // edge
        assertEquals(lightness(source, 32, 32), lightness(b, 32, 32), 2.0) // center
    }

    @Test fun sharpnessRaisesEdges() {
        val b = render("""{"sharpness":1}""")
        // at the edge of the blue patch the difference grows
        val before = abs(lightness(source, 47, 8) - lightness(source, 48, 8))
        val after = abs(lightness(b, 47, 8) - lightness(b, 48, 8))
        assertTrue("$before → $after", after > before)
    }

    /** Gray patches of the test chart as Google Photos' copies show them at ±1 (D-73). */
    @Test fun matchesGooglePhotosOnGray() {
        val cases = listOf(
            Triple("brightness" to -1, 255, intArrayOf(124, 124, 124)),
            Triple("brightness" to 1, 111, intArrayOf(200, 200, 200)),
            Triple("contrast" to 1, 55, intArrayOf(35, 35, 35)),
            Triple("shadows" to -1, 89, intArrayOf(55, 55, 55)),
            Triple("shadows" to 1, 22, intArrayOf(61, 61, 61)),
            Triple("highlights" to -1, 200, intArrayOf(170, 170, 170)),
            Triple("blackPoint" to -1, 0, intArrayOf(41, 41, 41)),
            Triple("whitePoint" to 1, 111, intArrayOf(147, 147, 147)),
            Triple("warmth" to 1, 133, intArrayOf(172, 127, 72)),
            Triple("tint" to -1, 133, intArrayOf(95, 147, 98)),
        )
        for ((adjustment, gray, google) in cases) {
            val patch = Bitmap.createBitmap(8, 8, Bitmap.Config.ARGB_8888).apply { eraseColor(Color.rgb(gray, gray, gray)) }
            val b = Renderer.render(patch, Geometry(), JSONObject("""{"${adjustment.first}":${adjustment.second}}"""))
                .copy(Bitmap.Config.ARGB_8888, false)
            val ours = channels(b, 4, 4)
            for (i in 0..2) assertEquals("$adjustment on $gray", google[i].toDouble(), ours[i].toDouble(), 5.0)
        }
    }

    @Test fun geometrySwapsWidthAndHeight() {
        val b = Renderer.render(source, Geometry(quarterTurns = 1, crop = listOf(0.0, 0.0, 1.0, 0.5)), JSONObject("{}"))
        assertEquals(64, b.width); assertEquals(32, b.height)
    }
}
