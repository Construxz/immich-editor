package io.github.construxz.photoeditor

import org.junit.Assert.assertEquals
import org.junit.Test

class PopTest {
    @Test fun aFlatImageIsItsOwnBlur() {
        val (a, b) = Pop.coefficients(FloatArray(20 * 10) { 0.4f }, 20, 10, 3, 0.01f)
        for (i in a.indices) assertEquals(0.4f, a[i] * 0.4f + b[i], 1e-5f)
    }

    @Test fun aStrongEdgeStaysAndFineDetailGoesIntoPop() {
        // Left dark, right bright, with a faint ripple on top.
        val w = 40; val h = 8
        val y = FloatArray(w * h) { val x = it % w; (if (x < 20) 0.2f else 0.8f) + if (x % 2 == 0) 0.01f else -0.01f }
        val (a, b) = Pop.coefficients(y, w, h, 3, 0.01f)
        val blur = FloatArray(y.size) { a[it] * y[it] + b[it] }
        // Next to the edge the blur keeps the step (edge-preserving) …
        assertEquals(0.2f, blur[4 * w + 18], 0.05f)
        assertEquals(0.8f, blur[4 * w + 21], 0.05f)
        // … far from it the ripple is smoothed out: that is the detail Pop raises.
        assertEquals(0.2f, blur[4 * w + 8], 0.005f)
    }
}
