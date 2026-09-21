package io.github.construxz.photoeditor

import android.graphics.Bitmap
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
                thread {
                    try {
                        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                        bitmap.copyPixelsFromBuffer(ByteBuffer.wrap(rgba))
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
