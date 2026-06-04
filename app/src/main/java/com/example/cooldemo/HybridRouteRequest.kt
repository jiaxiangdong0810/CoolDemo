package com.example.cooldemo

import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

/**
 * Native 与 Flutter 之间统一传递的 JSON 路由协议。
 */
data class HybridRouteRequest(
    val target: String,
    val path: String,
    val params: Map<String, Any?> = emptyMap(),
    val from: String = "native",
    val version: Int = 1,
    val requestId: String = UUID.randomUUID().toString()
) {
    fun toJson(): String {
        return JSONObject().apply {
            put("scheme", SCHEME)
            put("target", target)
            put("path", path)
            put("params", params.toJsonObject())
            put("from", from)
            put("version", version)
            put("requestId", requestId)
        }.toString()
    }

    companion object {
        const val SCHEME = "cooldemo"
        const val TARGET_FLUTTER = "flutter"
        const val TARGET_NATIVE = "native"

        fun flutter(
            path: String,
            params: Map<String, Any?> = emptyMap(),
            from: String = "native"
        ): HybridRouteRequest {
            return HybridRouteRequest(
                target = TARGET_FLUTTER,
                path = path,
                params = params,
                from = from
            )
        }
    }
}

private fun Map<String, Any?>.toJsonObject(): JSONObject {
    return JSONObject().also { json ->
        forEach { (key, value) ->
            json.put(key, value.toJsonValue())
        }
    }
}

private fun Any?.toJsonValue(): Any? {
    return when (this) {
        null -> JSONObject.NULL
        is Map<*, *> -> JSONObject().also { json ->
            forEach { (key, value) ->
                if (key is String) {
                    json.put(key, value.toJsonValue())
                }
            }
        }
        is Iterable<*> -> JSONArray().also { array ->
            forEach { item -> array.put(item.toJsonValue()) }
        }
        else -> this
    }
}
