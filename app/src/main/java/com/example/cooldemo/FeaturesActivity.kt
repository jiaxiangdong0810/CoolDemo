package com.example.cooldemo

import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import com.example.cooldemo.databinding.ActivityFeaturesBinding
import com.example.cooldemo.webview.SafeWebViewActivity

/**
 * 功能入口页面
 *
 * 演示使用统一 JSON 路由协议进入不同 Flutter 模块：
 * - AI 聊天: /model_setup
 * - 设置:    /settings
 * - 协议:    /agreement
 *
 * 每个模块独立一个 Flow（独立 Engine），互不影响。
 */
class FeaturesActivity : AppCompatActivity() {

    private lateinit var binding: ActivityFeaturesBinding

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityFeaturesBinding.inflate(layoutInflater)
        setContentView(binding.root)

        // AI 聊天模块
        binding.buttonOpenAiChat.setOnClickListener {
            startActivity(
                HybridRouter.openFlutter(
                    this,
                    "/model_setup",
                    mapOf(
                        "flowId" to "ai_chat",
                        "source" to "features_page"
                    )
                )
            )
        }

        // 设置模块
        binding.buttonOpenSettings.setOnClickListener {
            startActivity(
                HybridRouter.openFlutter(
                    this,
                    "/settings",
                    mapOf(
                        "flowId" to "settings",
                        "tab" to "account",
                        "source" to "features_page"
                    )
                )
            )
        }

        // 用户协议模块
        binding.buttonOpenAgreement.setOnClickListener {
            startActivity(
                HybridRouter.openFlutter(
                    this,
                    "/agreement",
                    mapOf(
                        "flowId" to "agreement",
                        "source" to "features_page"
                    )
                )
            )
        }

        binding.buttonOpenWebview.setOnClickListener {
            startActivity(
                SafeWebViewActivity.createIntent(
                    this,
                    "https://developer.android.com/develop/ui/views/layout/webapps",
                    "Android WebView"
                )
            )
        }

        binding.buttonNavCase1.setOnClickListener {
            openNavigationCase("nav_case_1", "/nav_case_1")
        }

        binding.buttonNavCase2.setOnClickListener {
            openNavigationCase("nav_case_2", "/nav_case_2")
        }

        binding.buttonNavCase3.setOnClickListener {
            openNavigationCase("nav_case_3", "/nav_case_3")
        }

        binding.buttonNavCase4.setOnClickListener {
            openNavigationCase("nav_case_4", "/nav_case_4")
        }
    }

    private fun openNavigationCase(flowId: String, route: String) {
        startActivity(
            HybridRouter.openFlutter(
                this,
                route,
                mapOf(
                    "flowId" to flowId,
                    "source" to "navigation_case"
                )
            )
        )
    }
}
