package com.example.cooldemo

import android.app.Application

class MyApplication : Application() {

    override fun onCreate() {
        super.onCreate()
        FlutterHybrid.init(this)
    }
}
