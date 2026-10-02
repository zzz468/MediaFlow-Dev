package com.mediaflow.research.v050.feasibility

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.ContentValues
import android.content.Intent
import android.media.MediaExtractor
import android.media.MediaFormat
import android.net.Uri
import android.os.Environment
import android.provider.MediaStore
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mediaflow.research.v050/storage")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "directory" -> result.success(filesDir.absolutePath)
                        "inspect" -> {
                            val file = ownedFile(call.argument<String>("path")!!)
                            val mime = call.argument<String>("mime") ?: ""
                            if (mime.startsWith("image/")) {
                                val bitmap = android.graphics.BitmapFactory.decodeFile(file.absolutePath)
                                    ?: error("Image decode failed")
                                result.success(mapOf("width" to bitmap.width, "height" to bitmap.height))
                                bitmap.recycle()
                            } else {
                                val extractor = MediaExtractor()
                                try {
                                    extractor.setDataSource(file.absolutePath)
                                    val tracks = (0 until extractor.trackCount).map { index ->
                                        val format = extractor.getTrackFormat(index)
                                        format.getString(MediaFormat.KEY_MIME)
                                    }
                                    result.success(tracks)
                                } finally { extractor.release() }
                            }
                        }
                        "publish" -> {
                            require(android.os.Build.VERSION.SDK_INT >= 29) { "Research MediaStore requires Android 10+" }
                            val file = ownedFile(call.argument<String>("path")!!)
                            val name = call.argument<String>("name")!!
                            require(name == File(name).name)
                            val values = ContentValues().apply {
                                put(MediaStore.MediaColumns.DISPLAY_NAME, name)
                                put(MediaStore.MediaColumns.MIME_TYPE, call.argument<String>("mime"))
                                put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/MediaFlow-v050-PoC")
                                put(MediaStore.MediaColumns.IS_PENDING, 1)
                            }
                            val uri = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                                ?: error("MediaStore insert failed")
                            try {
                                contentResolver.openOutputStream(uri)!!.use { output -> file.inputStream().use { it.copyTo(output) } }
                                values.clear(); values.put(MediaStore.MediaColumns.IS_PENDING, 0)
                                contentResolver.update(uri, values, null, null)
                                result.success(uri.toString())
                            } catch (error: Exception) {
                                contentResolver.delete(uri, null, null)
                                throw error
                            }
                        }
                        "open" -> {
                            val uri = Uri.parse(call.argument<String>("uri")!!)
                            require(uri.scheme == "content" && uri.authority == "media")
                            startActivity(Intent(Intent.ACTION_VIEW).setDataAndType(uri, call.argument<String>("mime"))
                                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION))
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) { result.error("PROBE_ERROR", error.javaClass.simpleName, null) }
            }
    }
    private fun ownedFile(path: String): File {
        val file = File(path).canonicalFile
        require(file.toPath().startsWith(filesDir.canonicalFile.toPath()))
        return file
    }
}
