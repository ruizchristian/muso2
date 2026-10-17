package com.example.music

import android.content.ContentUris
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.provider.Settings
import android.util.Size
import androidx.core.content.FileProvider
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.Executors

private val artworkExecutor = Executors.newFixedThreadPool(2)

// audio_service needs its own activity subclass so the Flutter engine outlives the UI while
// music plays in the background.
class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Cover art embedded in audio files (lib/media/cover_art.dart). Decoding is slow, so it runs
        // off the main thread; two workers keep a fast scroll from queueing dozens of decodes.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "muso/artwork")
            .setMethodCallHandler { call, result ->
                if (call.method != "cover") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val ids = call.argument<List<String>>("ids").orEmpty()
                val size = call.argument<Int>("size") ?: 256
                artworkExecutor.execute {
                    val bytes = ids.firstNotNullOfOrNull { coverFor(it, size) }
                    runOnUiThread { result.success(bytes) }
                }
            }

        // In-app updates (lib/update/update_platform.dart). Downloading happens in Dart; this
        // only covers what Dart cannot do: read the versionCode and open the package installer.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "muso/updates")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "installedVersion" -> {
                        val info = packageInfo()
                        val build = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                            info.longVersionCode
                        } else {
                            @Suppress("DEPRECATION") info.versionCode.toLong()
                        }
                        result.success(mapOf("version" to info.versionName, "build" to build))
                    }

                    "cacheDirectory" -> result.success(cacheDir.absolutePath)

                    "canInstall" -> result.success(
                        Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
                            packageManager.canRequestPackageInstalls(),
                    )

                    "openInstallSettings" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startActivity(
                                Intent(
                                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                    Uri.parse("package:$packageName"),
                                ),
                            )
                        }
                        result.success(null)
                    }

                    "install" -> result.success(install(call.argument<String>("path")))

                    else -> result.notImplemented()
                }
            }
    }

    /** JPEG of the track's embedded cover, at most `size` px on its longer edge, or null. */
    private fun coverFor(id: String, size: Int): ByteArray? {
        val mediaId = id.toLongOrNull() ?: return null
        val uri = ContentUris.withAppendedId(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, mediaId)

        val bitmap = try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                // The media store's own thumbnailer: reads the embedded picture and caches it.
                // Throws when the file has no cover.
                contentResolver.loadThumbnail(uri, Size(size, size), null)
            } else {
                val retriever = MediaMetadataRetriever()
                try {
                    retriever.setDataSource(this, uri)
                    retriever.embeddedPicture?.let { decodeScaled(it, size) }
                } finally {
                    retriever.release()
                }
            }
        } catch (_: Exception) {
            null
        } ?: return null

        return ByteArrayOutputStream().use { out ->
            bitmap.compress(Bitmap.CompressFormat.JPEG, 88, out)
            out.toByteArray()
        }
    }

    private fun decodeScaled(data: ByteArray, size: Int): Bitmap? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(data, 0, data.size, bounds)
        var sample = 1
        while (maxOf(bounds.outWidth, bounds.outHeight) / (sample * 2) >= size) sample *= 2
        return BitmapFactory.decodeByteArray(
            data, 0, data.size, BitmapFactory.Options().apply { inSampleSize = sample },
        )
    }

    private fun packageInfo() =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.getPackageInfo(packageName, PackageManager.PackageInfoFlags.of(0))
        } else {
            @Suppress("DEPRECATION") packageManager.getPackageInfo(packageName, 0)
        }

    /** Opens the system installer on a downloaded APK. Android shows its own confirmation. */
    private fun install(path: String?): Boolean {
        if (path == null) return false
        return try {
            val uri = FileProvider.getUriForFile(this, "$packageName.updates", File(path))
            startActivity(
                Intent(Intent.ACTION_VIEW)
                    .setDataAndType(uri, "application/vnd.android.package-archive")
                    .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION),
            )
            true
        } catch (_: Exception) {
            false
        }
    }
}
