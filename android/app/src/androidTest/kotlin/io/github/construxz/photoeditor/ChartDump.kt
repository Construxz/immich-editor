package io.github.construxz.photoeditor

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.Log
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
 * Argument "source" (a file in the app's files dir) renders that image instead. Recipe name
 * "optimize" takes its adjustments from [Optimize] on 256 px, like the editor (logged).
 */
@RunWith(AndroidJUnit4::class)
class ChartDump {
    @Test fun dump() {
        val args = InstrumentationRegistry.getArguments()
        val recipes = args.getString("recipes")
        assumeTrue(recipes != null)
        val inst = InstrumentationRegistry.getInstrumentation()
        val files = inst.targetContext.getExternalFilesDir(null)
        val source = args.getString("source")
        val image = if (source != null) BitmapFactory.decodeFile(File(files, source).path)
            else inst.context.assets.open("testchart.png").use { BitmapFactory.decodeStream(it) }
        val dir = File(files, "chart").apply { mkdirs() }
        val all = JSONObject(recipes!!)
        for (name in all.keys()) {
            val recipe = if (name != "optimize") all.getJSONObject(name) else {
                val k = 256f / maxOf(image.width, image.height)
                val small = Bitmap.createScaledBitmap(image, (image.width * k).toInt(), (image.height * k).toInt(), true)
                val pixels = IntArray(small.width * small.height)
                small.getPixels(pixels, 0, small.width, 0, 0, small.width, small.height)
                JSONObject(Optimize.adjustments(pixels) as Map<*, *>).also { Log.i("ChartDump", "$source $it") }
            }
            // Crop and rotation from the recipe, as the editor applies them (the source is upright).
            val b = Renderer.render(image, Geometry.from(recipe), recipe).copy(Bitmap.Config.ARGB_8888, false)
            File(dir, "$name.png").outputStream().use { b.compress(Bitmap.CompressFormat.PNG, 100, it) }
        }
    }
}
