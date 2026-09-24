package io.github.construxz.photoeditor

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test
import java.io.File

class LutTest {
    @Test fun readsSizeAndValuesRedFastest() {
        val lut = Lut.parse(
            """
            # comment
            TITLE "x"
            LUT_3D_SIZE 2
            0 0 0
            1 0 0
            0 1 0
            1 1 0
            0 0 1
            1 0 1
            0 1 1
            1 1 1
            """.trimIndent(),
        )
        assertEquals(2, lut.size)
        assertEquals(1f, lut.values[3], 0f) // second entry: red = 1
        assertEquals(1f, lut.values[3 * 4 + 2], 0f) // fifth entry: blue = 1
    }

    @Test fun rejectsIncompleteTables() {
        assertThrows(IllegalArgumentException::class.java) { Lut.parse("LUT_3D_SIZE 2\n0 0 0\n") }
    }

    @Test fun builtInFiltersAreComplete() {
        val files = File("src/main/assets/luts").listFiles()!!.filter { it.name.endsWith(".cube") }
        assertEquals(8, files.size)
        for (f in files) assertEquals(f.name, 17, Lut.parse(f.readText()).size)
        // Black and white: every entry gray
        val bw = Lut.parse(File("src/main/assets/luts/bw@1.cube").readText()).values
        for (i in bw.indices step 3) assertEquals(bw[i], bw[i + 2], 0.001f)
    }
}
