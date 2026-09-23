package io.github.construxz.photoeditor

import android.content.ContentUris
import android.content.pm.ActivityInfo
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.ExifInterface
import android.net.ConnectivityManager
import android.os.Handler
import android.os.HandlerThread
import android.provider.MediaStore
import java.io.ByteArrayInputStream
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.util.Base64
import org.json.JSONObject
import java.security.MessageDigest
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {
    /** Eigener Faden für Prüfsummen, damit der Renderer nicht wartet. */
    private val pruefFaden = Handler(HandlerThread("pruefsummen").apply { start() }.looper)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.platformViewsController.registry
            .registerViewFactory("immich_editor/vorschau", VorschauFabrik())

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "immich_editor/renderer")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "laden" -> {
                        val hdr = call.argument<Boolean>("hdr")!!
                        val original = call.argument<ByteArray>("original")!!
                        val rezept = call.argument<String>("rezept")!!
                        // Dekodieren nicht auf dem Haupt-Thread — sonst droht „App reagiert nicht".
                        Sitzung.hintergrund.post {
                            val antwort = Sitzung.laden(original, hdr, rezept)
                            runOnUiThread {
                                hdrFenster(hdr)
                                result.success(antwort)
                            }
                        }
                    }
                    "sha1" -> {
                        val bytes = call.argument<ByteArray>("bytes")!!
                        Sitzung.hintergrund.post {
                            val summe = Base64.encodeToString(
                                MessageDigest.getInstance("SHA-1").digest(bytes), Base64.NO_WRAP,
                            )
                            runOnUiThread { result.success(summe) }
                        }
                    }
                    "hdr" -> {
                        val an = call.argument<Boolean>("an")!!
                        Sitzung.setzeHdr(an)
                        hdrFenster(an)
                        result.success(null)
                    }
                    "rezept" -> {
                        Sitzung.setzeRezept(call.argument<String>("rezept")!!)
                        result.success(null)
                    }
                    "exportieren" -> {
                        val rezept = JSONObject(call.argument<String>("rezept")!!)
                        val qualitaet = call.argument<Int>("quality")!!
                        val hdr = call.argument<Boolean>("hdr")!!
                        val original = Sitzung.original!!
                        Sitzung.hintergrund.post {
                            try {
                                val jpeg = exportieren(original, rezept, qualitaet, hdr)
                                runOnUiThread { result.success(jpeg) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("export", e.toString(), null) }
                            }
                        }
                    }
                    "exif" -> {
                        val e = ExifInterface(ByteArrayInputStream(call.argument<ByteArray>("bytes")!!))
                        val werte = mutableMapOf<String, Any>()
                        for (t in listOf("Make", "Model", "LensModel")) e.getAttribute(t)?.let { werte[t] = it.trim() }
                        // Tag 0x8827; das Framework kennt ihn je nach Version unter dem alten Namen
                        listOf("PhotographicSensitivity", "ISOSpeedRatings").map { e.getAttributeInt(it, 0) }
                            .firstOrNull { it > 0 }?.let { werte["PhotographicSensitivity"] = it }
                        for (t in listOf("FNumber", "ExposureTime", "FocalLength")) {
                            e.getAttributeDouble(t, -1.0).takeIf { it > 0 }?.let { werte[t] = it }
                        }
                        val ort = FloatArray(2)
                        if (e.getLatLong(ort)) { werte["lat"] = ort[0].toDouble(); werte["lon"] = ort[1].toDouble() }
                        result.success(werte)
                    }
                    "appVersion" -> {
                        val p = packageManager.getPackageInfo(packageName, 0)
                        result.success("${p.versionName} build.${p.longVersionCode}")
                    }
                    "pruefsummen" -> {
                        // SHA-1 der Gerätefotos, direkt aus der Datei gelesen (unverändert, mit Ort —
                        // ACCESS_MEDIA_LOCATION), wie Immich sie als checksum führt (D-36).
                        val ids = call.argument<List<String>>("ids")!!
                        pruefFaden.post {
                            val summen = mutableMapOf<String, String>()
                            for (id in ids) {
                                try {
                                    val uri = MediaStore.setRequireOriginal(
                                        ContentUris.withAppendedId(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, id.toLong()),
                                    )
                                    val sha = MessageDigest.getInstance("SHA-1")
                                    contentResolver.openInputStream(uri)?.use { ein ->
                                        val puffer = ByteArray(1 shl 16)
                                        while (true) {
                                            val n = ein.read(puffer)
                                            if (n < 0) break
                                            sha.update(puffer, 0, n)
                                        }
                                        summen[id] = Base64.encodeToString(sha.digest(), Base64.NO_WRAP)
                                    }
                                } catch (_: Exception) {
                                    // gelöscht oder nicht lesbar: fehlt in der Antwort
                                }
                            }
                            runOnUiThread { result.success(summen) }
                        }
                    }
                    "dateien" -> result.success(filesDir.path)
                    "getaktet" -> result.success(
                        getSystemService(ConnectivityManager::class.java).isActiveNetworkMetered,
                    )
                    "beenden" -> {
                        Sitzung.beenden()
                        window.colorMode = ActivityInfo.COLOR_MODE_DEFAULT
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /** HDR-Fenster nur, wenn es etwas zu zeigen gibt (D-17). */
    private fun hdrFenster(an: Boolean) {
        window.colorMode = if (an && Sitzung.hatGainmap)
            ActivityInfo.COLOR_MODE_HDR else ActivityInfo.COLOR_MODE_DEFAULT
    }

    /**
     * Volle Auflösung durch denselben Renderer wie die Vorschau, dann JPEG über den Kodierer des
     * Systems (D-13). Mit HDR hängt die Gain-Map des Originals an, und compress schreibt
     * Ultra HDR (D-16, D-19).
     */
    private fun exportieren(original: ByteArray, rezept: JSONObject, qualitaet: Int, hdr: Boolean): ByteArray {
        val quelle = BitmapFactory.decodeByteArray(original, 0, original.size)
        val geo = Geometrie.aus(rezept).nachExif(Renderer.orientierung(original))
        val gerendert = Renderer.rendern(quelle, geo, rezept)
        val bitmap = gerendert.copy(Bitmap.Config.ARGB_8888, true)
        gerendert.recycle()
        if (hdr) quelle.gainmap?.let { bitmap.gainmap = Renderer.gainmap(it, geo) }
        quelle.recycle()
        val out = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.JPEG, qualitaet, out)
        bitmap.recycle()
        return out.toByteArray()
    }
}
