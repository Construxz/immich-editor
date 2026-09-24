package io.github.construxz.photoeditor

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.RectF
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.view.View
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import org.json.JSONObject

/** The image being edited. There is only ever one editor. */
object Session {
    private const val PREVIEW_EDGE = 2048 // longest edge of the preview source
    private const val THUMB_EDGE = 192 // filter thumbnails

    private val thread = HandlerThread("renderer").apply { start() }
    val background = Handler(thread.looper)
    private val main = Handler(Looper.getMainLooper())

    private var source: Bitmap? = null
    private var orientation = 1
    private var recipe = JSONObject()
    private var hdr = true
    private var busy = false
    private var again = false

    /** The last rendered preview image, with gain map when HDR is on. */
    var image: Bitmap? = null
        private set
    var view: View? = null

    /** Loads the original with [recipeJson]; the preview works on a downscaled version. */
    fun load(bytes: ByteArray, hdrOn: Boolean, recipeJson: String): Map<String, Any> {
        orientation = Renderer.orientation(bytes)
        hdr = hdrOn
        recipe = JSONObject(recipeJson)
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
        var factor = 1
        while (maxOf(bounds.outWidth, bounds.outHeight) / (factor * 2) >= PREVIEW_EDGE) factor *= 2
        source = BitmapFactory.decodeByteArray(
            bytes, 0, bytes.size, BitmapFactory.Options().apply { inSampleSize = factor },
        )
        rerender()
        // Size as the image is seen (after EXIF), for aspect ratios when cropping
        val (w, h) = Geometry().afterExif(orientation).frame(bounds.outWidth.toDouble(), bounds.outHeight.toDouble())
        return mapOf("hasGainmap" to (source?.gainmap != null), "width" to w.toInt(), "height" to h.toInt())
    }

    val hasGainmap get() = source?.gainmap != null

    fun setHdr(on: Boolean) {
        hdr = on
        rerender()
    }

    fun setRecipe(json: String) {
        recipe = JSONObject(json)
        rerender()
    }

    /** "Optimieren" (D-70): adjustments for the loaded photo, read from a 256 px version. */
    fun optimize(): Map<String, Double> = source?.let { optimize(it) } ?: emptyMap()

    /** "Optimieren" for [bytes] of an original — for a multiple selection, photo by photo (D-71). */
    fun optimize(bytes: ByteArray): Map<String, Double> {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
        var factor = 1
        while (maxOf(bounds.outWidth, bounds.outHeight) / (factor * 2) >= PREVIEW_EDGE) factor *= 2
        val q = BitmapFactory.decodeByteArray(bytes, 0, bytes.size, BitmapFactory.Options().apply { inSampleSize = factor })
            ?: return emptyMap()
        return optimize(q)
    }

    /** Both ways the same steps as the editor's preview (≤ 2048 px), then 256 px. */
    private fun optimize(q: Bitmap): Map<String, Double> {
        val s = 256f / maxOf(q.width, q.height)
        val small = Bitmap.createScaledBitmap(q, maxOf(1, (q.width * s).toInt()), maxOf(1, (q.height * s).toInt()), true)
        val pixels = IntArray(small.width * small.height)
        small.getPixels(pixels, 0, small.width, 0, 0, small.width, small.height)
        return Optimize.adjustments(pixels)
    }

    /** Small JPEGs of the photo, upright, with each filter in [ids] — for the filter tab. */
    fun filterThumbs(ids: List<String>): List<ByteArray> {
        val q = source ?: return emptyList()
        val s = THUMB_EDGE.toFloat() / maxOf(q.width, q.height)
        val small = Bitmap.createScaledBitmap(q, maxOf(1, (q.width * s).toInt()), maxOf(1, (q.height * s).toInt()), true)
        val geo = Geometry().afterExif(orientation)
        val recipes = ids.map { JSONObject().put("filter", JSONObject().put("id", it)) }
        return Renderer.renderTiles(small, geo, recipes).map { tile ->
            java.io.ByteArrayOutputStream().also { tile.compress(Bitmap.CompressFormat.JPEG, 85, it) }.toByteArray()
        }
    }

    fun end() {
        source = null
        image = null
    }

    /** Renders in the background; if changes come faster, only the last one counts. */
    private fun rerender() {
        if (busy) { again = true; return }
        val q = source ?: return
        val r = recipe
        val geo = Geometry.from(r).afterExif(orientation)
        val withHdr = hdr
        busy = true
        background.post {
            val fresh = Renderer.render(q, geo, r)
            if (withHdr) q.gainmap?.let { fresh.gainmap = Renderer.gainmap(it, geo) }
            main.post {
                image = fresh
                view?.invalidate()
                busy = false
                if (again) { again = false; rerender() }
            }
        }
    }
}

/** Shows [Session.image] fitted. As a real Android view, Android can draw the gain map. */
class PreviewView(context: Context) : View(context) {
    init { setBackgroundColor(Color.BLACK) }

    override fun onDraw(canvas: Canvas) {
        val b = Session.image ?: return
        val s = minOf(width / b.width.toFloat(), height / b.height.toFloat())
        val w = b.width * s
        val h = b.height * s
        val x = (width - w) / 2
        val y = (height - h) / 2
        canvas.drawBitmap(b, null, RectF(x, y, x + w, y + h), null)
    }
}

class PreviewFactory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val previewView = PreviewView(context)
        Session.view = previewView
        return object : PlatformView {
            override fun getView(): View = previewView
            override fun dispose() { if (Session.view === previewView) Session.view = null }
        }
    }
}
