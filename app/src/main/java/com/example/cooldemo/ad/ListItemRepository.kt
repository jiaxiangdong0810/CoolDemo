package com.example.cooldemo.ad

import kotlinx.coroutines.delay

class ListItemRepository {

    suspend fun fetchListItems(): ApiResult<List<ListItem>> {
        delay(1000) // 模拟网络请求
        return ApiResult.Success(
            data = listOf(
                ListItem(1, "Kotlin 协程", "轻量级线程框架，简化异步编程"),
                ListItem(2, "StateFlow", "响应式状态管理，驱动 UI 更新"),
                ListItem(3, "MVVM 架构", "Model-View-ViewModel 分层设计"),
                ListItem(4, "Retrofit", "类型安全的 HTTP 客户端"),
                ListItem(5, "Room 数据库", "SQLite 的抽象层，编译时校验"),
                ListItem(6, "Jetpack Compose", "声明式 UI 框架"),
                ListItem(7, "Hilt 依赖注入", "Android 官方 DI 方案"),
                ListItem(8, "Navigation", "页面导航组件"),
            )
        )
    }
}
