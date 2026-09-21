package io.github.construxz.photoeditor

import android.graphics.Bitmap
import android.graphics.Color
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import kotlin.math.abs

/** Der Renderer auf der GPU: neutral heißt unverändert, jeder Regler wirkt in seine Richtung. */
@RunWith(AndroidJUnit4::class)
class RendererTest {
    // 64×64: waagerecht ein Grauverlauf, oben rechts ein blaues, unten links ein oranges Feld
    private val quelle = Bitmap.createBitmap(64, 64, Bitmap.Config.ARGB_8888).apply {
        for (y in 0 until 64) for (x in 0 until 64) {
            val g = x * 4
            setPixel(x, y, when {
                x >= 48 && y < 16 -> Color.rgb(40, 90, 200)
                x < 16 && y >= 48 -> Color.rgb(220, 140, 60)
                else -> Color.rgb(g, g, g)
            })
        }
    }

    private fun rendern(rezept: String, geo: Geometrie = Geometrie()) =
        Renderer.rendern(quelle, geo, JSONObject(rezept)).copy(Bitmap.Config.ARGB_8888, false)

    private fun kanaele(b: Bitmap, x: Int, y: Int) = b.getPixel(x, y).let { intArrayOf(Color.red(it), Color.green(it), Color.blue(it)) }
    private fun hell(b: Bitmap, x: Int, y: Int) = kanaele(b, x, y).average()
    private fun buntheit(b: Bitmap, x: Int, y: Int) = kanaele(b, x, y).let { it.max() - it.min() }

    @Test fun neutralLaesstDasBildUnveraendert() {
        val b = rendern("""{"v":1}""")
        var abweichung = 0
        for (y in 0 until 64) for (x in 0 until 64) {
            val a = kanaele(quelle, x, y); val n = kanaele(b, x, y)
            for (i in 0..2) abweichung = maxOf(abweichung, abs(a[i] - n[i]))
        }
        assertTrue("größte Abweichung $abweichung", abweichung <= 2)
    }

    @Test fun helligkeitHebtMitteltoeneEndenBleiben() {
        val b = rendern("""{"brightness":0.5}""")
        assertTrue(hell(b, 32, 32) > hell(quelle, 32, 32) + 10)
        assertEquals(hell(quelle, 0, 32), hell(b, 0, 32), 2.0)
    }

    @Test fun kontrastSpreizt() {
        val b = rendern("""{"contrast":1}""")
        assertTrue(hell(b, 12, 32) < hell(quelle, 12, 32))
        assertTrue(hell(b, 52, 32) > hell(quelle, 52, 32))
    }

    @Test fun saettigungMinusEinsIstGrau() {
        val b = rendern("""{"saturation":-1}""")
        assertTrue(buntheit(b, 56, 8) <= 2)
        assertTrue(buntheit(b, 8, 56) <= 2)
    }

    @Test fun blautoeneWirkenNurAufBlau() {
        val b = rendern("""{"blueTones":-1}""")
        assertTrue(buntheit(b, 56, 8) < buntheit(quelle, 56, 8) - 20)
        assertEquals(buntheit(quelle, 8, 56).toDouble(), buntheit(b, 8, 56).toDouble(), 3.0)
    }

    @Test fun waermeMachtRoterUndWenigerBlau() {
        val b = rendern("""{"warmth":1}""")
        val a = kanaele(quelle, 32, 32); val n = kanaele(b, 32, 32)
        assertTrue(n[0] > a[0] && n[2] < a[2])
    }

    @Test fun schattenUndSpitzlichter() {
        assertTrue(hell(rendern("""{"shadows":1}"""), 12, 32) > hell(quelle, 12, 32) + 5)
        assertTrue(hell(rendern("""{"highlights":-1}"""), 60, 32) < hell(quelle, 60, 32) - 5)
    }

    @Test fun weissUndSchwarzpunkt() {
        assertTrue(hell(rendern("""{"whitePoint":1}"""), 56, 32) > hell(quelle, 56, 32))
        assertTrue(hell(rendern("""{"blackPoint":1}"""), 8, 32) < hell(quelle, 8, 32))
    }

    @Test fun vignetteDunkeltDieEcken() {
        val b = rendern("""{"vignette":1}""")
        assertTrue(hell(b, 63, 20) < hell(quelle, 63, 20) - 10) // Rand
        assertEquals(hell(quelle, 32, 32), hell(b, 32, 32), 2.0) // Mitte
    }

    @Test fun schaerfeHebtKanten() {
        val b = rendern("""{"sharpness":1}""")
        // an der Kante des blauen Feldes wird der Unterschied größer
        val vorher = abs(hell(quelle, 47, 8) - hell(quelle, 48, 8))
        val nachher = abs(hell(b, 47, 8) - hell(b, 48, 8))
        assertTrue("$vorher → $nachher", nachher > vorher)
    }

    @Test fun geometrieVertauschtBreiteUndHoehe() {
        val b = Renderer.rendern(quelle, Geometrie(viertel = 1, zuschnitt = listOf(0.0, 0.0, 1.0, 0.5)), JSONObject("{}"))
        assertEquals(64, b.width); assertEquals(32, b.height)
    }
}
