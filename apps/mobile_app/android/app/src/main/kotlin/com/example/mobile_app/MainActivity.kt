package com.example.mobile_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.samsung.android.sdk.healthdata.*
import android.util.Log

class MainActivity : FlutterActivity() {
    private val SAMSUNG_HEALTH_CHANNEL = "samsung_health"
    private var healthDataService: HealthDataService? = null
    private var connectionListener: HealthDataService.ConnectionListener? = null
    
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
                    result.success(healthDataService?.isConnected ?: false)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
    
    private fun requestSamsungHealthPermission(result: MethodChannel.Result) {
        try {
            val healthDataStore = HealthDataStore(this, connectionListener)
            
            connectionListener = object : HealthDataService.ConnectionListener {
                override fun onConnected() {
                    Log.d("SamsungHealth", "Connected to Samsung Health")
                    
                    // Request permissions for step data and exercise data
                    val permissionKey = mutableSetOf<HealthPermissionManager.PermissionKey>()
                    
                    // Add step count permissions
                    permissionKey.add(
                        HealthPermissionManager.PermissionKey(
                            HealthConstants.StepCount.HEALTH_DATA_TYPE,
                            HealthPermissionManager.PermissionType.READ
                        )
                    )
                    
                    // Add exercise permissions
                    permissionKey.add(
                        HealthPermissionManager.PermissionKey(
                            HealthConstants.Exercise.HEALTH_DATA_TYPE,
                            HealthPermissionManager.PermissionType.READ
                        )
                    )
                    
                    try {
                        val permissionManager = HealthPermissionManager(healthDataStore)
                        permissionManager.requestPermissions(permissionKey, this@MainActivity)
                            .setResultCallback { permissionResult ->
                                if (permissionResult.resultStatus.isSuccess) {
                                    val granted = permissionKey.all { key ->
                                        permissionResult.isPermissionAcquired(key)
                                    }
                                    Log.d("SamsungHealth", "Permission request result: $granted")
                                    result.success(granted)
                                } else {
                                    Log.e("SamsungHealth", "Permission request failed: ${permissionResult.resultStatus}")
                                    result.success(false)
                                }
                            }
                    } catch (e: Exception) {
                        Log.e("SamsungHealth", "Error requesting permissions: ${e.message}")
                        result.success(false)
                    }
                }
                
                override fun onConnectionFailed(error: HealthConnectionErrorResult) {
                    Log.e("SamsungHealth", "Connection failed: ${error.errorCode}")
                    when (error.errorCode) {
                        HealthConnectionErrorResult.PLATFORM_NOT_INSTALLED -> {
                            Log.e("SamsungHealth", "Samsung Health not installed")
                        }
                        HealthConnectionErrorResult.OLD_VERSION_PLATFORM -> {
                            Log.e("SamsungHealth", "Samsung Health version too old")
                        }
                        HealthConnectionErrorResult.PLATFORM_DISABLED -> {
                            Log.e("SamsungHealth", "Samsung Health disabled")
                        }
                        else -> {
                            Log.e("SamsungHealth", "Unknown connection error")
                        }
                    }
                    result.success(false)
                }
                
                override fun onDisconnected() {
                    Log.d("SamsungHealth", "Disconnected from Samsung Health")
                }
            }
            
            healthDataService = healthDataStore
            healthDataStore.connectService()
            
        } catch (e: Exception) {
            Log.e("SamsungHealth", "Exception in requestPermission: ${e.message}")
            result.success(false)
        }
    }
    
    private fun checkSamsungHealthPermissions(result: MethodChannel.Result) {
        try {
            if (healthDataService?.isConnected != true) {
                Log.d("SamsungHealth", "Not connected to Samsung Health")
                result.success(false)
                return
            }
            
            val permissionKey = mutableSetOf<HealthPermissionManager.PermissionKey>()
            
            // Check step count permissions
            permissionKey.add(
                HealthPermissionManager.PermissionKey(
                    HealthConstants.StepCount.HEALTH_DATA_TYPE,
                    HealthPermissionManager.PermissionType.READ
                )
            )
            
            // Check exercise permissions
            permissionKey.add(
                HealthPermissionManager.PermissionKey(
                    HealthConstants.Exercise.HEALTH_DATA_TYPE,
                    HealthPermissionManager.PermissionType.READ
                )
            )
            
            val permissionManager = HealthPermissionManager(healthDataService!!)
            val granted = permissionKey.all { key ->
                permissionManager.isPermissionAcquired(key)
            }
            
            Log.d("SamsungHealth", "Permission check result: $granted")
            result.success(granted)
            
        } catch (e: Exception) {
            Log.e("SamsungHealth", "Exception in checkPermissions: ${e.message}")
            result.success(false)
        }
    }
}
