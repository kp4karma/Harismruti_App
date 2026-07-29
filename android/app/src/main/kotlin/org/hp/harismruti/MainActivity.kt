package org.hp.harismruti

import android.app.WallpaperManager
import android.graphics.BitmapFactory
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val wallpaperExecutor = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            WALLPAPER_CHANNEL,
        ).setMethodCallHandler { call, result ->
            if (call.method != "setWallpaper") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val path = call.argument<String>("path")
            val destination = call.argument<String>("destination")
            if (path.isNullOrBlank() || destination.isNullOrBlank()) {
                result.error("INVALID_ARGUMENT", "A file and destination are required.", null)
                return@setMethodCallHandler
            }

            wallpaperExecutor.execute {
                try {
                    val imageFile = File(path)
                    val bitmap = BitmapFactory.decodeFile(imageFile.absolutePath)
                        ?: throw IllegalArgumentException("The downloaded image could not be opened.")
                    val wallpaperManager = WallpaperManager.getInstance(applicationContext)

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                        val flags = when (destination) {
                            "home" -> WallpaperManager.FLAG_SYSTEM
                            "lock" -> WallpaperManager.FLAG_LOCK
                            "both" -> WallpaperManager.FLAG_SYSTEM or WallpaperManager.FLAG_LOCK
                            else -> throw IllegalArgumentException("Unknown wallpaper destination.")
                        }
                        wallpaperManager.setBitmap(bitmap, null, true, flags)
                    } else {
                        if (destination != "home") {
                            throw UnsupportedOperationException(
                                "Lock screen wallpaper requires Android 7.0 or newer.",
                            )
                        }
                        wallpaperManager.setBitmap(bitmap)
                    }
                    bitmap.recycle()
                    runOnUiThread { result.success(true) }
                } catch (error: Exception) {
                    runOnUiThread {
                        result.error(
                            "SET_WALLPAPER_FAILED",
                            error.message ?: "Unable to set wallpaper.",
                            null,
                        )
                    }
                }
            }
        }
    }

    override fun onDestroy() {
        wallpaperExecutor.shutdown()
        super.onDestroy()
    }

    companion object {
        private const val WALLPAPER_CHANNEL = "org.hp.harismruti/wallpaper"
    }
}
