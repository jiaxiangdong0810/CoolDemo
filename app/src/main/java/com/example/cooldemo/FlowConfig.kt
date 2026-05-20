package com.example.cooldemo

/**
 * Flutter 业务流配置。
 *
 * 一个 Flow = 一组相关的 Flutter 页面，共享一个 Engine。
 * 不同 Flow 之间完全隔离，互不影响 Navigator 栈。
 */
data class FlowConfig(
    /** 流唯一标识，用于 Engine 管理和调试 */
    val flowId: String,
    /** Flutter 入口路由，对应 Dart 层的 onGenerateRoute */
    val initialRoute: String
)
