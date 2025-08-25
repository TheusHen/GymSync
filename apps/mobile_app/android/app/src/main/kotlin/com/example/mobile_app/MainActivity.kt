package com.example.mobile_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.util.Log

class MainActivity : FlutterActivity() {
    private val SAMSUNG_HEALTH_CHANNEL = "samsung_health"
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SAMSUNG_HEALTH_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestPermission" -> {
                    requestSamsungHealthPermission(result)
                }
                "checkPermissions" -> {
                    checkSamsungHealthPermissions(result)
                }
                "isConnected" -> {
                    result.success(false) // Samsung Health SDK not available
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
    
    private fun requestSamsungHealthPermission(result: MethodChannel.Result) {
        try {
            Log.d("SamsungHealth", "Samsung Health SDK not available - this is a placeholder implementation")
            Log.d("SamsungHealth", "Falling back to basic health functionality")
            
            // Since Samsung Health SDK is not available, we'll return false
            // This will trigger fallback to Google Fit in the Flutter code
            result.success(false)
            
        } catch (e: Exception) {
            Log.e("SamsungHealth", "Exception in requestPermission: ${e.message}")
            result.success(false)
        }
    }
    
    private fun checkSamsungHealthPermissions(result: MethodChannel.Result) {
        try {
            Log.d("SamsungHealth", "Samsung Health SDK not available - permission check returning false")
            
            // Since Samsung Health SDK is not available, we'll return false
            // This will trigger fallback to Google Fit in the Flutter code
            result.success(false)
            
        } catch (e: Exception) {
            Log.e("SamsungHealth", "Exception in checkPermissions: ${e.message}")
            result.success(false)
        }
    }
}
