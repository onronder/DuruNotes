package com.fittechs.durunotes.widget

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import android.util.Log
import android.widget.Button
import android.widget.CheckBox
import android.widget.RadioGroup
import android.widget.TextView
import android.widget.Toast
import com.fittechs.duruNotesApp.R
import org.json.JSONObject

/**
 * Configuration activity for Quick Capture Widget
 * Allows users to customize widget behavior and appearance
 */
class QuickCaptureConfigActivity : Activity() {

    companion object {
        private const val TAG = "QuickCaptureConfig"
        private const val PREFS_NAME = "QuickCaptureWidgetConfig"
        private const val PREF_DEFAULT_CAPTURE_TYPE = "default_capture_type"
        private const val PREF_SHOW_RECENT_CAPTURES = "show_recent_captures"
        private const val PREF_ENABLE_VOICE = "enable_voice"
        private const val PREF_ENABLE_CAMERA = "enable_camera"
        private const val PREF_DEFAULT_TEMPLATE = "default_template"
        private const val PREF_THEME = "theme"
    }

    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Set default result to cancelled
        setResult(RESULT_CANCELED)

        // Get widget ID from intent
        appWidgetId = intent?.extras?.getInt(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID

        // If no valid widget ID, finish
        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            Log.e(TAG, "Invalid widget ID")
            finish()
            return
        }

