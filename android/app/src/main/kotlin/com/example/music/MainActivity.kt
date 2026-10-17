package com.example.music

import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

// audio_service needs its own activity subclass so the Flutter engine outlives the UI while
// music plays in the background.
class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

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
