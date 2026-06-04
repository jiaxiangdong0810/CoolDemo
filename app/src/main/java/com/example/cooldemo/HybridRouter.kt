package com.example.cooldemo

import android.content.Context
import android.content.Intent

/**
 * 混合路由统一入口，业务侧只提交 JSON 路由请求。
 */
object HybridRouter {

    fun open(context: Context, request: HybridRouteRequest): Intent {
        return when (request.target) {
            HybridRouteRequest.TARGET_FLUTTER -> FlutterHybrid.open(context, request)
            else -> throw IllegalArgumentException("Unsupported route target: ${request.target}")
        }
    }

    fun openFlutter(
        context: Context,
        path: String,
        params: Map<String, Any?> = emptyMap()
    ): Intent {
        return open(
            context,
            HybridRouteRequest.flutter(
                path = path,
                params = params
            )
        )
    }
}
