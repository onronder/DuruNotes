package com.fittechs.durunotes.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import com.fittechs.duruNotesApp.MainActivity
import com.fittechs.duruNotesApp.R
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
        
        // SharedPreferences keys for widget configuration
        const val PREFS_NAME = "QuickCaptureWidget"
        const val PREF_TEMPLATES = "templates"
        
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
            setAction(ACTION_CAPTURE_TEXT)
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
            setData(Uri.parse(toUri(Intent.URI_INTENT_SCHEME)))
        }
        views.setRemoteAdapter(R.id.recent_captures_list, serviceIntent)
        
        // Set pending intent template for list items
        val noteIntent = Intent(context, QuickCaptureWidgetProvider::class.java).apply {
            setAction(ACTION_OPEN_NOTE)
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
        val storage = QuickCaptureWidgetStorage.getInstance(context)
        val captures = storage.getRecentCaptures()
        val isAuthenticated = !storage.getUserId().isNullOrEmpty()

        if (!isAuthenticated) {
            val titleView = when (size) {
                WidgetSize.SMALL -> R.id.widget_title
                WidgetSize.MEDIUM -> R.id.widget_title
                WidgetSize.LARGE -> R.id.widget_title
            }
            views.setTextViewText(
                titleView,
                context.getString(R.string.widget_login_required),
            )
            if (size == WidgetSize.LARGE) {
                views.setTextViewText(R.id.widget_subtitle, "")
            }
            return
        }

        if (size == WidgetSize.LARGE) {
            val updatedAt = storage.getUpdatedAtMillis()
            if (updatedAt != null) {
                val formatter = SimpleDateFormat("MMM d, h:mm a", Locale.getDefault())
                val syncText = context.getString(
                    R.string.widget_last_updated_format,
                    formatter.format(Date(updatedAt)),
                )
                views.setTextViewText(R.id.widget_subtitle, syncText)
            } else {
                views.setTextViewText(
                    R.id.widget_subtitle,
                    context.getString(R.string.widget_waiting_for_data),
                )
            }
        }

        if (size == WidgetSize.MEDIUM) {
            val hasCaptures = captures.isNotEmpty()
            views.setViewVisibility(
                R.id.no_captures_text,
                if (hasCaptures) View.GONE else View.VISIBLE,
            )
        }
    }

    /**
     * Handle text capture action
     */
    private fun handleCaptureText(context: Context, intent: Intent) {
        Log.d(TAG, "Handling text capture")
        
        val launchIntent = Intent(context, MainActivity::class.java).apply {
            setAction(ACTION_CAPTURE_TEXT)
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
            setAction(ACTION_CAPTURE_VOICE)
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
            setAction(ACTION_CAPTURE_CAMERA)
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
            setAction(ACTION_OPEN_TEMPLATE)
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
            setAction("com.fittechs.durunotes.REFRESH_WIDGET_DATA")
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
            setAction(Intent.ACTION_VIEW)
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
            setAction(Intent.ACTION_VIEW)
            setData(Uri.parse("durunotes://captures/widget"))
            setFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
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
            setAction(AppWidgetManager.ACTION_APPWIDGET_CONFIGURE)
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            setFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
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
            val payload = mutableMapOf<String, Any?>()
            extras.getString("auth_token")?.let { payload["authToken"] = it }
            extras.getString("user_id")?.let { payload["userId"] = it }
            extras.getString("recent_captures")?.let { jsonString ->
                runCatching { JSONArray(jsonString) }
                    .getOrNull()
                    ?.let { array -> payload["recentCaptures"] = array.toListOfMaps() }
            }
            extras.getString("templates")?.let { jsonString ->
                runCatching { JSONArray(jsonString) }
                    .getOrNull()
                    ?.let { array -> payload["templates"] = array.toListOfMaps() }
            }

            if (payload.isNotEmpty()) {
                QuickCaptureWidgetStorage.getInstance(context).writePayload(payload)
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
        QuickCaptureWidgetStorage.getInstance(context).clearAll(keepOfflineQueue)
        if (!keepOfflineQueue) {
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .edit()
                .clear()
                .apply()
        }
    }

    /**
     * Get recent captures from SharedPreferences
     */
    private fun getRecentCaptures(context: Context): List<CaptureItem> {
        val storage = QuickCaptureWidgetStorage.getInstance(context)
        return storage.getRecentCaptures(maxItems = 5).map { capture ->
            CaptureItem(
                id = capture.id,
                title = capture.title,
                snippet = capture.snippet,
                timestamp = capture.updatedAtMillis ?: System.currentTimeMillis(),
                isPinned = false,
            )
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
            setAction(action)
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
            setAction(ACTION_OPEN_TEMPLATE)
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
            setAction(action)
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

    private fun JSONArray.toListOfMaps(): List<Map<String, Any?>> {
        val result = mutableListOf<Map<String, Any?>>()
        for (index in 0 until length()) {
            val obj = optJSONObject(index) ?: continue
            val map = mutableMapOf<String, Any?>()
            obj.keys().forEach { key ->
                map[key] = obj.opt(key)
            }
            result.add(map)
        }
        return result
    }

}
