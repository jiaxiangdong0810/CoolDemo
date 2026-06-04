package com.example.cooldemo.ad

/**
 * 广告信息
 */
data class AdInfo(
    val id: Int,
    val title: String,
    val content: String,
    val imageUrl: String? = null
)

/**
 * 统一 API 响应封装（三态：成功、失败、结束）
 */
sealed class ApiResult<out T> {
    data class Success<T>(val data: T) : ApiResult<T>()
    data class Error(val code: String, val message: String) : ApiResult<Nothing>()
    data object Finished : ApiResult<Nothing>()
}
