package com.example.cooldemo

import android.app.Application

class MyApplication : Application() {

    override fun onCreate() {
        super.onCreate()
        FlutterEngineManager.init(this)
        FlutterEngineManager.prepareDefaultEngine(this)
    }
}
