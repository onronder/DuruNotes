package com.fittechs.duruNotesApp

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.Bundle
import android.view.WindowManager
import android.content.Intent
import android.net.Uri
import android.util.Log
import android.content.Context
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import com.fittechs.duruNotesApp.R
import com.fittechs.durunotes.widget.QuickCaptureWidgetProvider
import com.fittechs.durunotes.widget.QuickCaptureWidgetStorage

class MainActivity : FlutterActivity() {
    companion object {
        private const val TAG = "MainActivity"
        private const val CHANNEL = "com.fittechs.durunotes/quick_capture"
    }

    private lateinit var methodChannel: MethodChannel
    private var pendingCaptureData: Map<String, Any>? = null
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Fix surface lifecycle issues
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        
        // Optimize rendering
        window.setFlags(
            WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
            WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED
        )

        // Handle widget launch intents
        handleWidgetIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Set up platform channel for widget communication
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "updateWidgetData" -> {
                    val data = call.arguments as? Map<*, *>
                    if (data != null) {
                        @Suppress("UNCHECKED_CAST")
                        QuickCaptureWidgetStorage.getInstance(this)
                            .writePayload(data as Map<String, Any?>)
                        refreshWidget()
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "Invalid widget payload", null)
                    }
                }
                "refreshWidget" -> {
                    refreshWidget()
                    result.success(true)
                }
                "getAuthStatus" -> {
                    result.success(getAuthStatus())
                }
                "getWidgetSettings" -> {
                    val widgetId = call.argument<Int>("widgetId") ?: -1
                    result.success(getWidgetSettings(widgetId))
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleWidgetIntent(intent)
    }
    
    override fun onPause() {
        super.onPause()
        // Ensure proper cleanup on pause
    }
    
    override fun onResume() {
        super.onResume()
        // Re-initialize on resume
        
        // Process any pending capture data
        pendingCaptureData?.let { data ->
            Log.d(TAG, "Processing pending capture data")
            methodChannel.invokeMethod("handleWidgetCapture", data)
            pendingCaptureData = null
        }
    }

    /**
     * Handle intents from widget
     */
    private fun handleWidgetIntent(intent: Intent?) {
        if (intent == null) return
        
        Log.d(TAG, "Handling intent: ${intent.action}, data: ${intent.data}")
        
        when (intent.action) {
            QuickCaptureWidgetProvider.ACTION_CAPTURE_TEXT,
            QuickCaptureWidgetProvider.ACTION_CAPTURE_VOICE,
            QuickCaptureWidgetProvider.ACTION_CAPTURE_CAMERA -> {
                handleCaptureIntent(intent)
            }
            QuickCaptureWidgetProvider.ACTION_OPEN_TEMPLATE -> {
                handleTemplateIntent(intent)
            }
            Intent.ACTION_VIEW -> {
                handleDeepLink(intent.data)
            }
            "com.fittechs.durunotes.REFRESH_WIDGET_DATA" -> {
                // Request data refresh from Flutter
                methodChannel.invokeMethod("requestWidgetDataRefresh", null)
            }
        }
    }

    /**
     * Handle capture intents from widget
     */
    private fun handleCaptureIntent(intent: Intent) {
        val captureType = when (intent.action) {
            QuickCaptureWidgetProvider.ACTION_CAPTURE_TEXT -> "text"
            QuickCaptureWidgetProvider.ACTION_CAPTURE_VOICE -> "voice"
            QuickCaptureWidgetProvider.ACTION_CAPTURE_CAMERA -> "camera"
            else -> "text"
        }
        
        val data: Map<String, Any> = mapOf(
            "type" to captureType,
            "source" to "widget",
            "widgetId" to intent.getIntExtra(QuickCaptureWidgetProvider.EXTRA_WIDGET_ID, -1)
        )

        // Store data to process when Flutter is ready
        if (flutterEngine?.dartExecutor?.binaryMessenger != null) {
            methodChannel.invokeMethod("handleWidgetCapture", data)
        } else {
            pendingCaptureData = data
        }
    }

    /**
     * Handle template selection from widget
     */
    private fun handleTemplateIntent(intent: Intent) {
        val templateId = intent.getStringExtra(QuickCaptureWidgetProvider.EXTRA_TEMPLATE_ID)
        
        val data: Map<String, Any> = mapOf(
            "type" to "template",
            "templateId" to (templateId ?: ""),
            "source" to "widget",
            "widgetId" to intent.getIntExtra(QuickCaptureWidgetProvider.EXTRA_WIDGET_ID, -1)
        )

        if (flutterEngine?.dartExecutor?.binaryMessenger != null) {
            methodChannel.invokeMethod("handleWidgetCapture", data)
        } else {
            pendingCaptureData = data
        }
    }

    /**
     * Handle deep links from widget
     */
    private fun handleDeepLink(uri: Uri?) {
        if (uri == null) return
        
        Log.d(TAG, "Handling deep link: $uri")
        
        // Parse the URI and extract parameters
        val path = uri.path ?: ""
        val segments = path.split("/").filter { it.isNotEmpty() }
        
        when {
            segments.firstOrNull() == "capture" -> {
                val captureType = segments.getOrNull(1) ?: "text"
                val data = mapOf(
                    "type" to captureType,
                    "source" to "widget",
                    "uri" to uri.toString()
                )
                methodChannel.invokeMethod("handleWidgetCapture", data)
            }
            segments.firstOrNull() == "note" -> {
                val noteId = segments.getOrNull(1)
                if (noteId != null) {
                    methodChannel.invokeMethod("openNote", mapOf("noteId" to noteId))
                }
            }
            segments.firstOrNull() == "captures" -> {
                methodChannel.invokeMethod("openCapturesList", mapOf("filter" to "widget"))
            }
        }
    }

    /**
     * Update widget data from Flutter
     */
    private fun updateWidgetData(data: Map<String, Any?>?) {
        if (data == null) return
        QuickCaptureWidgetStorage.getInstance(this).writePayload(data)
    }

    /**
     * Refresh all widgets
     */
    private fun refreshWidget() {
        Log.d(TAG, "Refreshing all widgets")
        
        val intent = Intent(this, QuickCaptureWidgetProvider::class.java)
        intent.action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
        
        val widgetManager = AppWidgetManager.getInstance(this)
        val widgetIds = widgetManager.getAppWidgetIds(
            ComponentName(this, QuickCaptureWidgetProvider::class.java)
        )
        
        widgetManager.notifyAppWidgetViewDataChanged(widgetIds, R.id.recent_captures_list)
        intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, widgetIds)
        sendBroadcast(intent)
    }

    /**
     * Get current auth status
     */
    private fun getAuthStatus(): Map<String, Any> {
        val storage = QuickCaptureWidgetStorage.getInstance(this)
        val userId = storage.getUserId()
        val authToken = storage.getAuthToken()
        return mapOf(
            "isAuthenticated" to (userId != null),
            "userId" to (userId ?: ""),
            "hasToken" to (authToken != null)
        )
    }

    /**
     * Save a pending capture for offline processing
     */
    /**
     * Get widget-specific settings
     */
    private fun getWidgetSettings(widgetId: Int): Map<String, Any> {
        val prefs = getSharedPreferences("QuickCaptureWidgetConfig$widgetId", Context.MODE_PRIVATE)
        
        return mapOf(
            "defaultCaptureType" to prefs.getString("default_capture_type", "text")!!,
            "showRecentCaptures" to prefs.getBoolean("show_recent_captures", true),
            "enableVoice" to prefs.getBoolean("enable_voice", true),
            "enableCamera" to prefs.getBoolean("enable_camera", true),
            "defaultTemplate" to prefs.getString("default_template", "none")!!,
            "theme" to prefs.getString("theme", "auto")!!
        )
    }
}
