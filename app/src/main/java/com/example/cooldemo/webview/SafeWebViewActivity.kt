package com.example.cooldemo.webview

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.net.Uri
import android.os.Bundle
import android.view.View
import android.webkit.WebChromeClient
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.Toast
import androidx.activity.OnBackPressedCallback
import androidx.appcompat.app.AppCompatActivity
import androidx.core.view.isVisible
import com.example.cooldemo.databinding.ActivitySafeWebviewBinding

class SafeWebViewActivity : AppCompatActivity() {

    private lateinit var binding: ActivitySafeWebviewBinding
    private val initialUrl by lazy { intent.getStringExtra(EXTRA_URL) }
    private val localAssetPath by lazy { intent.getStringExtra(EXTRA_ASSET_PATH) }
    private val initialTitle by lazy { intent.getStringExtra(EXTRA_TITLE) ?: "WebView" }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivitySafeWebviewBinding.inflate(layoutInflater)
        setContentView(binding.root)

        binding.textTitle.text = initialTitle
        binding.buttonBack.setOnClickListener { navigateBack() }
        binding.buttonCallJs.setOnClickListener { callHtmlFunction() }
        binding.buttonRetry.setOnClickListener { reload() }

        setupWebView()
        setupBackPress()

        loadInitialPage()
    }

    private fun setupWebView() {
        binding.safeWebView.bindTo(this)
        binding.safeWebView.configure(
            SafeWebViewOptions(
                javaScriptEnabled = true,
                domStorageEnabled = true
            )
        )
        binding.safeWebView.setSafeWebViewClient(PageClient())
        binding.safeWebView.setSafeWebChromeClient(ProgressClient())
        binding.safeWebView.addJsBridge("NativeBridge") { message ->
            Toast.makeText(this, "JS: $message", Toast.LENGTH_SHORT).show()
        }
    }

    private fun setupBackPress() {
        onBackPressedDispatcher.addCallback(
            this,
            object : OnBackPressedCallback(true) {
                override fun handleOnBackPressed() {
                    navigateBack()
                }
            }
        )
    }

    private fun navigateBack() {
        val webView = binding.safeWebView.currentWebView()
        if (webView.canGoBack()) {
            webView.goBack()
        } else {
            finish()
        }
    }

    private fun reload() {
        binding.layoutError.isVisible = false
        if (localAssetPath != null) {
            loadInitialPage()
        } else {
            binding.safeWebView.currentWebView().reload()
        }
    }

    private fun loadInitialPage() {
        val assetPath = localAssetPath
        if (assetPath != null) {
            val html = assets.open(assetPath).bufferedReader().use { it.readText() }
            binding.safeWebView.currentWebView().loadDataWithBaseURL(
                "https://local.cooldemo/$assetPath",
                html,
                "text/html",
                "UTF-8",
                null
            )
            return
        }

        binding.safeWebView.loadUrl(requireNotNull(initialUrl))
    }

    private fun callHtmlFunction() {
        binding.safeWebView.callJavascriptFunction(
            "window.onNativeMessage",
            "Native 调用了 HTML 函数: ${System.currentTimeMillis()}"
        ) { result ->
            Toast.makeText(this, "HTML 返回: $result", Toast.LENGTH_SHORT).show()
        }
    }

    private inner class PageClient : WebViewClient() {
        override fun shouldOverrideUrlLoading(
            view: WebView,
            request: WebResourceRequest
        ): Boolean {
            val uri = request.url
            if (uri.scheme == "http" || uri.scheme == "https") return false
            return openExternal(uri)
        }

        override fun onPageStarted(view: WebView, url: String?, favicon: Bitmap?) {
            binding.layoutError.isVisible = false
            binding.progressBar.isVisible = true
        }

        override fun onPageFinished(view: WebView, url: String?) {
            binding.progressBar.isVisible = false
            val pageTitle = view.title
            if (!pageTitle.isNullOrBlank()) {
                binding.textTitle.text = pageTitle
            }
        }

        override fun onReceivedError(
            view: WebView,
            request: WebResourceRequest,
            error: WebResourceError
        ) {
            if (request.isForMainFrame) {
                binding.progressBar.isVisible = false
                binding.layoutError.isVisible = true
            }
        }
    }

    private inner class ProgressClient : WebChromeClient() {
        override fun onProgressChanged(view: WebView, newProgress: Int) {
            binding.progressBar.progress = newProgress
            binding.progressBar.visibility =
                if (newProgress in 1 until 100) View.VISIBLE else View.GONE
        }
    }

    private fun openExternal(uri: Uri): Boolean {
        val intent = Intent(Intent.ACTION_VIEW, uri)
        if (intent.resolveActivity(packageManager) == null) return true
        startActivity(intent)
        return true
    }

    companion object {
        private const val EXTRA_URL = "extra_url"
        private const val EXTRA_TITLE = "extra_title"
        private const val EXTRA_ASSET_PATH = "extra_asset_path"

        fun createIntent(context: Context, url: String, title: String): Intent {
            return Intent(context, SafeWebViewActivity::class.java)
                .putExtra(EXTRA_URL, url)
                .putExtra(EXTRA_TITLE, title)
        }

        fun createAssetIntent(context: Context, assetPath: String, title: String): Intent {
            return Intent(context, SafeWebViewActivity::class.java)
                .putExtra(EXTRA_ASSET_PATH, assetPath)
                .putExtra(EXTRA_TITLE, title)
        }
    }
}
