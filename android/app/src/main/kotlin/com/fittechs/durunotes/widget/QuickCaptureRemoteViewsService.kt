package com.fittechs.durunotes.widget

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import com.fittechs.duruNotesApp.R
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
            if (capture.isPinned) View.VISIBLE else View.GONE
        )

        // Set tag chips
        if (capture.tags.isNotEmpty()) {
            views.setTextViewText(R.id.capture_tags, capture.tags.joinToString(" • "))
            views.setViewVisibility(R.id.capture_tags, View.VISIBLE)
        } else {
            views.setViewVisibility(R.id.capture_tags, View.GONE)
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
        val storage = QuickCaptureWidgetStorage.getInstance(context)
        val items = storage.getRecentCaptures(maxItems = MAX_ITEMS)

        items.forEach { capture ->
            captures.add(
                CaptureListItem(
                    id = capture.id,
                    title = capture.title,
                    snippet = capture.snippet,
                    timestamp = capture.updatedAtMillis ?: System.currentTimeMillis(),
                    isPinned = false,
                    tags = capture.tags,
                ),
            )
        }

        captures.sortWith(
            compareBy(
                { !it.isPinned },
                { -it.timestamp },
            ),
        )

        Log.d(TAG, "Loaded ${captures.size} captures for widget $appWidgetId")
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
