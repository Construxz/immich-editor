package io.github.construxz.photoeditor

import android.content.ActivityNotFoundException
import android.content.ContentUris
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import androidx.exifinterface.media.ExifInterface
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
    /** Own thread for checksums, so the renderer does not wait. */
    private val checksumThread = Handler(HandlerThread("checksums").apply { start() }.looper)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        Luts.assets = assets
        flutterEngine.platformViewsController.registry
            .registerViewFactory("immich_editor/preview", PreviewFactory())
        flutterEngine.platformViewsController.registry
            .registerViewFactory("immich_editor/hdr", HdrImageFactory(this))

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "immich_editor/renderer")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "load" -> {
                        val hdr = call.argument<Boolean>("hdr")!!
                        val original = call.argument<ByteArray>("original")!!
                        val recipe = call.argument<String>("recipe")!!
                        // Decode off the main thread — otherwise "app not responding" looms.
                        Session.background.post {
                            val answer = Session.load(original, hdr, recipe)
                            runOnUiThread {
                                hdrWindow(hdr)
                                result.success(answer)
                            }
                        }
                    }
                    "sha1" -> {
                        val bytes = call.argument<ByteArray>("bytes")!!
                        Session.background.post {
                            val sum = Base64.encodeToString(
                                MessageDigest.getInstance("SHA-1").digest(bytes), Base64.NO_WRAP,
                            )
                            runOnUiThread { result.success(sum) }
                        }
                    }
                    "hdr" -> {
                        val on = call.argument<Boolean>("on")!!
                        Session.setHdr(on)
                        hdrWindow(on)
                        result.success(null)
                    }
                    "filterThumbs" -> {
                        val ids = call.argument<List<String>>("ids")!!
                        Session.background.post {
                            val thumbs = Session.filterThumbs(ids)
                            runOnUiThread { result.success(thumbs) }
                        }
                    }
                    "recipe" -> {
                        Session.setRecipe(call.argument<String>("recipe")!!)
                        result.success(null)
                    }
                    "export" -> {
                        val recipe = JSONObject(call.argument<String>("recipe")!!)
                        val quality = call.argument<Int>("quality")!!
                        val hdr = call.argument<Boolean>("hdr")!!
                        val original = call.argument<ByteArray>("original")!!
                        Session.background.post {
                            try {
                                val jpeg = export(original, recipe, quality, hdr)
                                runOnUiThread { result.success(jpeg) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("export", e.toString(), null) }
                            }
                        }
                    }
                    "exif" -> {
                        val e = ExifInterface(ByteArrayInputStream(call.argument<ByteArray>("bytes")!!))
                        val values = mutableMapOf<String, Any>()
                        for (t in listOf("Make", "Model", "LensModel")) e.getAttribute(t)?.let { values[t] = it.trim() }
                        // Tag 0x8827; depending on version the framework knows it by the old name
                        listOf("PhotographicSensitivity", "ISOSpeedRatings").map { e.getAttributeInt(it, 0) }
                            .firstOrNull { it > 0 }?.let { values["PhotographicSensitivity"] = it }
                        for (t in listOf("FNumber", "ExposureTime", "FocalLength")) {
                            e.getAttributeDouble(t, -1.0).takeIf { it > 0 }?.let { values[t] = it }
                        }
                        val place = FloatArray(2)
                        if (e.getLatLong(place)) { values["lat"] = place[0].toDouble(); values["lon"] = place[1].toDouble() }
                        result.success(values)
                    }
                    "appVersion" -> {
                        val p = packageManager.getPackageInfo(packageName, 0)
                        result.success("${p.versionName} build.${p.longVersionCode}")
                    }
                    "checksums" -> {
                        // SHA-1 of the device photos, read straight from the file (unchanged, with location —
                        // ACCESS_MEDIA_LOCATION), as Immich keeps it as checksum (D-36).
                        val ids = call.argument<List<String>>("ids")!!
                        checksumThread.post {
                            val sums = mutableMapOf<String, String>()
                            for (id in ids) {
                                try {
                                    val uri = MediaStore.setRequireOriginal(
                                        ContentUris.withAppendedId(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, id.toLong()),
                                    )
                                    val sha = MessageDigest.getInstance("SHA-1")
                                    contentResolver.openInputStream(uri)?.use { input ->
                                        val buffer = ByteArray(1 shl 16)
                                        while (true) {
                                            val n = input.read(buffer)
                                            if (n < 0) break
                                            sha.update(buffer, 0, n)
                                        }
                                        sums[id] = Base64.encodeToString(sha.digest(), Base64.NO_WRAP)
                                    }
                                } catch (_: Exception) {
                                    // deleted or unreadable: missing from the answer
                                }
                            }
                            runOnUiThread { result.success(sums) }
                        }
                    }
                    "folderOwners" -> checksumThread.post {
                        // Per folder the app that made most of its photos (MediaStore's owner), if
                        // it made at least 60 % — groups e.g. all of Obsidian's attachment folders (D-61).
                        val counts = mutableMapOf<String, MutableMap<String?, Int>>()
                        contentResolver.query(
                            MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                            arrayOf(MediaStore.MediaColumns.RELATIVE_PATH, MediaStore.MediaColumns.OWNER_PACKAGE_NAME),
                            null, null, null,
                        )?.use { c ->
                            while (c.moveToNext()) {
                                val path = c.getString(0) ?: continue
                                counts.getOrPut(path) { mutableMapOf() }.merge(c.getString(1), 1, Int::plus)
                            }
                        }
                        val owners = mutableMapOf<String, String>()
                        for ((path, byOwner) in counts) {
                            val (owner, n) = byOwner.maxBy { it.value }
                            if (owner != null && n * 10 >= byOwner.values.sum() * 6) owners[path] = owner
                        }
                        runOnUiThread { result.success(owners) }
                    }
                    "appInfo" -> {
                        // Name and icon (PNG, 96 px) of the given apps; unknown or invisible ones are left out.
                        val pm = packageManager
                        result.success(call.argument<List<String>>("packages")!!.mapNotNull { p ->
                            try {
                                val info = pm.getApplicationInfo(p, 0)
                                val bitmap = Bitmap.createBitmap(96, 96, Bitmap.Config.ARGB_8888)
                                pm.getApplicationIcon(info).apply { setBounds(0, 0, 96, 96) }.draw(android.graphics.Canvas(bitmap))
                                val png = ByteArrayOutputStream().also { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
                                mapOf("package" to p, "label" to pm.getApplicationLabel(info).toString(), "icon" to png.toByteArray())
                            } catch (_: PackageManager.NameNotFoundException) {
                                null
                            }
                        })
                    }
                    "filesDir" -> result.success(filesDir.path)
                    "cacheDir" -> result.success(cacheDir.path)
                    "openUrl" -> try {
                        // Without a package Android asks ("Just once" / "Always"), D-52.
                        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(call.argument<String>("url")!!))
                        call.argument<String>("package")?.let { intent.setPackage(it) }
                        startActivity(intent)
                        result.success(true)
                    } catch (_: ActivityNotFoundException) {
                        result.success(false) // no app for it, e.g. without the Immich app
                    }
                    "urlHandlers" -> {
                        // Apps that open the link, e.g. Immich and Noodle Gallery for immich:// (D-52)
                        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(call.argument<String>("url")!!))
                        result.success(
                            packageManager.queryIntentActivities(intent, PackageManager.MATCH_ALL)
                                .map { mapOf("package" to it.activityInfo.packageName, "label" to it.loadLabel(packageManager).toString()) }
                                .distinctBy { it["package"] },
                        )
                    }
                    "isMetered" -> result.success(
                        getSystemService(ConnectivityManager::class.java).isActiveNetworkMetered,
                    )
                    "end" -> {
                        Session.end()
                        hdrMode(HdrImageView.active > 0) // back in the viewer, its HDR photo stays
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /** HDR window only when there is something to show (D-17). */
    private fun hdrWindow(on: Boolean) {
        hdrMode(on && Session.hasGainmap)
    }

    /**
     * Full resolution through the same renderer as the preview, then JPEG via the system
     * encoder (D-13). With HDR the original's gain map is attached, and compress writes
     * Ultra HDR (D-16, D-19).
     */
    private fun export(original: ByteArray, recipe: JSONObject, quality: Int, hdr: Boolean): ByteArray {
        val source = BitmapFactory.decodeByteArray(original, 0, original.size)
        val geo = Geometry.from(recipe).afterExif(Renderer.orientation(original))
        val rendered = Renderer.render(source, geo, recipe)
        val bitmap = rendered.copy(Bitmap.Config.ARGB_8888, true)
        rendered.recycle()
        if (hdr) source.gainmap?.let { bitmap.gainmap = Renderer.gainmap(it, geo) }
        source.recycle()
        val out = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.JPEG, quality, out)
        bitmap.recycle()
        return out.toByteArray()
    }
}
