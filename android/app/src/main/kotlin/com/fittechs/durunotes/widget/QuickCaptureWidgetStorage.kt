package com.fittechs.durunotes.widget

import android.content.Context
import android.content.SharedPreferences
import android.os.Build
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import org.json.JSONArray
import org.json.JSONObject
import java.text.ParseException
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

class QuickCaptureWidgetStorage private constructor(context: Context) {

    private val appContext = context.applicationContext

    data class WidgetCapture(
        val id: String,
        val title: String,
        val snippet: String,
        val updatedAtIso: String?,
        val updatedAtMillis: Long?,
        val tags: List<String> = emptyList()
    )

    companion object {
        private const val PREFS_NAME = "quick_capture_widget_secure"
        private const val KEY_WIDGET_PAYLOAD = "widget_payload"
        private const val KEY_UPDATED_AT = "widget_payload_updated_at"
        private const val KEY_USER_ID = "widget_user_id"
        private const val KEY_AUTH_TOKEN = "widget_auth_token"
        private const val KEY_OFFLINE_QUEUE = "widget_offline_queue"
        private const val MAX_QUEUE_SIZE = 50

        @Volatile
        private var INSTANCE: QuickCaptureWidgetStorage? = null

        fun getInstance(context: Context): QuickCaptureWidgetStorage {
            return INSTANCE ?: synchronized(this) {
                INSTANCE ?: QuickCaptureWidgetStorage(context.applicationContext).also {
                    INSTANCE = it
                }
            }
        }
    }

    private val prefs: SharedPreferences by lazy {
        val masterKey = MasterKey.Builder(appContext)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()

        EncryptedSharedPreferences.create(
            appContext,
            PREFS_NAME,
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        )
    }

    fun writePayload(data: Map<String, Any?>) {
        val json = mapToJson(data)
        prefs.edit()
            .putString(KEY_WIDGET_PAYLOAD, json.toString())
            .putLong(KEY_UPDATED_AT, System.currentTimeMillis())
            .apply()

        data["userId"]?.let { prefs.edit().putString(KEY_USER_ID, it.toString()).apply() }
        data["authToken"]?.let { prefs.edit().putString(KEY_AUTH_TOKEN, it.toString()).apply() }
    }

    fun readPayload(): JSONObject? {
        val stored = prefs.getString(KEY_WIDGET_PAYLOAD, null) ?: return null
        return runCatching { JSONObject(stored) }.getOrNull()
    }

    fun clearAll(keepOfflineQueue: Boolean = false) {
        val queueSnapshot = prefs.getString(KEY_OFFLINE_QUEUE, null)
        prefs.edit().clear().apply()
        if (keepOfflineQueue && queueSnapshot != null) {
            prefs.edit().putString(KEY_OFFLINE_QUEUE, queueSnapshot).apply()
        }
    }

    fun getUserId(): String? = prefs.getString(KEY_USER_ID, null)

    fun getAuthToken(): String? = prefs.getString(KEY_AUTH_TOKEN, null)

    fun getUpdatedAtMillis(): Long? {
        val fromPayload = readPayload()?.optString("updatedAt", null)
        if (!fromPayload.isNullOrEmpty()) {
            parseIsoToMillis(fromPayload)?.let { return it }
        }
        val stored = prefs.getLong(KEY_UPDATED_AT, 0L)
        return if (stored == 0L) null else stored
    }

    fun getRecentCaptures(maxItems: Int = Int.MAX_VALUE): List<WidgetCapture> {
        val payload = readPayload() ?: return emptyList()
        val capturesArray = payload.optJSONArray("recentCaptures") ?: return emptyList()

        val captures = mutableListOf<WidgetCapture>()
        val count = minOf(capturesArray.length(), maxItems)
        for (index in 0 until count) {
            val obj = capturesArray.optJSONObject(index) ?: continue
            val id = obj.optString("id", "")
            if (id.isEmpty()) continue
            val title = obj.optString("title", "Quick capture")
            val snippet = obj.optString("snippet", "")
            val updatedAtIso = obj.optString("updatedAt", null)
            val tags = obj.optJSONArray("tags")?.let { array ->
                buildList(array.length()) {
                    for (i in 0 until array.length()) {
                        add(array.optString(i))
                    }
                }
            } ?: emptyList()

            captures.add(
                WidgetCapture(
                    id = id,
                    title = title,
                    snippet = snippet,
                    updatedAtIso = updatedAtIso,
                    updatedAtMillis = updatedAtIso?.let { parseIsoToMillis(it) },
                    tags = tags
                ),
            )
        }
        return captures
    }

    fun saveOfflineCapture(capture: Map<String, Any>) {
        val queue = getOfflineQueueInternal()
        if (queue.size >= MAX_QUEUE_SIZE) {
            queue.removeAt(0)
        }
        queue.add(mapToJson(capture))

        val jsonArray = JSONArray()
        queue.forEach { jsonArray.put(it) }
        prefs.edit().putString(KEY_OFFLINE_QUEUE, jsonArray.toString()).apply()
    }

    fun clearOfflineCaptures() {
        prefs.edit().remove(KEY_OFFLINE_QUEUE).apply()
    }

    fun getOfflineCaptures(): JSONArray = JSONArray(prefs.getString(KEY_OFFLINE_QUEUE, "[]"))

    private fun getOfflineQueueInternal(): MutableList<JSONObject> {
        val stored = prefs.getString(KEY_OFFLINE_QUEUE, null) ?: return mutableListOf()
        val array = runCatching { JSONArray(stored) }.getOrDefault(JSONArray())
        val list = mutableListOf<JSONObject>()
        for (i in 0 until array.length()) {
            val obj = array.optJSONObject(i)
            if (obj != null) list.add(obj)
        }
        return list
    }

    private fun mapToJson(map: Map<String, Any?>): JSONObject {
        val json = JSONObject()
        map.forEach { (key, value) ->
            json.put(key, value.toJsonValue())
        }
        return json
    }

    private fun Any?.toJsonValue(): Any? {
        return when (this) {
            null -> JSONObject.NULL
            is Map<*, *> -> {
                val map = mutableMapOf<String, Any?>()
                forEach { (key, value) ->
                    if (key != null) {
                        map[key.toString()] = value
                    }
                }
                mapToJson(map)
            }
            is List<*> -> {
                val array = JSONArray()
                this.forEach { array.put(it.toJsonValue()) }
                array
            }
            is Array<*> -> {
                val array = JSONArray()
                this.forEach { array.put(it.toJsonValue()) }
                array
            }
            is Boolean, is Int, is Long, is Double, is Float, is String -> this
            else -> this.toString()
        }
    }

    private fun parseIsoToMillis(value: String): Long? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            runCatching {
                java.time.Instant.parse(value).toEpochMilli()
            }.getOrNull()
        } else {
            // Fallback for older API levels
            val patterns = listOf(
                "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
                "yyyy-MM-dd'T'HH:mm:ss'Z'",
                "yyyy-MM-dd'T'HH:mm:ss.SSSXXX",
                "yyyy-MM-dd'T'HH:mm:ssXXX",
            )
            for (pattern in patterns) {
                val format = SimpleDateFormat(pattern, Locale.US).apply {
                    timeZone = TimeZone.getTimeZone("UTC")
                }
                try {
                    val date: Date = format.parse(value) ?: continue
                    return date.time
                } catch (_: ParseException) {
                    // Try next pattern
                }
            }
            null
        }
    }
}
