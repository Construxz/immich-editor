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

/** Das Bild, das gerade bearbeitet wird. Es gibt immer nur einen Editor. */
object Sitzung {
    private const val VORSCHAU_KANTE = 2048 // längste Kante der Vorschauquelle

    private val faden = HandlerThread("renderer").apply { start() }
    val hintergrund = Handler(faden.looper)
    private val haupt = Handler(Looper.getMainLooper())

    var original: ByteArray? = null
        private set
    private var quelle: Bitmap? = null
    private var rezept = JSONObject()
    private var hdr = true
    private var laeuft = false
    private var nochmal = false

    /** Das zuletzt gerenderte Vorschaubild, samt Gain-Map, wenn HDR an ist. */
    var bild: Bitmap? = null
        private set
    var ansicht: View? = null

    /** Lädt das Original; die Vorschau rechnet auf einer verkleinerten Fassung. */
    fun laden(bytes: ByteArray, hdrAn: Boolean): Map<String, Any> {
        original = bytes
        hdr = hdrAn
        rezept = JSONObject()
        val masse = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, masse)
        var faktor = 1
        while (maxOf(masse.outWidth, masse.outHeight) / (faktor * 2) >= VORSCHAU_KANTE) faktor *= 2
        quelle = BitmapFactory.decodeByteArray(
            bytes, 0, bytes.size, BitmapFactory.Options().apply { inSampleSize = faktor },
        )
        neuRendern()
        return mapOf("hatGainmap" to (quelle?.gainmap != null))
    }

    val hatGainmap get() = quelle?.gainmap != null

    fun setzeHdr(an: Boolean) {
        hdr = an
        neuRendern()
    }

    fun setzeRezept(json: String) {
        rezept = JSONObject(json)
        neuRendern()
    }

    fun beenden() {
        original = null
        quelle = null
        bild = null
    }

    /** Rendert im Hintergrund; kommen Änderungen schneller, zählt nur die letzte. */
    private fun neuRendern() {
        if (laeuft) { nochmal = true; return }
        val q = quelle ?: return
        val r = rezept
        laeuft = true
        hintergrund.post {
            val neu = Renderer.rendern(q, r, q.width, q.height)
            if (hdr) q.gainmap?.let { neu.gainmap = it }
            haupt.post {
                bild = neu
                ansicht?.invalidate()
                laeuft = false
                if (nochmal) { nochmal = false; neuRendern() }
            }
        }
    }
}

/** Zeigt [Sitzung.bild] eingepasst an. Als echte Android-Ansicht kann Android die Gain-Map zeichnen. */
class VorschauAnsicht(context: Context) : View(context) {
    init { setBackgroundColor(Color.BLACK) }

    override fun onDraw(canvas: Canvas) {
        val b = Sitzung.bild ?: return
        val s = minOf(width / b.width.toFloat(), height / b.height.toFloat())
        val w = b.width * s
        val h = b.height * s
        val x = (width - w) / 2
        val y = (height - h) / 2
        canvas.drawBitmap(b, null, RectF(x, y, x + w, y + h), null)
    }
}

class VorschauFabrik : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val ansicht = VorschauAnsicht(context)
        Sitzung.ansicht = ansicht
        return object : PlatformView {
            override fun getView(): View = ansicht
            override fun dispose() { if (Sitzung.ansicht === ansicht) Sitzung.ansicht = null }
        }
    }
}
