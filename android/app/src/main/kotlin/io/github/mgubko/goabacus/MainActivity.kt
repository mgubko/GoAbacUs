package io.github.mgubko.goabacus

import android.os.Build
import android.view.Surface
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Reports the display rotation so the app can map the accelerometer
        // to screen axes (tablets and phones have different natural orientations).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "goabacus/display")
            .setMethodCallHandler { call, result ->
                if (call.method == "rotation") {
                    val rotation = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        display?.rotation ?: Surface.ROTATION_0
                    } else {
                        @Suppress("DEPRECATION")
                        windowManager.defaultDisplay.rotation
                    }
                    result.success(rotation)
                } else {
                    result.notImplemented()
                }
            }
    }
}
