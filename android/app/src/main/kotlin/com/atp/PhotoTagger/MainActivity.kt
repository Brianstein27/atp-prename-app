package com.atp.PhotoTagger

import android.media.MediaScannerConnection
import android.os.Build
import android.os.Bundle
import android.os.Environment
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.atp.PhotoTagger/media_scan"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "scanFile" -> {
                        val path = call.argument<String>("path")
                        if (path != null) {
                            MediaScannerConnection.scanFile(
                                this,
                                arrayOf(path),
                                null
                            ) { _, _ -> }
                            result.success(true)
                        } else {
                            result.error("INVALID_PATH", "Pfad ist null", null)
                        }
                    }
                    "getSdkInt" -> result.success(Build.VERSION.SDK_INT)
                    "getLegacyDcim" -> result.success(
                        Environment.getExternalStoragePublicDirectory(
                            Environment.DIRECTORY_DCIM
                        )?.absolutePath
                    )
                    else -> result.notImplemented()
                }
            }
    }
}
