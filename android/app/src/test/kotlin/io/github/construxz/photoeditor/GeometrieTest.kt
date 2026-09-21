package io.github.construxz.photoeditor

import io.github.construxz.photoeditor.Geometrie.Companion.anwenden
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.max

class GeometrieTest {
    private val w = 400.0
    private val h = 200.0

    private fun punkt(g: Geometrie, x: Double, y: Double): Pair<Double, Double> {
        val (px, py) = anwenden(g.matrix(w, h), x, y)
        return Math.round(px * 1e6) / 1e6 to Math.round(py * 1e6) / 1e6
    }

    @Test fun neutral() {
        val g = Geometrie()
        assertTrue(g.istNeutral)
        assertEquals(0.0 to 0.0, punkt(g, 0.0, 0.0))
        assertEquals(w to h, punkt(g, w, h))
        assertEquals(w to h, g.ausgabe(w, h))
    }

    @Test fun vierteldrehungImUhrzeigersinn() {
        val g = Geometrie(viertel = 1)
        assertEquals(h to w, g.ausgabe(w, h))
        assertEquals(h to 0.0, punkt(g, 0.0, 0.0)) // oben links → oben rechts
        assertEquals(0.0 to w, punkt(g, w, h)) // unten rechts → unten links
    }

    @Test fun spiegelnWaagerecht() {
        val g = Geometrie(spiegeln = true)
        assertEquals(w to 0.0, punkt(g, 0.0, 0.0))
        assertEquals(0.0 to h, punkt(g, w, h))
    }

    @Test fun spiegelnWirktAufDieGedrehteAnsicht() {
        // erst drehen, dann so spiegeln, wie man es sieht: oben links landet oben links
        val g = Geometrie(viertel = 1, spiegeln = true)
        assertEquals(0.0 to 0.0, punkt(g, 0.0, 0.0))
    }

    @Test fun zuschnitt() {
        val g = Geometrie(zuschnitt = listOf(0.25, 0.5, 0.5, 0.5))
        assertEquals(200.0 to 100.0, g.ausgabe(w, h))
        assertEquals(0.0 to 0.0, punkt(g, 100.0, 100.0)) // Zuschnitt-Ecke → Ausgabe-Ursprung
    }

    @Test fun geraderichtenLaesstKeineLeerenEcken() {
        for (winkel in listOf(-45.0, -10.0, 3.0, 30.0)) {
            val g = Geometrie(winkel = winkel)
            val m = g.matrix(w, h)
            // Ausgabe-Ecken zurück in die Quelle: sie müssen im Bild liegen
            val inv = invers(m)
            for ((x, y) in listOf(0.0 to 0.0, w to 0.0, 0.0 to h, w to h)) {
                val (qx, qy) = anwenden(inv, x, y)
                assertTrue("$winkel°: ($qx, $qy)", qx >= -1e-6 && qx <= w + 1e-6 && qy >= -1e-6 && qy <= h + 1e-6)
            }
            // und nicht mehr gezoomt als nötig: eine Ecke liegt auf dem Rand
            val rand = listOf(0.0 to 0.0, w to 0.0, 0.0 to h, w to h).minOf { (x, y) ->
                val (qx, qy) = anwenden(inv, x, y); minOf(qx, w - qx, qy, h - qy)
            }
            assertEquals(0.0, max(rand, 0.0), 1e-6)
        }
    }

    @Test fun ausJson() {
        val g = Geometrie.aus(org.json.JSONObject("""{"v":1,"geometry":{"quarterTurns":3,"flip":true,"angle":-2.5,"crop":[0.1,0.2,0.3,0.4]}}"""))
        assertEquals(Geometrie(3, true, -2.5, listOf(0.1, 0.2, 0.3, 0.4)), g)
    }

    @Test fun exifOrientierungRichtetAuf() {
        // gespeichert 400×200, EXIF 6: angezeigt wird es 200×400, oben links landet oben rechts
        val g = Geometrie().nachExif(6)
        assertEquals(h to w, g.ausgabe(w, h))
        assertEquals(h to 0.0, punkt(g, 0.0, 0.0))
        // EXIF 5 (Transponieren): (x, y) → (y, x)
        assertEquals(50.0 to 10.0, punkt(Geometrie().nachExif(5), 10.0, 50.0))
        // EXIF 7 (Transversale): (x, y) → (h − y, w − x)
        assertEquals(150.0 to 390.0, punkt(Geometrie().nachExif(7), 10.0, 50.0))
        assertEquals(Geometrie(), Geometrie().nachExif(1))
    }

    @Test fun nutzerDrehungNachExif() {
        // EXIF 6 und eine Vierteldrehung des Nutzers = halbe Drehung des gespeicherten Bildes
        assertEquals(punkt(Geometrie(viertel = 2), 10.0, 50.0), punkt(Geometrie(viertel = 1).nachExif(6), 10.0, 50.0))
        // gespiegeltes Original (EXIF 2), Nutzer dreht: das Gesehene dreht sich im Uhrzeigersinn
        val gesehen = Geometrie(viertel = 1).nachExif(2)
        val erwartet = Geometrie.mal(Geometrie.mal(Geometrie.verschiebung(h / 2, w / 2), Geometrie.drehung(90.0)),
            Geometrie.mal(Geometrie.verschiebung(-w / 2, -h / 2), Geometrie(spiegeln = true).matrix(w, h)))
        assertEquals(anwenden(erwartet, 10.0, 50.0).let { Math.round(it.first) to Math.round(it.second) },
            punkt(gesehen, 10.0, 50.0).let { Math.round(it.first) to Math.round(it.second) })
    }

    private fun invers(m: DoubleArray): DoubleArray {
        val det = m[0] * m[4] - m[1] * m[3]
        val a = m[4] / det; val b = -m[1] / det; val c = -m[3] / det; val d = m[0] / det
        return doubleArrayOf(a, b, -(a * m[2] + b * m[5]), c, d, -(c * m[2] + d * m[5]), 0.0, 0.0, 1.0)
    }
}
