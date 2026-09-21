package io.github.construxz.photoeditor

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import kotlin.concurrent.thread

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // JPEG-Kodierung mit dem Kodierer des Systems (E1): RGBA rein, JPEG raus.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "immich_editor/jpeg")
            .setMethodCallHandler { call, result ->
                val rgba = call.argument<ByteArray>("rgba")!!
                val width = call.argument<Int>("width")!!
                val height = call.argument<Int>("height")!!
                val quality = call.argument<Int>("quality")!!
                val original = call.argument<ByteArray>("original")
                thread {
                    try {
                        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                        bitmap.copyPixelsFromBuffer(ByteBuffer.wrap(rgba))
                        // Ultra HDR (E2): die Gain-Map des Originals mitnehmen; compress schreibt
                        // dann ein JPEG mit Gain-Map. Tonwert-Änderungen wirken so auf SDR und HDR
                        // gleich. ponytail: Geometrie (Zuschneiden, M2) muss die Gain-Map mittransformieren.
                        if (original != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                            BitmapFactory.decodeByteArray(original, 0, original.size)?.let { o ->
                                o.gainmap?.let { bitmap.gainmap = it }
                                o.recycle()
                            }
                        }
                        val out = ByteArrayOutputStream()
                        bitmap.compress(Bitmap.CompressFormat.JPEG, quality, out)
                        bitmap.recycle()
                        runOnUiThread { result.success(out.toByteArray()) }
                    } catch (e: Exception) {
                        runOnUiThread { result.error("encode", e.toString(), null) }
                    }
                }
            }
    }
}
