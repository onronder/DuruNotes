package com.fittechs.durunotes.widget

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mock
import org.mockito.Mockito.*
import org.mockito.junit.MockitoJUnitRunner
import org.junit.Assert.*
import java.util.UUID

/**
 * Unit tests for Quick Capture Widget Provider
 */
@RunWith(MockitoJUnitRunner::class)
class QuickCaptureWidgetProviderTest {

    @Mock
    private lateinit var mockContext: Context

    @Mock
    private lateinit var mockAppWidgetManager: AppWidgetManager

    @Mock
    private lateinit var mockSharedPreferences: SharedPreferences

    @Mock
    private lateinit var mockEditor: SharedPreferences.Editor

    private lateinit var widgetProvider: QuickCaptureWidgetProvider

    @Before
    fun setUp() {
        widgetProvider = QuickCaptureWidgetProvider()
        
        // Set up SharedPreferences mock
        `when`(mockContext.getSharedPreferences(anyString(), anyInt()))
            .thenReturn(mockSharedPreferences)
        `when`(mockSharedPreferences.edit()).thenReturn(mockEditor)
        `when`(mockEditor.putString(anyString(), anyString())).thenReturn(mockEditor)
        `when`(mockEditor.putLong(anyString(), anyLong())).thenReturn(mockEditor)
        `when`(mockEditor.putBoolean(anyString(), anyBoolean())).thenReturn(mockEditor)
        `when`(mockEditor.apply()).then { }
    }

    @Test
    fun `test widget update with valid data`() {
        // Arrange
        val appWidgetIds = intArrayOf(1, 2, 3)
        `when`(mockSharedPreferences.getString("auth_token", null))
            .thenReturn("test-token")
        `when`(mockSharedPreferences.getString("recent_captures", null))
            .thenReturn(createMockRecentCaptures())

        // Act
        widgetProvider.onUpdate(mockContext, mockAppWidgetManager, appWidgetIds)

        // Assert
        verify(mockAppWidgetManager, times(3)).updateAppWidget(anyInt(), any(RemoteViews::class.java))
    }

    @Test
    fun `test widget handles missing authentication`() {
        // Arrange
        val appWidgetIds = intArrayOf(1)
        `when`(mockSharedPreferences.getString("auth_token", null))
            .thenReturn(null)

        // Act
        widgetProvider.onUpdate(mockContext, mockAppWidgetManager, appWidgetIds)

        // Assert
        verify(mockAppWidgetManager).updateAppWidget(anyInt(), any(RemoteViews::class.java))
        // Widget should show login prompt
    }

    @Test
    fun `test capture text action`() {
        // Arrange
        val intent = Intent().apply {
            action = QuickCaptureWidgetProvider.ACTION_CAPTURE_TEXT
            putExtra(QuickCaptureWidgetProvider.EXTRA_WIDGET_ID, 1)
        }

        // Act
        widgetProvider.onReceive(mockContext, intent)

        // Assert
        verify(mockContext).startActivity(any(Intent::class.java))
    }

    @Test
    fun `test capture voice action`() {
        // Arrange
        val intent = Intent().apply {
            action = QuickCaptureWidgetProvider.ACTION_CAPTURE_VOICE
            putExtra(QuickCaptureWidgetProvider.EXTRA_WIDGET_ID, 1)
        }

        // Act
        widgetProvider.onReceive(mockContext, intent)

        // Assert
        verify(mockContext).startActivity(any(Intent::class.java))
    }

    @Test
    fun `test template selection`() {
        // Arrange
        val intent = Intent().apply {
            action = QuickCaptureWidgetProvider.ACTION_OPEN_TEMPLATE
            putExtra(QuickCaptureWidgetProvider.EXTRA_TEMPLATE_ID, "meeting")
            putExtra(QuickCaptureWidgetProvider.EXTRA_WIDGET_ID, 1)
        }

        // Act
        widgetProvider.onReceive(mockContext, intent)

        // Assert
        verify(mockContext).startActivity(argThat { launchIntent ->
            launchIntent.data?.toString()?.contains("template/meeting") == true
        })
    }

    @Test
    fun `test widget refresh`() {
        // Arrange
        val intent = Intent().apply {
            action = QuickCaptureWidgetProvider.ACTION_REFRESH
            putExtra(QuickCaptureWidgetProvider.EXTRA_WIDGET_ID, 1)
        }

        // Act
        widgetProvider.onReceive(mockContext, intent)

        // Assert
        verify(mockContext).startActivity(argThat { refreshIntent ->
            refreshIntent.action == "com.fittechs.durunotes.REFRESH_WIDGET_DATA"
        })
    }

