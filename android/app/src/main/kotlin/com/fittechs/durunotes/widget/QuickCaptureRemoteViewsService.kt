package com.fittechs.durunotes.widget

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import com.fittechs.durunotes.R
import org.json.JSONArray
import org.json.JSONObject
import android.util.Log
import java.text.SimpleDateFormat
import java.util.*

/**
 * RemoteViewsService for providing list data to the widget
 * Handles recent captures list in large widget layout
 */
class QuickCaptureRemoteViewsService : RemoteViewsService() {

    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        val appWidgetId = intent.getIntExtra(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID
        )
        return QuickCaptureRemoteViewsFactory(applicationContext, appWidgetId)
    }
}

/**
 * Factory for creating RemoteViews for list items
 */
class QuickCaptureRemoteViewsFactory(
    private val context: Context,
    private val appWidgetId: Int
) : RemoteViewsService.RemoteViewsFactory {

    companion object {
        private const val TAG = "QuickCaptureListFactory"
        private const val MAX_ITEMS = 5
    }

    private var captures = mutableListOf<CaptureListItem>()
    private val dateFormatter = SimpleDateFormat("MMM d", Locale.getDefault())
    private val timeFormatter = SimpleDateFormat("h:mm a", Locale.getDefault())

    override fun onCreate() {
        Log.d(TAG, "onCreate for widget $appWidgetId")
        loadData()
    }

    override fun onDataSetChanged() {
        Log.d(TAG, "onDataSetChanged for widget $appWidgetId")
        loadData()
    }

    override fun onDestroy() {
        Log.d(TAG, "onDestroy for widget $appWidgetId")
        captures.clear()
    }

    override fun getCount(): Int = captures.size

    override fun getViewAt(position: Int): RemoteViews? {
        if (position < 0 || position >= captures.size) {
            return null
        }

        val capture = captures[position]
        val views = RemoteViews(context.packageName, R.layout.widget_list_item_capture)

        // Set capture data
        views.setTextViewText(R.id.capture_title, capture.title)
        views.setTextViewText(R.id.capture_snippet, capture.snippet)
        
        // Format timestamp
        val date = Date(capture.timestamp)
        val isToday = isToday(date)
        val timeText = if (isToday) {
            "Today, ${timeFormatter.format(date)}"
        } else {
            "${dateFormatter.format(date)}, ${timeFormatter.format(date)}"
        }
        views.setTextViewText(R.id.capture_time, timeText)

        // Show pin indicator if pinned
        views.setViewVisibility(
            R.id.pin_indicator,
            if (capture.isPinned) RemoteViews.VISIBLE else RemoteViews.GONE
        )

        // Set tag chips
        if (capture.tags.isNotEmpty()) {
            views.setTextViewText(R.id.capture_tags, capture.tags.joinToString(" • "))
            views.setViewVisibility(R.id.capture_tags, RemoteViews.VISIBLE)
        } else {
            views.setViewVisibility(R.id.capture_tags, RemoteViews.GONE)
        }

        // Set click fill-in intent
        val fillInIntent = Intent().apply {
            val extras = Bundle()
            extras.putString(QuickCaptureWidgetProvider.EXTRA_NOTE_ID, capture.id)
            putExtras(extras)
        }
        views.setOnClickFillInIntent(R.id.list_item_container, fillInIntent)

        return views
    }

    override fun getLoadingView(): RemoteViews? {
        // Return a simple loading view
        return RemoteViews(context.packageName, R.layout.widget_list_item_loading)
    }

    override fun getViewTypeCount(): Int = 2 // Normal item and loading view

    override fun getItemId(position: Int): Long {
        return if (position < captures.size) {
            captures[position].id.hashCode().toLong()
        } else {
            position.toLong()
        }
    }

    override fun hasStableIds(): Boolean = true

    /**
     * Load capture data from SharedPreferences
     */
    private fun loadData() {
        captures.clear()

        val prefs = context.getSharedPreferences(
            QuickCaptureWidgetProvider.PREFS_NAME,
            Context.MODE_PRIVATE
        )

        val capturesJson = prefs.getString(
            QuickCaptureWidgetProvider.PREF_RECENT_CAPTURES,
            null
        ) ?: return

        try {
            val jsonArray = JSONArray(capturesJson)
            val itemCount = minOf(jsonArray.length(), MAX_ITEMS)

            for (i in 0 until itemCount) {
                val obj = jsonArray.getJSONObject(i)
                
                // Parse tags
                val tags = mutableListOf<String>()
                if (obj.has("tags")) {
                    val tagsArray = obj.getJSONArray("tags")
                    for (j in 0 until tagsArray.length()) {
                        tags.add(tagsArray.getString(j))
                    }
                }

                captures.add(
                    CaptureListItem(
                        id = obj.getString("id"),
                        title = obj.getString("title"),
                        snippet = obj.optString("snippet", ""),
                        timestamp = obj.getLong("created_at"),
                        isPinned = obj.optBoolean("is_pinned", false),
                        tags = tags
                    )
                )
            }

            // Sort by pinned first, then by timestamp
            captures.sortWith(compareBy(
                { !it.isPinned }, // Pinned items first
                { -it.timestamp }  // Then by timestamp descending
            ))

            Log.d(TAG, "Loaded ${captures.size} captures for widget $appWidgetId")

        } catch (e: Exception) {
            Log.e(TAG, "Error loading captures data", e)
        }
    }

    /**
     * Check if a date is today
     */
    private fun isToday(date: Date): Boolean {
        val today = Calendar.getInstance()
        val cal = Calendar.getInstance().apply { time = date }
        
        return today.get(Calendar.YEAR) == cal.get(Calendar.YEAR) &&
               today.get(Calendar.DAY_OF_YEAR) == cal.get(Calendar.DAY_OF_YEAR)
    }

    /**
     * Data class for list items
     */
    data class CaptureListItem(
        val id: String,
        val title: String,
        val snippet: String,
        val timestamp: Long,
        val isPinned: Boolean,
        val tags: List<String>
    )
}
