package com.example.inventario_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.logistock/apk_path"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getApkPath") {
                try {
                    val apkPath = context.packageResourcePath
                    result.success(apkPath)
                } catch (e: Exception) {
                    result.error("UNAVAILABLE", "No se pudo obtener la ruta del APK", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