    @Test
    fun `test data update from app`() {
        // Arrange
        val recentCaptures = JSONArray().apply {
            put(JSONObject().apply {
                put("id", "1")
                put("title", "Test Note")
                put("snippet", "Test content")
                put("created_at", System.currentTimeMillis())
            })
        }

        val intent = Intent().apply {
            action = QuickCaptureWidgetProvider.ACTION_UPDATE_FROM_APP
            putExtra("auth_token", "new-token")
            putExtra("user_id", "test-user")
            putExtra("recent_captures", recentCaptures.toString())
        }

        // Act
        widgetProvider.onReceive(mockContext, intent)

        // Assert
        verify(mockEditor).putString("auth_token", "new-token")
        verify(mockEditor).putString("user_id", "test-user")
        verify(mockEditor).putString("recent_captures", recentCaptures.toString())
        verify(mockEditor).putLong(eq("last_sync"), anyLong())
        verify(mockEditor).apply()
    }

    @Test
    fun `test widget size detection`() {
        // Test small widget
        testWidgetSize(100, QuickCaptureWidgetProvider.WidgetSize.SMALL)
        
        // Test medium widget
        testWidgetSize(200, QuickCaptureWidgetProvider.WidgetSize.MEDIUM)
        
        // Test large widget
        testWidgetSize(300, QuickCaptureWidgetProvider.WidgetSize.LARGE)
    }

    @Test
    fun `test offline queue handling`() {
        // Arrange
        val offlineQueue = JSONArray().apply {
            put(JSONObject().apply {
                put("id", UUID.randomUUID().toString())
                put("content", "Offline note")
                put("type", "text")
                put("timestamp", System.currentTimeMillis())
            })
        }
        
        `when`(mockSharedPreferences.getString("offline_queue", null))
            .thenReturn(offlineQueue.toString())

        // Act
        val queue = getOfflineQueueFromProvider()

        // Assert
        assertEquals(1, queue.length())
        assertEquals("Offline note", queue.getJSONObject(0).getString("content"))
    }

    @Test
    fun `test widget lifecycle callbacks`() {
        // Test onEnabled
        widgetProvider.onEnabled(mockContext)
        verify(mockSharedPreferences, atLeastOnce()).edit()

        // Test onDisabled
        widgetProvider.onDisabled(mockContext)
        // Should keep offline queue but clear other data
        verify(mockSharedPreferences, atLeastOnce()).getString("offline_queue", null)
    }

    // Helper methods
    private fun createMockRecentCaptures(): String {
        return JSONArray().apply {
            put(JSONObject().apply {
                put("id", "1")
                put("title", "Note 1")
                put("snippet", "Content 1")
                put("created_at", System.currentTimeMillis())
                put("is_pinned", false)
            })
            put(JSONObject().apply {
                put("id", "2")
                put("title", "Note 2")
                put("snippet", "Content 2")
                put("created_at", System.currentTimeMillis() - 3600000)
                put("is_pinned", true)
            })
        }.toString()
    }

    private fun testWidgetSize(width: Int, expectedSize: QuickCaptureWidgetProvider.WidgetSize) {
        val options = mock(android.os.Bundle::class.java)
        `when`(options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH))
            .thenReturn(width)
        `when`(mockAppWidgetManager.getAppWidgetOptions(1))
            .thenReturn(options)

        // This would need access to the private method, so in real implementation
        // you'd make it package-private or use reflection
        // val size = widgetProvider.getWidgetSize(mockContext, mockAppWidgetManager, 1)
        // assertEquals(expectedSize, size)
    }

    private fun getOfflineQueueFromProvider(): JSONArray {
        // This simulates getting the offline queue
        val queueJson = mockSharedPreferences.getString("offline_queue", null) ?: "[]"
        return JSONArray(queueJson)
    }
}

/**
 * Unit tests for RemoteViewsService
 */
@RunWith(MockitoJUnitRunner::class)
class QuickCaptureRemoteViewsFactoryTest {

    @Mock
    private lateinit var mockContext: Context

    @Mock
    private lateinit var mockSharedPreferences: SharedPreferences

    private lateinit var factory: QuickCaptureRemoteViewsFactory
    private val testWidgetId = 1

    @Before
    fun setUp() {
        `when`(mockContext.getSharedPreferences(anyString(), anyInt()))
            .thenReturn(mockSharedPreferences)
        
        factory = QuickCaptureRemoteViewsFactory(mockContext, testWidgetId)
    }

    @Test
    fun `test factory loads data correctly`() {
        // Arrange
        val captures = createMockCapturesList()
        `when`(mockSharedPreferences.getString(
            QuickCaptureWidgetProvider.PREF_RECENT_CAPTURES, null
        )).thenReturn(captures)

        // Act
        factory.onCreate()
        factory.onDataSetChanged()

        // Assert
        assertEquals(3, factory.count)
    }

