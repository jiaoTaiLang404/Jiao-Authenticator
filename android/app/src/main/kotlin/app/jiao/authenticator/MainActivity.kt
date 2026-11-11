
package app.jiao.authenticator

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PersistableBundle
import android.os.SystemClock
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

class MainActivity : FlutterFragmentActivity() {
    private val clipboard by lazy { getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager }
    private val handler = Handler(Looper.getMainLooper())
    private var ownedClip: String? = null
    private var clearAt = 0L
    private val clearTask = Runnable { clearExpiredClip() }
    // TEMP_SCREENSHOT_TOGGLE: remove captureResumed and the marked handlers.
    private var captureResumed = false

    override fun onCreate(savedInstanceState: Bundle?) {
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= 33) setRecentsScreenshotEnabled(false)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.jiao.authenticator/device")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // TEMP_SCREENSHOT_TOGGLE: remove this MethodChannel branch.
                    "setScreenshotAllowed" -> {
                        val allowed = call.arguments as? Boolean
                        if (allowed == null) {
                            result.error("invalid_screenshot_preference", null, null)
                        } else {
                            val flag = WindowManager.LayoutParams.FLAG_SECURE
                            if (allowed && captureResumed && hasWindowFocus()) {
                                window.clearFlags(flag)
                            } else {
                                window.addFlags(flag)
                            }
                            result.success(null)
                        }
                    }
                    "copyCode" -> {
                        val code = call.arguments as? String
                        if (code == null || !code.matches(Regex("[0-9]{6}|[0-9]{8}")) ||
                            !hasWindowFocus()) {
                            result.error("clipboard_unavailable", null, null)
                        } else {
                            val id = UUID.randomUUID().toString()
                            val clip = ClipData.newPlainText("Jiao Authenticator", code)
                            clip.description.extras = PersistableBundle().apply {
                                putBoolean("android.content.extra.IS_SENSITIVE", true)
                                putString("app.jiao.authenticator.clipId", id)
                            }
                            clipboard.setPrimaryClip(clip)
                            ownedClip = id
                            clearAt = SystemClock.elapsedRealtime() + 30_000L
                            handler.removeCallbacks(clearTask)
                            handler.postDelayed(clearTask, 30_000L)
                            result.success(null)
                        }
                    }
                    "openDeviceSecurity" -> {
                        try {
                            startActivity(Intent(Settings.ACTION_SECURITY_SETTINGS))
                            result.success(null)
                        } catch (_: android.content.ActivityNotFoundException) {
                            result.error("settings_unavailable", null, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // TEMP_SCREENSHOT_TOGGLE: remove these two overrides when retiring the switch.
    override fun onResume() {
        super.onResume()
        captureResumed = true
    }

    override fun onPause() {
        captureResumed = false
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        super.onPause()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        // TEMP_SCREENSHOT_TOGGLE: remove only this added line; keep clipboard cleanup.
        if (!hasFocus) window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) clearExpiredClip()
    }

    private fun clearExpiredClip() {
        val id = ownedClip ?: return
        if (!hasWindowFocus() || SystemClock.elapsedRealtime() < clearAt) return
        ownedClip = null
        if (clipboard.primaryClipDescription?.extras?.getString("app.jiao.authenticator.clipId") != id) {
            return
        }
        if (Build.VERSION.SDK_INT >= 28) {
            clipboard.clearPrimaryClip()
        } else {
            clipboard.setPrimaryClip(ClipData.newPlainText("", ""))
        }
    }

    override fun onDestroy() {
        handler.removeCallbacks(clearTask)
        super.onDestroy()
    }
}
