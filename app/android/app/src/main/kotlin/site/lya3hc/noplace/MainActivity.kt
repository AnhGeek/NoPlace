package site.lya3hc.noplace

import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * The two things a walk with the screen off needs that `geolocator` cannot ask
 * for on its own.
 *
 * The location foreground service is what keeps fixes arriving while NoPlace is
 * not visible (see docs/adr/0009-real-location.md), but it only survives if:
 *
 *  * its notification can actually be posted — from Android 13 that needs
 *    `POST_NOTIFICATIONS`, and a foreground service whose notification is
 *    suppressed is the first thing the system decides it can do without; and
 *  * the OEM's battery manager is not allowed to doze the process — on Samsung,
 *    Xiaomi and Oppo an unexempted app is put to sleep minutes after the screen
 *    goes off, which is exactly a walk that comes back with a hole in it.
 *
 * Both are Android-only and neither has a plugin in this project, so they live
 * here behind one channel rather than pulling in a dependency for three calls.
 */
class MainActivity : FlutterActivity() {
    private companion object {
        const val CHANNEL = "site.lya3hc.noplace/background_tracking"
        const val NOTIFICATION_PERMISSION_REQUEST = 4242
    }

    /** Answered from [onRequestPermissionsResult], so Dart learns the outcome. */
    private var pendingNotificationResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result -> onMethodCall(call, result) }
    }

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "ensureNotificationPermission" -> ensureNotificationPermission(result)
            "isBatteryOptimised" -> result.success(isBatteryOptimised())
            "requestBatteryExemption" -> {
                requestBatteryExemption()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    /**
     * Grants-or-asks for the ongoing notification, and reports whether it can
     * be shown. Below Android 13 there is nothing to ask for.
     */
    private fun ensureNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(true)
            return
        }

        val permission = android.Manifest.permission.POST_NOTIFICATIONS
        if (checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED) {
            result.success(true)
            return
        }

        // A second ask while the first prompt is still up would strand the
        // first result. Answering it "not yet" is truthful and leaves one owner.
        pendingNotificationResult?.success(false)
        pendingNotificationResult = result
        requestPermissions(arrayOf(permission), NOTIFICATION_PERMISSION_REQUEST)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != NOTIFICATION_PERMISSION_REQUEST) return

        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        pendingNotificationResult?.success(granted)
        pendingNotificationResult = null
    }

    /**
     * Whether the system is still free to doze this process. False also when
     * the API predates Doze, which is the same thing from Dart's point of view:
     * nothing to ask the player for.
     */
    private fun isBatteryOptimised(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return false
        val power = getSystemService(PowerManager::class.java) ?: return false
        return !power.isIgnoringBatteryOptimizations(packageName)
    }

    /**
     * Asks to be exempted. The direct dialog is a one-tap yes; where it does not
     * resolve — some OEM builds remove it — fall back to the settings list,
     * which always exists.
     */
    private fun requestBatteryExemption() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return

        val direct = Intent(
            Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
            Uri.parse("package:$packageName"),
        )
        if (direct.resolveActivity(packageManager) != null) {
            startActivity(direct)
            return
        }

        startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
    }
}
