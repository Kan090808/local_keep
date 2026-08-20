package com.example.local_keep

import android.content.Intent
import android.os.Bundle
import android.view.WindowManager
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.local_keep/file_preview"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Prevent screenshots and recents thumbnails of sensitive content.
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "previewFile") {
                val filePath = call.argument<String>("filePath")
                if (filePath != null) {
                    try {
                        openFile(filePath)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("PREVIEW_FAILED", "Failed to open file: ${e.message}", null)
                    }
                } else {
                    result.error("INVALID_ARGUMENT", "File path is required", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun openFile(filePath: String) {
        val file = File(filePath)
        if (!file.exists()) {
            throw Exception("File does not exist: $filePath")
        }

        // Only allow files under the secure_preview cache subdirectory.
        val canonical = file.canonicalPath
        val previewRoot = File(cacheDir, "secure_preview").canonicalPath
        if (!canonical.startsWith(previewRoot)) {
            throw SecurityException("Preview path outside secure_preview directory")
        }

        val uri = FileProvider.getUriForFile(
            this,
            "${applicationContext.packageName}.fileprovider",
            file
        )

        val mimeType = contentResolver.getType(uri) ?: "*/*"

        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, mimeType)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }

        try {
            startActivity(intent)
        } catch (e: Exception) {
            val chooserIntent = Intent.createChooser(intent, "Open with")
            startActivity(chooserIntent)
        }
    }
}
