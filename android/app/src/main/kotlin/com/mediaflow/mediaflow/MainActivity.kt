package com.mediaflow.mediaflow

import android.Manifest
import android.content.ContentValues
import android.content.pm.PackageManager
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.annotation.RequiresApi
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private data class PendingPublish(
        val sourcePath: String,
        val displayName: String,
        val mimeType: String,
        val result: MethodChannel.Result,
    )

    private var pendingPublish: PendingPublish? = null
    private var browserObservationHost: AndroidBrowserObservationHost? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        browserObservationHost = AndroidBrowserObservationHost(
            activity = this,
            messenger = flutterEngine.dartExecutor.binaryMessenger,
        )
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            STORAGE_CHANNEL,
        ).setMethodCallHandler { call, result ->
            if (call.method != "publishToDownloads") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val sourcePath = call.argument<String>("sourcePath")
            val displayName = call.argument<String>("displayName")
            val mimeType = call.argument<String>("mimeType")
            if (sourcePath.isNullOrBlank() || displayName.isNullOrBlank() || mimeType.isNullOrBlank()) {
                result.error("invalid_arguments", "Missing source file, display name, or media type.", null)
                return@setMethodCallHandler
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q || hasLegacyStoragePermission()) {
                publishAsync(sourcePath, displayName, mimeType, result)
                return@setMethodCallHandler
            }

            if (pendingPublish != null) {
                result.error("storage_busy", "Another file is waiting for storage permission.", null)
                return@setMethodCallHandler
            }
            pendingPublish = PendingPublish(sourcePath, displayName, mimeType, result)
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE),
                STORAGE_PERMISSION_REQUEST,
            )
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        browserObservationHost?.dispose()
        browserObservationHost = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != STORAGE_PERMISSION_REQUEST) {
            return
        }
        val pending = pendingPublish ?: return
        pendingPublish = null
        if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
            publishAsync(
                pending.sourcePath,
                pending.displayName,
                pending.mimeType,
                pending.result,
            )
        } else {
            pending.result.error(
                "storage_permission_denied",
                "Storage permission is required to save to Download/MediaFlow.",
                null,
            )
        }
    }

    private fun publishAsync(
        sourcePath: String,
        displayName: String,
        mimeType: String,
        result: MethodChannel.Result,
    ) {
        Thread {
            try {
                val published = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    publishWithMediaStore(sourcePath, displayName, mimeType)
                } else {
                    publishLegacy(sourcePath, displayName, mimeType)
                }
                runOnUiThread { result.success(published) }
            } catch (error: Exception) {
                runOnUiThread {
                    result.error(
                        "publish_failed",
                        error.message ?: "Failed to save to Download/MediaFlow.",
                        null,
                    )
                }
            }
        }.start()
    }

    @RequiresApi(Build.VERSION_CODES.Q)
    private fun publishWithMediaStore(
        sourcePath: String,
        displayName: String,
        mimeType: String,
    ): Map<String, String> {
        val source = File(sourcePath)
        require(source.isFile) { "The media file to publish does not exist." }

        val resolver = applicationContext.contentResolver
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, displayName)
            put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
            put(
                MediaStore.MediaColumns.RELATIVE_PATH,
                "${Environment.DIRECTORY_DOWNLOADS}/MediaFlow",
            )
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }
        val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
            ?: error("Missing source file, display name, or media type.??")

        try {
            resolver.openOutputStream(uri, "w")?.use { output ->
                source.inputStream().use { input -> input.copyTo(output) }
            } ?: error("Unable to open the system download file.")

            values.clear()
            values.put(MediaStore.MediaColumns.IS_PENDING, 0)
            resolver.update(uri, values, null, null)

            val actualName = resolver.query(
                uri,
                arrayOf(MediaStore.MediaColumns.DISPLAY_NAME),
                null,
                null,
                null,
            )?.use { cursor ->
                if (cursor.moveToFirst()) cursor.getString(0) else null
            } ?: displayName
            val publicPath = File(
                Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
                "MediaFlow/$actualName",
            ).absolutePath
            return mapOf("path" to publicPath, "uri" to uri.toString())
        } catch (error: Exception) {
            resolver.delete(uri, null, null)
            throw error
        }
    }

    @Suppress("DEPRECATION")
    private fun publishLegacy(
        sourcePath: String,
        displayName: String,
        mimeType: String,
    ): Map<String, String> {
        val source = File(sourcePath)
        require(source.isFile) { "The media file to publish does not exist." }
        val directory = File(
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
            "MediaFlow",
        )
        check(directory.exists() || directory.mkdirs()) { "Unable to create Download/MediaFlow." }
        val target = uniqueFile(directory, displayName)
        source.copyTo(target, overwrite = false)
        MediaScannerConnection.scanFile(
            applicationContext,
            arrayOf(target.absolutePath),
            arrayOf(mimeType),
            null,
        )
        return mapOf("path" to target.absolutePath, "uri" to target.toURI().toString())
    }

    private fun uniqueFile(directory: File, displayName: String): File {
        val dotIndex = displayName.lastIndexOf('.')
        val name = if (dotIndex < 0) displayName else displayName.substring(0, dotIndex)
        val extension = if (dotIndex < 0) "" else displayName.substring(dotIndex)
        var index = 0
        while (true) {
            val suffix = if (index == 0) "" else " ($index)"
            val candidate = File(directory, "$name$suffix$extension")
            if (!candidate.exists()) {
                return candidate
            }
            index += 1
        }
    }

    private fun hasLegacyStoragePermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.WRITE_EXTERNAL_STORAGE,
        ) == PackageManager.PERMISSION_GRANTED
    }

    companion object {
        private const val STORAGE_CHANNEL = "com.mediaflow.mediaflow/storage"
        private const val STORAGE_PERMISSION_REQUEST = 1043
    }
}
