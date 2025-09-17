package com.fittechs.duruNotesApp

import androidx.multidex.MultiDexApplication

class MainApplication : MultiDexApplication() {
    
    override fun onCreate() {
        super.onCreate()
        
        // Clear old cache to prevent buildup
        clearOldCache()
    }
    
    private fun clearOldCache() {
        try {
            val cacheDir = cacheDir
            val sentryCache = java.io.File(cacheDir, "sentry")
            if (sentryCache.exists() && sentryCache.isDirectory) {
                sentryCache.listFiles()?.forEach { file ->
                    if (System.currentTimeMillis() - file.lastModified() > 24 * 60 * 60 * 1000) {
                        file.deleteRecursively()
                    }
                }
            }
        } catch (e: Exception) {
            // Ignore cache cleanup errors
        }
    }
}