        // Set up the configuration UI
        setContentView(R.layout.activity_widget_config)
        setupUI()
        loadExistingConfig()
    }

    /**
     * Set up the configuration UI
     */
    private fun setupUI() {
        // Title
        findViewById<TextView>(R.id.config_title)?.text = 
            getString(R.string.widget_config_title)

        // Default capture type
        findViewById<RadioGroup>(R.id.capture_type_group)?.setOnCheckedChangeListener { _, checkedId ->
            when (checkedId) {
                R.id.radio_text -> Log.d(TAG, "Selected text capture")
                R.id.radio_voice -> Log.d(TAG, "Selected voice capture")
                R.id.radio_camera -> Log.d(TAG, "Selected camera capture")
            }
        }

        // Features checkboxes
        findViewById<CheckBox>(R.id.checkbox_show_recent)?.setOnCheckedChangeListener { _, isChecked ->
            Log.d(TAG, "Show recent captures: $isChecked")
        }

        findViewById<CheckBox>(R.id.checkbox_enable_voice)?.setOnCheckedChangeListener { _, isChecked ->
            Log.d(TAG, "Enable voice capture: $isChecked")
        }

        findViewById<CheckBox>(R.id.checkbox_enable_camera)?.setOnCheckedChangeListener { _, isChecked ->
            Log.d(TAG, "Enable camera capture: $isChecked")
        }

        // Default template
        findViewById<RadioGroup>(R.id.template_group)?.setOnCheckedChangeListener { _, checkedId ->
            when (checkedId) {
                R.id.radio_no_template -> Log.d(TAG, "No default template")
                R.id.radio_meeting -> Log.d(TAG, "Meeting template")
                R.id.radio_idea -> Log.d(TAG, "Idea template")
                R.id.radio_task -> Log.d(TAG, "Task template")
            }
        }

        // Theme selection
        findViewById<RadioGroup>(R.id.theme_group)?.setOnCheckedChangeListener { _, checkedId ->
            when (checkedId) {
                R.id.radio_theme_auto -> Log.d(TAG, "Auto theme")
                R.id.radio_theme_light -> Log.d(TAG, "Light theme")
                R.id.radio_theme_dark -> Log.d(TAG, "Dark theme")
            }
        }

        // Save button
        findViewById<Button>(R.id.button_save)?.setOnClickListener {
            saveConfiguration()
        }

        // Cancel button
        findViewById<Button>(R.id.button_cancel)?.setOnClickListener {
            finish()
        }
    }

    /**
     * Load existing configuration if available
     */
    private fun loadExistingConfig() {
        val prefs = getSharedPreferences("$PREFS_NAME$appWidgetId", MODE_PRIVATE)

        // Default capture type
        val captureType = prefs.getString(PREF_DEFAULT_CAPTURE_TYPE, "text")
        findViewById<RadioGroup>(R.id.capture_type_group)?.check(
            when (captureType) {
                "voice" -> R.id.radio_voice
                "camera" -> R.id.radio_camera
                else -> R.id.radio_text
            }
        )

        // Features
        findViewById<CheckBox>(R.id.checkbox_show_recent)?.isChecked =
            prefs.getBoolean(PREF_SHOW_RECENT_CAPTURES, true)
        findViewById<CheckBox>(R.id.checkbox_enable_voice)?.isChecked =
            prefs.getBoolean(PREF_ENABLE_VOICE, true)
        findViewById<CheckBox>(R.id.checkbox_enable_camera)?.isChecked =
            prefs.getBoolean(PREF_ENABLE_CAMERA, true)

        // Default template
        val template = prefs.getString(PREF_DEFAULT_TEMPLATE, "none")
        findViewById<RadioGroup>(R.id.template_group)?.check(
            when (template) {
                "meeting" -> R.id.radio_meeting
                "idea" -> R.id.radio_idea
                "task" -> R.id.radio_task
                else -> R.id.radio_no_template
            }
        )

        // Theme
        val theme = prefs.getString(PREF_THEME, "auto")
        findViewById<RadioGroup>(R.id.theme_group)?.check(
            when (theme) {
                "light" -> R.id.radio_theme_light
                "dark" -> R.id.radio_theme_dark
                else -> R.id.radio_theme_auto
            }
        )
    }

    /**
     * Save configuration and update widget
     */
    private fun saveConfiguration() {
        val prefs = getSharedPreferences("$PREFS_NAME$appWidgetId", MODE_PRIVATE)
        val editor = prefs.edit()

        // Save capture type
        val captureTypeId = findViewById<RadioGroup>(R.id.capture_type_group)?.checkedRadioButtonId
        val captureType = when (captureTypeId) {
            R.id.radio_voice -> "voice"
            R.id.radio_camera -> "camera"
            else -> "text"
        }
        editor.putString(PREF_DEFAULT_CAPTURE_TYPE, captureType)

        // Save features
        editor.putBoolean(
            PREF_SHOW_RECENT_CAPTURES,
            findViewById<CheckBox>(R.id.checkbox_show_recent)?.isChecked ?: true
        )
        editor.putBoolean(
            PREF_ENABLE_VOICE,
            findViewById<CheckBox>(R.id.checkbox_enable_voice)?.isChecked ?: true
        )
        editor.putBoolean(
            PREF_ENABLE_CAMERA,
            findViewById<CheckBox>(R.id.checkbox_enable_camera)?.isChecked ?: true
        )

        // Save template
        val templateId = findViewById<RadioGroup>(R.id.template_group)?.checkedRadioButtonId
        val template = when (templateId) {
            R.id.radio_meeting -> "meeting"
            R.id.radio_idea -> "idea"
            R.id.radio_task -> "task"
            else -> "none"
        }
        editor.putString(PREF_DEFAULT_TEMPLATE, template)

        // Save theme
        val themeId = findViewById<RadioGroup>(R.id.theme_group)?.checkedRadioButtonId
        val theme = when (themeId) {
            R.id.radio_theme_light -> "light"
            R.id.radio_theme_dark -> "dark"
            else -> "auto"
        }
        editor.putString(PREF_THEME, theme)

        // Apply changes
        editor.apply()

        // Update widget
        updateWidget()

        // Show success message
        Toast.makeText(this, R.string.widget_config_saved, Toast.LENGTH_SHORT).show()

        // Return result
        val resultValue = Intent().apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
        }
        setResult(RESULT_OK, resultValue)
        finish()
    }

    /**
     * Update the widget with new configuration
     */
    private fun updateWidget() {
        val appWidgetManager = AppWidgetManager.getInstance(this)
        
        // Create intent to update widget
        val updateIntent = Intent(this, QuickCaptureWidgetProvider::class.java).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, intArrayOf(appWidgetId))
        }
        
        sendBroadcast(updateIntent)
        
        Log.d(TAG, "Widget $appWidgetId updated with new configuration")
    }
}
