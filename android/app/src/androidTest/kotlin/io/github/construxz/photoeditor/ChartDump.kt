package io.github.construxz.photoeditor

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.json.JSONObject
import org.junit.Assume.assumeTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

/**
 * Measuring tool, not a check (D-73): renders the test chart (assets, made by tool/testchart.py)
 * per recipe into the app's files dir — driven by tool/chartdump.sh, skipped in the normal run.
 * Recipe name "optimize" takes its adjustments from [Optimize], like the editor.
 */
@RunWith(AndroidJUnit4::class)
class ChartDump {
    @Test fun dump() {
        val recipes = InstrumentationRegistry.getArguments().getString("recipes")
        assumeTrue(recipes != null)
        val inst = InstrumentationRegistry.getInstrumentation()
        val chart = inst.context.assets.open("testchart.png").use { BitmapFactory.decodeStream(it) }
        val dir = File(inst.targetContext.getExternalFilesDir(null), "chart").apply { mkdirs() }
        val all = JSONObject(recipes!!)
        for (name in all.keys()) {
            val recipe = if (name != "optimize") all.getJSONObject(name) else {
                val small = Bitmap.createScaledBitmap(chart, 192, 256, true)
                val pixels = IntArray(192 * 256).also { small.getPixels(it, 0, 192, 0, 0, 192, 256) }
                JSONObject(Optimize.adjustments(pixels) as Map<*, *>)
            }
            val b = Renderer.render(chart, Geometry(), recipe).copy(Bitmap.Config.ARGB_8888, false)
            File(dir, "$name.png").outputStream().use { b.compress(Bitmap.CompressFormat.PNG, 100, it) }
        }
    }
}
