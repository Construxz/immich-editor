package io.github.construxz.photoeditor

import android.animation.ValueAnimator
import android.app.Activity
import android.content.ContentUris
import android.content.Context
import android.content.pm.ActivityInfo
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.ImageDecoder
import android.graphics.RectF
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.provider.MediaStore
import android.view.View
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * Switches the window to HDR and back. On Android 15+ the headroom ramps up over half a second
 * instead of jumping (D-54).
 */
fun Activity.hdrMode(on: Boolean) {
    val mode = if (on) ActivityInfo.COLOR_MODE_HDR else ActivityInfo.COLOR_MODE_DEFAULT
    if (window.colorMode == mode) return
    window.colorMode = mode
    android.util.Log.i("immich_editor", "hdr window ${if (on) "on" else "off"}") // measured in D-63
    if (on && Build.VERSION.SDK_INT >= 35) {
        val top = display?.highestHdrSdrRatio ?: return
        ValueAnimator.ofFloat(1f, top).apply {
            duration = 500
            addUpdateListener { window.desiredHdrHeadroom = it.animatedValue as Float }
            doOnEnd { window.desiredHdrHeadroom = 0f } // 0: no limit, the system decides
            start()
        }
    }
}

private fun ValueAnimator.doOnEnd(action: () -> Unit) = addListener(object : android.animation.AnimatorListenerAdapter() {
    override fun onAnimationEnd(animation: android.animation.Animator) = action()
})

/**
 * A device photo drawn by Android, so its gain map shows in HDR (D-54) — the viewer lays it over
 * Flutter's image while not zoomed. ImageDecoder keeps the gain map and applies the EXIF
 * orientation.
 */
class HdrImageView(context: Context, private val activity: Activity, id: Long, private val hdr: Boolean) : View(context) {
    private var image: Bitmap? = null
    private var counted = false

    init {
        decoder.post {
            val bitmap = try {
                val uri = ContentUris.withAppendedId(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, id)
                ImageDecoder.decodeBitmap(ImageDecoder.createSource(context.contentResolver, uri)) { d, info, _ ->
                    var n = 1
                    while (maxOf(info.size.width, info.size.height) / (n * 2) >= MAX_EDGE) n *= 2
                    d.setTargetSampleSize(n)
                }
            } catch (_: Exception) {
                null // gone or unreadable: Flutter's image stays
            }
            post {
                image = bitmap
                invalidate()
                if (hdr && bitmap?.hasGainmap() == true && isAttachedToWindow && !counted) {
                    counted = true
                    if (active++ == 0) activity.hdrMode(true)
                }
            }
        }
    }

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        if (counted) {
            counted = false
            if (--active == 0) activity.hdrMode(false)
        }
    }

    override fun onDraw(canvas: Canvas) {
        val b = image ?: return
        val s = minOf(width / b.width.toFloat(), height / b.height.toFloat())
        val w = b.width * s
        val h = b.height * s
        val x = (width - w) / 2
        val y = (height - h) / 2
        canvas.drawBitmap(b, null, RectF(x, y, x + w, y + h), null)
    }

    companion object {
        private const val MAX_EDGE = 2560
        private val decoder = Handler(HandlerThread("viewer").apply { start() }.looper)

        /** HDR photos on screen right now; the window stays HDR while there is one. */
        var active = 0
            private set
    }
}

class HdrImageFactory(private val activity: Activity) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val a = args as Map<*, *>
        val view = HdrImageView(context, activity, (a["id"] as String).toLong(), a["hdr"] == true)
        return object : PlatformView {
            override fun getView(): View = view
            override fun dispose() {}
        }
    }
}
