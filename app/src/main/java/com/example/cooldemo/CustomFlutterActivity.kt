package com.example.cooldemo

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class CustomFlutterActivity : FlutterActivity() {

    companion object {
        const val CHANNEL = "com.example.cooldemo/navigation"
    }

    private var methodChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        flutterEngine?.let { engine ->
            methodChannel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            methodChannel?.setMethodCallHandler { call, result ->
                when (call.method) {
                    "openNativeSecondPage" -> {
                        startActivity(Intent(this, SecondActivity::class.java))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }
}
