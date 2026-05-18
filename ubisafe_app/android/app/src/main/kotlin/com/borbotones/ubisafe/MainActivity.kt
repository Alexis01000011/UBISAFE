package com.borbotones.ubisafe

import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val channel = "ubisafe/config"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                if (call.method == "getMapsApiKey") {
                    try {
                        val appInfo = packageManager.getApplicationInfo(
                            packageName,
                            PackageManager.GET_META_DATA,
                        )
                        val key = appInfo.metaData
                            ?.getString("com.google.android.geo.API_KEY") ?: ""
                        result.success(key)
                    } catch (e: Exception) {
                        result.error("UNAVAILABLE", "Maps API key not found", null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }
}
