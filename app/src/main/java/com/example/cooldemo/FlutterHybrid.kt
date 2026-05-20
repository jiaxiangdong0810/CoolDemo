package com.example.cooldemo

import android.app.Application
import android.content.Context
import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineGroup
import io.flutter.embedding.engine.dart.DartExecutor

/**
 * Flutter 混合开发统一入口。
 *
 * 基于 FlutterEngineGroup 实现，多个 Flow 共享 Dart VM，
 * 每个 Flow 拥有独立的 Engine 和 Navigator 栈。
 *
 * 使用方式：
 * ```
 * // Application.onCreate() 中初始化
 * FlutterHybrid.init(this)
 *
 * // 任意原生页面中打开 Flutter
 * val flow = FlowConfig(flowId = "ai_chat", initialRoute = "/model_setup")
 * startActivity(FlutterHybrid.open(this, flow))
 * ```
 */
object FlutterHybrid {

    private var engineGroup: FlutterEngineGroup? = null

    /**
     * 在 Application.onCreate() 中初始化，创建 FlutterEngineGroup。
     */
    fun init(application: Application) {
        if (engineGroup != null) return
        engineGroup = FlutterEngineGroup(application)
    }

    /**
     * 打开指定的 Flutter 业务流。
     *
     * @param context 上下文
     * @param flow 业务流配置
     * @return 启动 HybridFlutterActivity 的 Intent
     */
    fun open(context: Context, flow: FlowConfig): Intent {
        return HybridFlutterActivity.createIntent(context, flow)
    }

    /**
     * 创建新的 FlutterEngine，绑定指定初始路由。
     * 由 HybridFlutterActivity 在需要时调用，业务代码不应直接调用。
     */
    internal fun createEngine(context: Context, initialRoute: String): FlutterEngine {
        return engineGroup!!.createAndRunEngine(
            context,
            DartExecutor.DartEntrypoint.createDefault(),
            initialRoute
        )
    }
}