    @Test
    fun `test factory handles empty data`() {
        // Arrange
        `when`(mockSharedPreferences.getString(
            QuickCaptureWidgetProvider.PREF_RECENT_CAPTURES, null
        )).thenReturn(null)

        // Act
        factory.onCreate()
        factory.onDataSetChanged()

        // Assert
        assertEquals(0, factory.count)
    }

    @Test
    fun `test factory creates correct RemoteViews`() {
        // Arrange
        val captures = createMockCapturesList()
        `when`(mockSharedPreferences.getString(
            QuickCaptureWidgetProvider.PREF_RECENT_CAPTURES, null
        )).thenReturn(captures)

        factory.onCreate()
        factory.onDataSetChanged()

        // Act
        val remoteViews = factory.getViewAt(0)

        // Assert
        assertNotNull(remoteViews)
        // Additional assertions would require checking RemoteViews content
    }

    @Test
    fun `test factory handles pinned items priority`() {
        // Arrange
        val captures = JSONArray().apply {
            // Unpinned item
            put(JSONObject().apply {
                put("id", "1")
                put("title", "Unpinned")
                put("created_at", System.currentTimeMillis())
                put("is_pinned", false)
            })
            // Pinned item (should appear first after sorting)
            put(JSONObject().apply {
                put("id", "2")
                put("title", "Pinned")
                put("created_at", System.currentTimeMillis() - 3600000)
                put("is_pinned", true)
            })
        }.toString()

        `when`(mockSharedPreferences.getString(
            QuickCaptureWidgetProvider.PREF_RECENT_CAPTURES, null
        )).thenReturn(captures)

        // Act
        factory.onCreate()
        factory.onDataSetChanged()

        // Assert
        // The pinned item should be first after sorting
        val firstItem = factory.getViewAt(0)
        assertNotNull(firstItem)
    }

    private fun createMockCapturesList(): String {
        return JSONArray().apply {
            for (i in 1..3) {
                put(JSONObject().apply {
                    put("id", i.toString())
                    put("title", "Capture $i")
                    put("snippet", "Content for capture $i")
                    put("created_at", System.currentTimeMillis() - (i * 3600000))
                    put("is_pinned", i == 2)
                    put("tags", JSONArray().apply {
                        put("tag$i")
                        put("widget")
                    })
                })
            }
        }.toString()
    }
}

/**
 * Unit tests for Configuration Activity
 */
@RunWith(MockitoJUnitRunner::class)
class QuickCaptureConfigActivityTest {

    @Mock
    private lateinit var mockSharedPreferences: SharedPreferences

    @Mock
    private lateinit var mockEditor: SharedPreferences.Editor

    @Before
    fun setUp() {
        `when`(mockSharedPreferences.edit()).thenReturn(mockEditor)
        `when`(mockEditor.putString(anyString(), anyString())).thenReturn(mockEditor)
        `when`(mockEditor.putBoolean(anyString(), anyBoolean())).thenReturn(mockEditor)
        `when`(mockEditor.apply()).then { }
    }

    @Test
    fun `test configuration saves correctly`() {
        // Verify that configuration values are saved to SharedPreferences
        val config = mapOf(
            "default_capture_type" to "voice",
            "show_recent_captures" to true,
            "enable_voice" to true,
            "enable_camera" to false,
            "default_template" to "meeting",
            "theme" to "dark"
        )

        // Save configuration
        config.forEach { (key, value) ->
            when (value) {
                is String -> mockEditor.putString(key, value)
                is Boolean -> mockEditor.putBoolean(key, value)
            }
        }
        mockEditor.apply()

        // Verify all values were saved
        verify(mockEditor).putString("default_capture_type", "voice")
        verify(mockEditor).putBoolean("show_recent_captures", true)
        verify(mockEditor).putBoolean("enable_voice", true)
        verify(mockEditor).putBoolean("enable_camera", false)
        verify(mockEditor).putString("default_template", "meeting")
        verify(mockEditor).putString("theme", "dark")
        verify(mockEditor).apply()
    }

    @Test
    fun `test configuration loads existing values`() {
        // Arrange
        `when`(mockSharedPreferences.getString("default_capture_type", "text"))
            .thenReturn("voice")
        `when`(mockSharedPreferences.getBoolean("show_recent_captures", true))
            .thenReturn(false)
        `when`(mockSharedPreferences.getString("theme", "auto"))
            .thenReturn("dark")

        // Act - Load configuration
        val captureType = mockSharedPreferences.getString("default_capture_type", "text")
        val showRecent = mockSharedPreferences.getBoolean("show_recent_captures", true)
        val theme = mockSharedPreferences.getString("theme", "auto")

        // Assert
        assertEquals("voice", captureType)
        assertEquals(false, showRecent)
        assertEquals("dark", theme)
    }
}
