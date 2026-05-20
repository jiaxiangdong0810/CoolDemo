package com.example.cooldemo

import android.content.Context
import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.example.cooldemo.native.UserApiImpl
import com.example.cooldemo.native.SettingApiImpl
import com.example.cooldemo.pigeon.UserApi
import com.example.cooldemo.pigeon.SettingApi

/**
 * 自定义 FlutterActivity，每个实例绑定独立的 Engine。
 *
 * 设计要点：
 * - 通过 [provideFlutterEngine] 为每个 Activity 实例创建独立 Engine
 * - Activity 真正 finish 时销毁 Engine，避免状态残留
 * - 配置变更（如旋转）时保留 Engine，避免重建
 * - 不同 Flow 的页面互不干扰，各自维护自己的 Navigator 栈
 */
class HybridFlutterActivity : FlutterActivity() {

    companion object {
        const val EXTRA_INITIAL_ROUTE = "extra_initial_route"

        /**
         * 创建打开指定 Flow 的 Intent。
         */
        fun createIntent(context: Context, flow: FlowConfig): Intent {
            return Intent(context, HybridFlutterActivity::class.java).apply {
                putExtra(EXTRA_INITIAL_ROUTE, flow.initialRoute)
            }
        }
    }

    private var engine: FlutterEngine? = null
    private var methodChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        flutterEngine?.let { engine ->
            val messenger = engine.dartExecutor.binaryMessenger

            // Pigeon API 注册
            UserApi.setUp(messenger, UserApiImpl(this))
            SettingApi.setUp(messenger, SettingApiImpl(this))

            // 保留原有 MethodChannel（暂不迁移）
            methodChannel = MethodChannel(
                messenger,
                "com.example.cooldemo/navigation"
            )
            methodChannel?.setMethodCallHandler { call, result ->
                when (call.method) {
                    else -> result.notImplemented()
                }
            }
        }
    }

    /**
     * 提供 FlutterEngine。每个 Activity 实例拥有独立的 Engine。
     * 首次调用时创建，之后复用（应对配置变更等场景）。
     */
    override fun provideFlutterEngine(context: Context): FlutterEngine {
        if (engine == null) {
            val initialRoute = intent.getStringExtra(EXTRA_INITIAL_ROUTE) ?: "/"
            engine = FlutterHybrid.createEngine(context, initialRoute)
        }
        return engine!!
    }

    /**
     * 允许 Engine 绑定到 Activity 生命周期，接收 onResume/onPause 等事件。
     */
    override fun shouldAttachEngineToActivity(): Boolean = true

    override fun onDestroy() {
        super.onDestroy()
        // 只有 Activity 真正 finish 时才销毁 Engine
        // 配置变更（如旋转）时 isFinishing 为 false，Engine 得以保留复用
        if (isFinishing) {
            engine?.destroy()
            engine = null
        }
    }
}
