package com.example.cooldemo.webview

import android.content.Context
import android.os.Build
import android.util.AttributeSet
import android.view.ViewGroup
import android.webkit.WebChromeClient
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.FrameLayout
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import org.json.JSONObject

class SafeWebView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null
) : FrameLayout(context, attrs), DefaultLifecycleObserver {

    private var webView: WebView? = null
    private var destroyed = false
    private val jsBridgeNames = mutableSetOf<String>()

    init {
        webView = createWebView().also { addView(it) }
    }

    fun bindTo(owner: LifecycleOwner) {
        owner.lifecycle.addObserver(this)
    }

    fun configure(options: SafeWebViewOptions = SafeWebViewOptions()) {
        currentWebView().applyOptions(options)
    }

    fun loadUrl(url: String, headers: Map<String, String> = emptyMap()) {
        currentWebView().loadUrl(url, headers)
    }

    fun setSafeWebViewClient(client: WebViewClient) {
        currentWebView().webViewClient = client
    }

    fun setSafeWebChromeClient(client: WebChromeClient?) {
        currentWebView().webChromeClient = client
    }

    fun addJsBridge(name: String, handler: JsMessageHandler) {
        currentWebView().addJavascriptInterface(SafeJsBridge(handler), name)
        jsBridgeNames += name
    }

    fun evaluateJavascript(script: String, onResult: ((String?) -> Unit)? = null) {
        currentWebView().evaluateJavascript(script, onResult)
    }

    fun callJavascriptFunction(
        functionName: String,
        vararg args: String,
        onResult: ((String?) -> Unit)? = null
    ) {
        val encodedArgs = args.joinToString(separator = ",") { JSONObject.quote(it) }
        evaluateJavascript("$functionName($encodedArgs)", onResult)
    }

    fun currentWebView(): WebView {
        return webView ?: error("WebView has already been destroyed.")
    }

    override fun onResume(owner: LifecycleOwner) {
        webView?.onResume()
    }

    override fun onPause(owner: LifecycleOwner) {
        webView?.onPause()
    }

    override fun onDestroy(owner: LifecycleOwner) {
        owner.lifecycle.removeObserver(this)
        destroySafely()
    }

    fun destroySafely() {
        if (destroyed) return
        destroyed = true

        val target = webView ?: return
        webView = null

        runCatching { target.stopLoading() }
        runCatching { target.loadUrl("about:blank") }
        jsBridgeNames.forEach { name ->
            runCatching { target.removeJavascriptInterface(name) }
        }
        jsBridgeNames.clear()
        target.clearFocus()
        target.webChromeClient = null
        target.webViewClient = WebViewClient()
        target.removeAllViews()
        (target.parent as? ViewGroup)?.removeView(target)
        target.destroy()
    }

    private fun createWebView(): WebView {
        return WebView(context.applicationContext).apply {
            layoutParams = LayoutParams(
                LayoutParams.MATCH_PARENT,
                LayoutParams.MATCH_PARENT
            )
            isSaveEnabled = false
            overScrollMode = OVER_SCROLL_NEVER
            applyOptions(SafeWebViewOptions())
        }
    }

    private fun WebView.applyOptions(options: SafeWebViewOptions) {
        settings.apply {
            javaScriptEnabled = options.javaScriptEnabled
            domStorageEnabled = options.domStorageEnabled
            databaseEnabled = options.domStorageEnabled
            cacheMode = WebSettings.LOAD_DEFAULT
            loadsImagesAutomatically = true
            mediaPlaybackRequiresUserGesture = true
            allowFileAccess = false
            allowContentAccess = false
            setSupportMultipleWindows(false)
            javaScriptCanOpenWindowsAutomatically = false
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                safeBrowsingEnabled = true
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                mixedContentMode = WebSettings.MIXED_CONTENT_NEVER_ALLOW
            }
        }
    }
}

data class SafeWebViewOptions(
    val javaScriptEnabled: Boolean = false,
    val domStorageEnabled: Boolean = true
)
