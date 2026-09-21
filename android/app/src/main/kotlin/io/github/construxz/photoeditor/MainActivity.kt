package io.github.construxz.photoeditor

import android.content.pm.ActivityInfo
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.platformViewsController.registry
            .registerViewFactory("immich_editor/vorschau", VorschauFabrik())

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "immich_editor/renderer")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "laden" -> {
                        val hdr = call.argument<Boolean>("hdr")!!
                        val antwort = Sitzung.laden(call.argument<ByteArray>("original")!!, hdr)
                        // HDR-Fenster nur, wenn es etwas zu zeigen gibt (D-17).
                        window.colorMode = if (hdr && antwort["hatGainmap"] == true)
                            ActivityInfo.COLOR_MODE_HDR else ActivityInfo.COLOR_MODE_DEFAULT
                        result.success(antwort)
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
                    "beenden" -> {
                        Sitzung.beenden()
                        window.colorMode = ActivityInfo.COLOR_MODE_DEFAULT
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Volle Auflösung durch denselben Renderer wie die Vorschau, dann JPEG über den Kodierer des
     * Systems (D-13). Mit HDR hängt die Gain-Map des Originals an, und compress schreibt
     * Ultra HDR (D-16, D-19).
     */
    private fun exportieren(original: ByteArray, rezept: JSONObject, qualitaet: Int, hdr: Boolean): ByteArray {
        val quelle = BitmapFactory.decodeByteArray(original, 0, original.size)
        val gerendert = Renderer.rendern(quelle, rezept, quelle.width, quelle.height)
        val bitmap = gerendert.copy(Bitmap.Config.ARGB_8888, true)
        gerendert.recycle()
        // ponytail: Geometrie (M2) muss die Gain-Map mittransformieren.
        if (hdr) quelle.gainmap?.let { bitmap.gainmap = it }
        quelle.recycle()
        val out = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.JPEG, qualitaet, out)
        bitmap.recycle()
        return out.toByteArray()
    }
}
