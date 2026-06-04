package com.example.cooldemo.webview

import android.webkit.JavascriptInterface
import java.lang.ref.WeakReference

fun interface JsMessageHandler {
    fun onMessage(message: String)
}

/**
 * Avoids letting JavaScript bridge callbacks keep an Activity or View strongly reachable.
 */
class SafeJsBridge(handler: JsMessageHandler) {

    private val handlerRef = WeakReference(handler)

    @JavascriptInterface
    fun postMessage(message: String) {
        handlerRef.get()?.onMessage(message)
    }
}
