package com.example.cooldemo

import android.app.Application
import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.FlutterEngineGroup
import io.flutter.embedding.engine.dart.DartExecutor

/**
 * FlutterEngine 管理类，基于 FlutterEngineGroup 实现。
 *
 * 适用场景：原生页面与 Flutter 页面逐个跳转（非多 Flutter 页面同时展示）。
 * 通过共享 Dart VM 和 isolate group snapshot，显著降低多 Engine 的内存开销。
 */
object FlutterEngineManager {

    private const val DEFAULT_ENGINE_ID = "default_engine"

    private var engineGroup: FlutterEngineGroup? = null

    /**
     * 初始化 EngineGroup。建议在 Application.onCreate() 中调用。
     */
    fun init(application: Application) {
        if (engineGroup != null) return
        engineGroup = FlutterEngineGroup(application)
    }

    /**
     * 预创建默认 Engine 并放入缓存，用于提升 Flutter 页面首屏打开速度。
     * 可在 Application.onCreate() 中调用，或在合适的时机（如首页加载后）调用。
     */
    fun prepareDefaultEngine(context: Context) {
        getOrCreateEngine(context, DEFAULT_ENGINE_ID)
    }

    /**
     * 获取或创建指定 ID 的 Engine。
     * 如果缓存中已存在，直接返回；否则通过 EngineGroup 创建新的 Engine。
     */
    fun getOrCreateEngine(context: Context, engineId: String): FlutterEngine {
        FlutterEngineCache.getInstance().get(engineId)?.let { return it }

        val engine = engineGroup!!.createAndRunEngine(
            context,
            DartExecutor.DartEntrypoint.createDefault()
        )
        FlutterEngineCache.getInstance().put(engineId, engine)
        return engine
    }

    /**
     * 创建指定初始路由的 Engine 并缓存。
     * 适用于原生直接跳转到指定 Flutter 页面的场景。
     * 通过 EngineGroup 复用 Dart VM，仅创建新的 isolate。
     */
    fun createEngineWithRoute(context: Context, engineId: String, initialRoute: String): FlutterEngine {
        FlutterEngineCache.getInstance().get(engineId)?.let {
            it.destroy()
            FlutterEngineCache.getInstance().remove(engineId)
        }

        val engine = engineGroup!!.createAndRunEngine(
            context,
            DartExecutor.DartEntrypoint.createDefault(),
            initialRoute
        )
        FlutterEngineCache.getInstance().put(engineId, engine)
        return engine
    }

    /**
     * 获取默认 Engine 的缓存 ID，供 FlutterActivity.withCachedEngine() 使用。
     */
    fun getDefaultEngineId(): String = DEFAULT_ENGINE_ID

    /**
     * 判断指定 ID 的 Engine 是否已在缓存中。
     */
    fun hasEngine(engineId: String): Boolean {
        return FlutterEngineCache.getInstance().get(engineId) != null
    }

    /**
     * 销毁指定 ID 的 Engine。一般不需要手动调用，除非需要精确控制内存。
     */
    fun destroyEngine(engineId: String) {
        FlutterEngineCache.getInstance().get(engineId)?.destroy()
        FlutterEngineCache.getInstance().remove(engineId)
    }

    /**
     * 销毁所有管理的 Engine。建议在 Application.onTerminate() 或内存紧张时调用。
     */
    fun destroyAll() {
        FlutterEngineCache.getInstance().apply {
            // FlutterEngineCache 没有提供遍历方法，默认只处理 default_engine
            // 如果有其他 engine，建议在外部维护 ID 列表后批量销毁
            get(DEFAULT_ENGINE_ID)?.destroy()
            remove(DEFAULT_ENGINE_ID)
        }
        engineGroup = null
    }
}
