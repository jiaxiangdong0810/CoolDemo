package com.example.cooldemo

import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import com.example.cooldemo.databinding.ActivityFeaturesBinding

/**
 * 功能入口页面
 *
 * 演示使用最新 Router 架构（FlowConfig + FlutterHybrid）进入不同 Flutter 模块：
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
            val flow = FlowConfig(
                flowId = "ai_chat",
                initialRoute = "/model_setup"
            )
            startActivity(FlutterHybrid.open(this, flow))
        }

        // 设置模块
        binding.buttonOpenSettings.setOnClickListener {
            val flow = FlowConfig(
                flowId = "settings",
                initialRoute = "/settings"
            )
            startActivity(FlutterHybrid.open(this, flow))
        }

        // 用户协议模块
        binding.buttonOpenAgreement.setOnClickListener {
            val flow = FlowConfig(
                flowId = "agreement",
                initialRoute = "/agreement"
            )
            startActivity(FlutterHybrid.open(this, flow))
        }
    }
}
