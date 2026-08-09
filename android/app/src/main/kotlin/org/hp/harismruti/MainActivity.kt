package org.hp.harismruti

import android.app.WallpaperManager
import android.content.Intent
import android.graphics.BitmapFactory
import android.os.Build
import androidx.core.content.FileProvider
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
            val path = call.argument<String>("path")
            if (path.isNullOrBlank()) {
                result.error("INVALID_ARGUMENT", "A wallpaper image file is required.", null)
                return@setMethodCallHandler
            }

            if (call.method == "openWallpaperEditor") {
                try {
                    val imageFile = File(path)
                    val imageUri = FileProvider.getUriForFile(
                        this,
                        "$packageName.wallpaper_files",
                        imageFile,
                    )
                    val intent = Intent(Intent.ACTION_ATTACH_DATA).apply {
                        setDataAndType(imageUri, "image/*")
                        putExtra("mimeType", "image/*")
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }
                    startActivity(intent)
                    result.success(true)
                } catch (error: Exception) {
                    result.error(
                        "OPEN_WALLPAPER_EDITOR_FAILED",
                        error.message ?: "The phone's wallpaper editor could not be opened.",
                        null,
                    )
                }
                return@setMethodCallHandler
            }

            if (call.method != "setWallpaper") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val destination = call.argument<String>("destination")
            if (destination.isNullOrBlank()) {
                result.error("INVALID_ARGUMENT", "A wallpaper destination is required.", null)
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

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            INSTAGRAM_STORY_CHANNEL,
        ).setMethodCallHandler { call, result ->
            if (call.method != "shareImage") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val path = call.argument<String>("path")
            if (path.isNullOrBlank()) {
                result.error("INVALID_ARGUMENT", "An image file is required.", null)
                return@setMethodCallHandler
            }
            try {
                val imageUri = FileProvider.getUriForFile(
                    this,
                    "$packageName.wallpaper_files",
                    File(path),
                )
                val intent = Intent("com.instagram.share.ADD_TO_STORY").apply {
                    setDataAndType(imageUri, "image/jpeg")
                    setPackage("com.instagram.android")
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    clipData = android.content.ClipData.newRawUri("story", imageUri)
                }
                if (intent.resolveActivity(packageManager) == null) {
                    result.success(false)
                } else {
                    grantUriPermission(
                        "com.instagram.android",
                        imageUri,
                        Intent.FLAG_GRANT_READ_URI_PERMISSION,
                    )
                    startActivity(intent)
                    result.success(true)
                }
            } catch (error: Exception) {
                result.error(
                    "INSTAGRAM_SHARE_FAILED",
                    error.message ?: "Unable to open Instagram Stories.",
                    null,
                )
            }
        }
    }

    override fun onDestroy() {
        wallpaperExecutor.shutdown()
        super.onDestroy()
    }

    companion object {
        private const val WALLPAPER_CHANNEL = "org.hp.harismruti/wallpaper"
        private const val INSTAGRAM_STORY_CHANNEL = "org.hp.harismruti/instagram_story"
    }
}
