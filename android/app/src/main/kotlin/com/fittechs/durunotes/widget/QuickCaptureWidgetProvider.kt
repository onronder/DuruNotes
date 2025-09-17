package com.fittechs.durunotes.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.widget.RemoteViews
import com.fittechs.durunotes.MainActivity
import com.fittechs.durunotes.R
import android.util.Log
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.*

/**
 * Production-grade Android App Widget Provider for Quick Capture
 * Handles widget lifecycle, updates, and user interactions
 */
class QuickCaptureWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val TAG = "QuickCaptureWidget"
        
        // Action constants
        const val ACTION_CAPTURE_TEXT = "com.fittechs.durunotes.CAPTURE_TEXT"
        const val ACTION_CAPTURE_VOICE = "com.fittechs.durunotes.CAPTURE_VOICE"
        const val ACTION_CAPTURE_CAMERA = "com.fittechs.durunotes.CAPTURE_CAMERA"
        const val ACTION_OPEN_TEMPLATE = "com.fittechs.durunotes.OPEN_TEMPLATE"
        const val ACTION_REFRESH = "com.fittechs.durunotes.REFRESH_WIDGET"
        const val ACTION_OPEN_NOTE = "com.fittechs.durunotes.OPEN_NOTE"
        const val ACTION_VIEW_ALL = "com.fittechs.durunotes.VIEW_ALL"
        const val ACTION_SETTINGS = "com.fittechs.durunotes.WIDGET_SETTINGS"
        const val ACTION_UPDATE_FROM_APP = "com.fittechs.durunotes.UPDATE_WIDGET_DATA"
        
        // Extra keys
        const val EXTRA_CAPTURE_TYPE = "capture_type"
        const val EXTRA_TEMPLATE_ID = "template_id"
        const val EXTRA_NOTE_ID = "note_id"
        const val EXTRA_WIDGET_ID = "widget_id"
        
        // SharedPreferences keys
        const val PREFS_NAME = "QuickCaptureWidget"
        const val PREF_AUTH_TOKEN = "auth_token"
        const val PREF_USER_ID = "user_id"
        const val PREF_RECENT_CAPTURES = "recent_captures"
        const val PREF_TEMPLATES = "templates"
        const val PREF_LAST_SYNC = "last_sync"
        const val PREF_OFFLINE_QUEUE = "offline_queue"
        
        // Widget size thresholds (dp)
        const val WIDGET_SIZE_SMALL_MAX = 110
        const val WIDGET_SIZE_MEDIUM_MAX = 250
        
        /**
         * Force update all widgets
         */
        fun updateAllWidgets(context: Context) {
            val intent = Intent(context, QuickCaptureWidgetProvider::class.java)
            intent.action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            val widgetManager = AppWidgetManager.getInstance(context)
            val widgetIds = widgetManager.getAppWidgetIds(
                ComponentName(context, QuickCaptureWidgetProvider::class.java)
            )
            intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, widgetIds)
            context.sendBroadcast(intent)
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        Log.d(TAG, "onUpdate called for widgets: ${appWidgetIds.joinToString()}")
        
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        
        Log.d(TAG, "onReceive: ${intent.action}")
        
        when (intent.action) {
            ACTION_CAPTURE_TEXT -> handleCaptureText(context, intent)
            ACTION_CAPTURE_VOICE -> handleCaptureVoice(context, intent)
            ACTION_CAPTURE_CAMERA -> handleCaptureCamera(context, intent)
            ACTION_OPEN_TEMPLATE -> handleOpenTemplate(context, intent)
            ACTION_REFRESH -> handleRefresh(context, intent)
            ACTION_OPEN_NOTE -> handleOpenNote(context, intent)
            ACTION_VIEW_ALL -> handleViewAll(context, intent)
            ACTION_SETTINGS -> handleSettings(context, intent)
            ACTION_UPDATE_FROM_APP -> handleUpdateFromApp(context, intent)
        }
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        Log.d(TAG, "Widget enabled - first widget added")
        
        // Initialize widget data
        initializeWidgetData(context)
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        Log.d(TAG, "Widget disabled - last widget removed")
        
        // Clean up widget data (but keep offline queue)
        cleanupWidgetData(context, keepOfflineQueue = true)
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)
        Log.d(TAG, "Widgets deleted: ${appWidgetIds.joinToString()}")
    }

    /**
     * Update a specific widget
     */
    private fun updateWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        val widgetSize = getWidgetSize(context, appWidgetManager, appWidgetId)
        val views = when (widgetSize) {
            WidgetSize.SMALL -> createSmallWidgetViews(context, appWidgetId)
            WidgetSize.MEDIUM -> createMediumWidgetViews(context, appWidgetId)
            WidgetSize.LARGE -> createLargeWidgetViews(context, appWidgetId)
        }
        
        // Update widget data
        updateWidgetData(context, views, widgetSize)
        
        // Apply the update
        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    /**
     * Determine widget size based on dimensions
     */
    private fun getWidgetSize(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ): WidgetSize {
        val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
        val minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
        
        return when {
            minWidth <= WIDGET_SIZE_SMALL_MAX -> WidgetSize.SMALL
            minWidth <= WIDGET_SIZE_MEDIUM_MAX -> WidgetSize.MEDIUM
            else -> WidgetSize.LARGE
        }
    }

    /**
     * Create RemoteViews for small widget
     */
    private fun createSmallWidgetViews(context: Context, appWidgetId: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_quick_capture_small)
        
        // Set up capture button
        val captureIntent = Intent(context, MainActivity::class.java).apply {
            action = ACTION_CAPTURE_TEXT
            data = Uri.parse("durunotes://capture/text?widget=$appWidgetId")
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        
        val pendingIntent = PendingIntent.getActivity(
            context,
            appWidgetId,
            captureIntent,
            getPendingIntentFlags()
        )
        
        views.setOnClickPendingIntent(R.id.capture_button, pendingIntent)
        
        return views
    }

    /**
     * Create RemoteViews for medium widget
     */
    private fun createMediumWidgetViews(context: Context, appWidgetId: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_quick_capture_medium)
        
        // Text capture button
        val textIntent = createCaptureIntent(context, ACTION_CAPTURE_TEXT, appWidgetId)
        views.setOnClickPendingIntent(R.id.capture_text_button, textIntent)
        
        // Voice capture button
        val voiceIntent = createCaptureIntent(context, ACTION_CAPTURE_VOICE, appWidgetId)
        views.setOnClickPendingIntent(R.id.capture_voice_button, voiceIntent)
        
        // Settings button
        val settingsIntent = createActionIntent(context, ACTION_SETTINGS, appWidgetId)
        views.setOnClickPendingIntent(R.id.settings_button, settingsIntent)
        
        return views
    }

    /**
     * Create RemoteViews for large widget
     */
    private fun createLargeWidgetViews(context: Context, appWidgetId: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_quick_capture_large)
        
        // Capture buttons
        val textIntent = createCaptureIntent(context, ACTION_CAPTURE_TEXT, appWidgetId)
        views.setOnClickPendingIntent(R.id.capture_text_button, textIntent)
        
        val voiceIntent = createCaptureIntent(context, ACTION_CAPTURE_VOICE, appWidgetId)
        views.setOnClickPendingIntent(R.id.capture_voice_button, voiceIntent)
        
        val cameraIntent = createCaptureIntent(context, ACTION_CAPTURE_CAMERA, appWidgetId)
        views.setOnClickPendingIntent(R.id.capture_camera_button, cameraIntent)
        
        // Template buttons
        views.setOnClickPendingIntent(
            R.id.template_meeting,
            createTemplateIntent(context, "meeting", appWidgetId)
        )
        views.setOnClickPendingIntent(
            R.id.template_idea,
            createTemplateIntent(context, "idea", appWidgetId)
        )
        views.setOnClickPendingIntent(
            R.id.template_task,
            createTemplateIntent(context, "task", appWidgetId)
        )
        
        // Control buttons
        val refreshIntent = createActionIntent(context, ACTION_REFRESH, appWidgetId)
        views.setOnClickPendingIntent(R.id.refresh_button, refreshIntent)
        
        val settingsIntent = createActionIntent(context, ACTION_SETTINGS, appWidgetId)
        views.setOnClickPendingIntent(R.id.settings_button, settingsIntent)
        
        val viewAllIntent = createActionIntent(context, ACTION_VIEW_ALL, appWidgetId)
        views.setOnClickPendingIntent(R.id.view_all_button, viewAllIntent)
        
        // Set up ListView for recent captures
        val serviceIntent = Intent(context, QuickCaptureRemoteViewsService::class.java).apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
        }
        views.setRemoteAdapter(R.id.recent_captures_list, serviceIntent)
        
        // Set pending intent template for list items
        val noteIntent = Intent(context, QuickCaptureWidgetProvider::class.java).apply {
            action = ACTION_OPEN_NOTE
            putExtra(EXTRA_WIDGET_ID, appWidgetId)
        }
        val notePendingIntent = PendingIntent.getBroadcast(
            context,
            0,
            noteIntent,
            getPendingIntentFlags()
        )
        views.setPendingIntentTemplate(R.id.recent_captures_list, notePendingIntent)
        
        return views
    }

    /**
     * Update widget with latest data
     */
    private fun updateWidgetData(context: Context, views: RemoteViews, size: WidgetSize) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        
        // Check authentication status
        val isAuthenticated = prefs.getString(PREF_AUTH_TOKEN, null) != null
        
        if (!isAuthenticated) {
            // Show login prompt
            views.setTextViewText(
                when (size) {
                    WidgetSize.SMALL -> R.id.widget_title
                    WidgetSize.MEDIUM -> R.id.widget_title
                    WidgetSize.LARGE -> R.id.widget_subtitle
                },
                context.getString(R.string.widget_login_required)
            )
            return
        }
        
        // Update last sync time for large widget
        if (size == WidgetSize.LARGE) {
            val lastSync = prefs.getLong(PREF_LAST_SYNC, 0)
            if (lastSync > 0) {
                val formatter = SimpleDateFormat("MMM d, h:mm a", Locale.getDefault())
                val syncText = "Last sync: ${formatter.format(Date(lastSync))}"
                views.setTextViewText(R.id.widget_subtitle, syncText)
            }
        }
        
        // Update recent captures count for medium widget
        if (size == WidgetSize.MEDIUM) {
            val recentCaptures = getRecentCaptures(context)
            if (recentCaptures.isEmpty()) {
                views.setViewVisibility(R.id.no_captures_text, RemoteViews.VISIBLE)
            } else {
                views.setViewVisibility(R.id.no_captures_text, RemoteViews.GONE)
            }
        }
        
        // Check for offline queue
        val offlineQueue = getOfflineQueue(context)
        if (offlineQueue.isNotEmpty()) {
            // Show offline indicator
            Log.d(TAG, "Offline queue has ${offlineQueue.size} items")
        }
    }

    /**
     * Handle text capture action
     */
    private fun handleCaptureText(context: Context, intent: Intent) {
        Log.d(TAG, "Handling text capture")
        
        val launchIntent = Intent(context, MainActivity::class.java).apply {
            action = ACTION_CAPTURE_TEXT
            data = Uri.parse("durunotes://capture/text")
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtras(intent.extras ?: android.os.Bundle())
        }
        
        context.startActivity(launchIntent)
    }

    /**
     * Handle voice capture action
     */
    private fun handleCaptureVoice(context: Context, intent: Intent) {
        Log.d(TAG, "Handling voice capture")
        
        val launchIntent = Intent(context, MainActivity::class.java).apply {
            action = ACTION_CAPTURE_VOICE
            data = Uri.parse("durunotes://capture/voice")
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtras(intent.extras ?: android.os.Bundle())
        }
        
        context.startActivity(launchIntent)
    }

    /**
     * Handle camera capture action
     */
    private fun handleCaptureCamera(context: Context, intent: Intent) {
        Log.d(TAG, "Handling camera capture")
        
        val launchIntent = Intent(context, MainActivity::class.java).apply {
            action = ACTION_CAPTURE_CAMERA
            data = Uri.parse("durunotes://capture/camera")
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtras(intent.extras ?: android.os.Bundle())
        }
        
        context.startActivity(launchIntent)
    }

    /**
     * Handle template selection
     */
    private fun handleOpenTemplate(context: Context, intent: Intent) {
        val templateId = intent.getStringExtra(EXTRA_TEMPLATE_ID) ?: return
        Log.d(TAG, "Opening template: $templateId")
        
        val launchIntent = Intent(context, MainActivity::class.java).apply {
            action = ACTION_OPEN_TEMPLATE
            data = Uri.parse("durunotes://capture/template/$templateId")
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtras(intent.extras ?: android.os.Bundle())
        }
        
        context.startActivity(launchIntent)
    }

    /**
     * Handle refresh action
     */
    private fun handleRefresh(context: Context, intent: Intent) {
        Log.d(TAG, "Refreshing widget")
        
        val widgetId = intent.getIntExtra(EXTRA_WIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
        
        // Request data update from app via platform channel
        val updateIntent = Intent(context, MainActivity::class.java).apply {
            action = "com.fittechs.durunotes.REFRESH_WIDGET_DATA"
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(EXTRA_WIDGET_ID, widgetId)
        }
        context.startActivity(updateIntent)
        
        // Update widget immediately
        if (widgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            updateWidget(context, appWidgetManager, widgetId)
        } else {
            updateAllWidgets(context)
        }
    }

    /**
     * Handle note opening
     */
    private fun handleOpenNote(context: Context, intent: Intent) {
        val noteId = intent.getStringExtra(EXTRA_NOTE_ID) ?: return
        Log.d(TAG, "Opening note: $noteId")
        
        val launchIntent = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            data = Uri.parse("durunotes://note/$noteId")
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        
        context.startActivity(launchIntent)
    }

    /**
     * Handle view all action
     */
    private fun handleViewAll(context: Context, intent: Intent) {
        Log.d(TAG, "Opening all widget captures")
        
        val launchIntent = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            data = Uri.parse("durunotes://captures/widget")
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        
        context.startActivity(launchIntent)
    }

    /**
     * Handle settings action
     */
    private fun handleSettings(context: Context, intent: Intent) {
        Log.d(TAG, "Opening widget settings")
        
        val widgetId = intent.getIntExtra(EXTRA_WIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
        
        val launchIntent = Intent(context, QuickCaptureConfigActivity::class.java).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_CONFIGURE
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        
        context.startActivity(launchIntent)
    }

    /**
     * Handle data update from app
     */
    private fun handleUpdateFromApp(context: Context, intent: Intent) {
        Log.d(TAG, "Updating widget data from app")
        
        // Extract and save data from intent
        intent.extras?.let { extras ->
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().apply {
                extras.getString("auth_token")?.let { putString(PREF_AUTH_TOKEN, it) }
                extras.getString("user_id")?.let { putString(PREF_USER_ID, it) }
                extras.getString("recent_captures")?.let { putString(PREF_RECENT_CAPTURES, it) }
                extras.getString("templates")?.let { putString(PREF_TEMPLATES, it) }
                putLong(PREF_LAST_SYNC, System.currentTimeMillis())
                apply()
            }
        }
        
        // Update all widgets
        updateAllWidgets(context)
    }

    /**
     * Initialize widget data
     */
    private fun initializeWidgetData(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        
        // Initialize with default templates if not present
        if (!prefs.contains(PREF_TEMPLATES)) {
            val defaultTemplates = JSONArray().apply {
                put(JSONObject().apply {
                    put("id", "meeting")
                    put("name", "Meeting Notes")
                    put("icon", "ic_meeting")
                })
                put(JSONObject().apply {
                    put("id", "idea")
                    put("name", "Quick Idea")
                    put("icon", "ic_lightbulb")
                })
                put(JSONObject().apply {
                    put("id", "task")
                    put("name", "New Task")
                    put("icon", "ic_task")
                })
            }
            
            prefs.edit().putString(PREF_TEMPLATES, defaultTemplates.toString()).apply()
        }
    }

    /**
     * Clean up widget data
     */
    private fun cleanupWidgetData(context: Context, keepOfflineQueue: Boolean) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        
        if (keepOfflineQueue) {
            // Keep offline queue but clear other data
            val offlineQueue = prefs.getString(PREF_OFFLINE_QUEUE, null)
            prefs.edit().clear().apply()
            offlineQueue?.let {
                prefs.edit().putString(PREF_OFFLINE_QUEUE, it).apply()
            }
        } else {
            // Clear all data
            prefs.edit().clear().apply()
        }
    }

    /**
     * Get recent captures from SharedPreferences
     */
    private fun getRecentCaptures(context: Context): List<CaptureItem> {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val capturesJson = prefs.getString(PREF_RECENT_CAPTURES, null) ?: return emptyList()
        
        return try {
            val captures = mutableListOf<CaptureItem>()
            val jsonArray = JSONArray(capturesJson)
            
            for (i in 0 until jsonArray.length()) {
                val obj = jsonArray.getJSONObject(i)
                captures.add(
                    CaptureItem(
                        id = obj.getString("id"),
                        title = obj.getString("title"),
                        snippet = obj.optString("snippet", ""),
                        timestamp = obj.getLong("timestamp"),
                        isPinned = obj.optBoolean("is_pinned", false)
                    )
                )
            }
            
            captures
        } catch (e: Exception) {
            Log.e(TAG, "Error parsing recent captures", e)
            emptyList()
        }
    }

    /**
     * Get offline queue
     */
    private fun getOfflineQueue(context: Context): List<PendingCapture> {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val queueJson = prefs.getString(PREF_OFFLINE_QUEUE, null) ?: return emptyList()
        
        return try {
            val queue = mutableListOf<PendingCapture>()
            val jsonArray = JSONArray(queueJson)
            
            for (i in 0 until jsonArray.length()) {
                val obj = jsonArray.getJSONObject(i)
                queue.add(
                    PendingCapture(
                        id = obj.getString("id"),
                        content = obj.getString("content"),
                        type = obj.getString("type"),
                        timestamp = obj.getLong("timestamp"),
                        templateId = obj.optString("template_id", null)
                    )
                )
            }
            
            queue
        } catch (e: Exception) {
            Log.e(TAG, "Error parsing offline queue", e)
            emptyList()
        }
    }

    /**
     * Create capture intent
     */
    private fun createCaptureIntent(
        context: Context,
        action: String,
        widgetId: Int
    ): PendingIntent {
        val intent = Intent(context, QuickCaptureWidgetProvider::class.java).apply {
            this.action = action
            putExtra(EXTRA_WIDGET_ID, widgetId)
        }
        
        return PendingIntent.getBroadcast(
            context,
            widgetId + action.hashCode(),
            intent,
            getPendingIntentFlags()
        )
    }

    /**
     * Create template intent
     */
    private fun createTemplateIntent(
        context: Context,
        templateId: String,
        widgetId: Int
    ): PendingIntent {
        val intent = Intent(context, QuickCaptureWidgetProvider::class.java).apply {
            action = ACTION_OPEN_TEMPLATE
            putExtra(EXTRA_TEMPLATE_ID, templateId)
            putExtra(EXTRA_WIDGET_ID, widgetId)
        }
        
        return PendingIntent.getBroadcast(
            context,
            widgetId + templateId.hashCode(),
            intent,
            getPendingIntentFlags()
        )
    }

    /**
     * Create action intent
     */
    private fun createActionIntent(
        context: Context,
        action: String,
        widgetId: Int
    ): PendingIntent {
        val intent = Intent(context, QuickCaptureWidgetProvider::class.java).apply {
            this.action = action
            putExtra(EXTRA_WIDGET_ID, widgetId)
        }
        
        return PendingIntent.getBroadcast(
            context,
            widgetId + action.hashCode(),
            intent,
            getPendingIntentFlags()
        )
    }

    /**
     * Get appropriate PendingIntent flags based on API level
     */
    private fun getPendingIntentFlags(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
    }

    /**
     * Widget size enum
     */
    enum class WidgetSize {
        SMALL, MEDIUM, LARGE
    }

    /**
     * Data class for capture items
     */
    data class CaptureItem(
        val id: String,
        val title: String,
        val snippet: String,
        val timestamp: Long,
        val isPinned: Boolean
    )

    /**
     * Data class for pending captures
     */
    data class PendingCapture(
        val id: String,
        val content: String,
        val type: String,
        val timestamp: Long,
        val templateId: String?
    )
}
