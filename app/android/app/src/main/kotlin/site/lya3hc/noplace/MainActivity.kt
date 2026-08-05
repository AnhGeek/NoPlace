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
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * The things a walk needs from Android that no plugin in this project provides.
 *
 * ## Keeping the walk recording
 *
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
 * ## Getting the walk off the phone
 *
 * Backup and restore need the system's own save and open dialogs. From
 * Android 11 the app's private storage is not reachable from a file manager, so
 * a backup written somewhere of our choosing is one the player cannot actually
 * get at — the whole point of it is that they can put it on a computer, a
 * memory card or a cloud drive. The Storage Access Framework does exactly that
 * in two Intents, and asks for no permission at all: the player picking the
 * file *is* the grant.
 *
 * All of it is Android-only and none of it has a plugin in this project, so it
 * lives here behind one channel rather than pulling in a dependency for five
 * calls.
 */
class MainActivity : FlutterActivity() {
    private companion object {
        const val CHANNEL = "site.lya3hc.noplace/background_tracking"
        const val NOTIFICATION_PERMISSION_REQUEST = 4242
        const val SAVE_DOCUMENT_REQUEST = 4243
        const val OPEN_DOCUMENT_REQUEST = 4244
    }

    /** Answered from [onRequestPermissionsResult], so Dart learns the outcome. */
    private var pendingNotificationResult: MethodChannel.Result? = null

    /** Answered from [onActivityResult], once the player has picked a file. */
    private var pendingDocumentResult: MethodChannel.Result? = null

    /**
     * What to write once there is somewhere to write it.
     *
     * The dialog comes back through [onActivityResult] with a URI and nothing
     * else, so the bytes have to wait here between the two halves of the call.
     */
    private var pendingDocumentBytes: ByteArray? = null

    /** Reading and writing a backup off the main thread, one file at a time. */
    private val documentIo: ExecutorService = Executors.newSingleThreadExecutor()

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
            "saveDocument" -> saveDocument(call, result)
            "openDocument" -> openDocument(result)
            else -> result.notImplemented()
        }
    }

    /**
     * Asks the player where to put a file, then writes it there.
     *
     * `ACTION_CREATE_DOCUMENT` lets them choose any provider on the device —
     * Downloads, an SD card, Drive — and grants us write access to that one URI
     * and nothing else.
     */
    private fun saveDocument(call: MethodCall, result: MethodChannel.Result) {
        val bytes = call.argument<ByteArray>("bytes")
        if (bytes == null) {
            result.error("no_bytes", "saveDocument needs bytes to write", null)
            return
        }
        if (!claimDocumentCall(result)) return

        pendingDocumentBytes = bytes

        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = call.argument<String>("mimeType") ?: "application/octet-stream"
            putExtra(Intent.EXTRA_TITLE, call.argument<String>("fileName"))
        }
        startActivityForResult(intent, SAVE_DOCUMENT_REQUEST)
    }

    /** Asks the player for a file and hands its bytes back. */
    private fun openDocument(result: MethodChannel.Result) {
        if (!claimDocumentCall(result)) return

        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            // Not filtered: a backup's extension has no registered MIME type, so
            // anything narrower greys out the only file worth picking. Dart
            // refuses a file that is not a backup, which is the check that can
            // actually tell.
            type = "*/*"
        }
        startActivityForResult(intent, OPEN_DOCUMENT_REQUEST)
    }

    /**
     * Makes [result] the one owner of the dialog, or refuses.
     *
     * Two dialogs cannot be up at once, and the second call would otherwise
     * strand the first result forever — a screen stuck on its spinner.
     */
    private fun claimDocumentCall(result: MethodChannel.Result): Boolean {
        if (pendingDocumentResult != null) {
            result.error("busy", "A file dialog is already open", null)
            return false
        }
        pendingDocumentResult = result
        return true
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != SAVE_DOCUMENT_REQUEST && requestCode != OPEN_DOCUMENT_REQUEST) {
            return
        }

        val result = pendingDocumentResult ?: return
        pendingDocumentResult = null
        val bytes = pendingDocumentBytes
        pendingDocumentBytes = null

        val uri = data?.data
        // Backing out of the dialog is an answer, not a failure: null tells Dart
        // the player changed their mind, and nothing is said on screen.
        if (resultCode != RESULT_OK || uri == null) {
            result.success(null)
            return
        }

        // A backup is megabytes. Copying it on the main thread is a frozen UI
        // for as long as it takes, on the one screen whose whole job is to look
        // reliable.
        documentIo.execute {
            try {
                val answer: Any? = if (requestCode == SAVE_DOCUMENT_REQUEST) {
                    contentResolver.openOutputStream(uri).use { stream ->
                        requireNotNull(stream) { "no output stream for $uri" }
                        stream.write(requireNotNull(bytes))
                    }
                    true
                } else {
                    contentResolver.openInputStream(uri).use { stream ->
                        requireNotNull(stream) { "no input stream for $uri" }
                        stream.readBytes()
                    }
                }
                runOnUiThread { result.success(answer) }
            } catch (error: Exception) {
                runOnUiThread {
                    result.error("io_failed", error.message, null)
                }
            }
        }
    }

    override fun onDestroy() {
        documentIo.shutdown()
        super.onDestroy()
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
