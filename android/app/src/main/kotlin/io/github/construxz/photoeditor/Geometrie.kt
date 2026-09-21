package io.github.construxz.photoeditor

import org.json.JSONObject
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.sin

/**
 * Geometrie eines Rezepts, in dieser Reihenfolge: Vierteldrehungen im Uhrzeigersinn, Spiegeln
 * (waagerecht, so wie man es sieht), Geraderichten um [winkel] Grad mit automatischem Zoom, damit
 * keine leeren Ecken entstehen, zuletzt [zuschnitt] (x, y, Breite, Höhe; 0…1 im gedrehten Rahmen).
 *
 * Reine Rechnung ohne Android-Klassen — Bild und Gain-Map bekommen dieselbe Matrix (D-17).
 */
data class Geometrie(
    val viertel: Int = 0,
    val spiegeln: Boolean = false,
    val winkel: Double = 0.0,
    val zuschnitt: List<Double> = listOf(0.0, 0.0, 1.0, 1.0),
) {
    val istNeutral get() = viertel % 4 == 0 && !spiegeln && winkel == 0.0 && zuschnitt == listOf(0.0, 0.0, 1.0, 1.0)

    /** Rahmen nach den Vierteldrehungen, für eine Quelle [w]×[h]. */
    fun rahmen(w: Double, h: Double) = if (viertel % 2 == 1) h to w else w to h

    /** Größe der Ausgabe in Pixeln der Quelle. */
    fun ausgabe(w: Double, h: Double): Pair<Double, Double> {
        val (fw, fh) = rahmen(w, h)
        return fw * zuschnitt[2] to fh * zuschnitt[3]
    }

    /** Matrix Quelle → Ausgabe (3×3, zeilenweise, für Spaltenvektoren) für eine Quelle [w]×[h]. */
    fun matrix(w: Double, h: Double): DoubleArray {
        val (fw, fh) = rahmen(w, h)
        var m = verschiebung(-w / 2, -h / 2)
        m = mal(drehung(90.0 * (viertel % 4)), m)
        if (spiegeln) m = mal(skalierung(-1.0, 1.0), m)
        m = mal(skalierung(abdeckung(fw, fh), abdeckung(fw, fh)), m)
        m = mal(drehung(winkel), m)
        m = mal(verschiebung(fw / 2 - zuschnitt[0] * fw, fh / 2 - zuschnitt[1] * fh), m)
        return m
    }

    /** Zoom, mit dem das um [winkel] gedrehte Bild den Rahmen [fw]×[fh] ganz bedeckt. */
    private fun abdeckung(fw: Double, fh: Double): Double {
        val a = Math.toRadians(abs(winkel))
        return max((fw * cos(a) + fh * sin(a)) / fw, (fw * sin(a) + fh * cos(a)) / fh)
    }

    /**
     * Setzt diese Geometrie auf die EXIF-[orientierung] (1…8) des Originals: erst wird das Bild
     * aufgerichtet, dann gilt, was der Nutzer eingestellt hat. Spiegeln vor einer Drehung kehrt
     * deren Richtung um (F·R(q) = R(−q)·F).
     */
    fun nachExif(orientierung: Int): Geometrie {
        val (qb, fb) = when (orientierung) {
            2 -> 0 to true
            3 -> 2 to false
            4 -> 2 to true
            5 -> 1 to true
            6 -> 1 to false
            7 -> 3 to true
            8 -> 3 to false
            else -> 0 to false
        }
        val q = (qb + if (fb) -viertel else viertel).mod(4)
        return copy(viertel = q, spiegeln = fb != spiegeln)
    }

    companion object {
        fun aus(rezept: JSONObject): Geometrie {
            val g = rezept.optJSONObject("geometry") ?: return Geometrie()
            val z = g.optJSONArray("crop")
            return Geometrie(
                viertel = g.optInt("quarterTurns", 0),
                spiegeln = g.optBoolean("flip", false),
                winkel = g.optDouble("angle", 0.0),
                zuschnitt = if (z == null) listOf(0.0, 0.0, 1.0, 1.0) else List(4) { z.getDouble(it) },
            )
        }

        fun verschiebung(x: Double, y: Double) = doubleArrayOf(1.0, 0.0, x, 0.0, 1.0, y, 0.0, 0.0, 1.0)
        fun skalierung(x: Double, y: Double) = doubleArrayOf(x, 0.0, 0.0, 0.0, y, 0.0, 0.0, 0.0, 1.0)

        /** Drehung um [grad] im Uhrzeigersinn (y zeigt nach unten). */
        fun drehung(grad: Double): DoubleArray {
            val r = Math.toRadians(grad)
            val c = cos(r)
            val s = sin(r)
            return doubleArrayOf(c, -s, 0.0, s, c, 0.0, 0.0, 0.0, 1.0)
        }

        fun mal(a: DoubleArray, b: DoubleArray) = DoubleArray(9) { i ->
            val z = i / 3
            val sp = i % 3
            a[z * 3] * b[sp] + a[z * 3 + 1] * b[3 + sp] + a[z * 3 + 2] * b[6 + sp]
        }

        fun anwenden(m: DoubleArray, x: Double, y: Double) =
            (m[0] * x + m[1] * y + m[2]) to (m[3] * x + m[4] * y + m[5])
    }
}
