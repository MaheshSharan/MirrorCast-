package com.mirrorcast.android

import android.app.Application
import timber.log.Timber

/**
 * Main Application class for MirrorCast Android app.
 * Initializes global dependencies and configurations.
 */
class MirrorCastApplication : Application() {

    override fun onCreate() {
        super.onCreate()
        
        // Initialize Timber for logging
        if (BuildConfig.DEBUG) {
            Timber.plant(Timber.DebugTree())
        }
        
        Timber.i("MirrorCast Application started")
    }
}
