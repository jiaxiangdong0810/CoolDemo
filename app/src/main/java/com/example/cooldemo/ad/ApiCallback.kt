package com.example.cooldemo.ad

import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.launch

/**
 * 回调构建器
 */
class ApiCallback<T> {
    var onSuccess: (T) -> Unit = { _ -> }
    var onError: (code: String, message: String) -> Unit = { _, _ -> }
    var onFinished: () -> Unit = {}
}

/**
 * 扩展函数：将 suspend 的 ApiResult 调用转为回调式写法
 *
 * 用法：
 * fetchAd(adViewModel::fetchHomeActivityAd) {
 *     onSuccess = { ad -> showAdDialog(ad) }
 *     onError = { code, msg -> ... }
 *     onFinished = { ... }
 * }
 */
fun <T> LifecycleOwner.fetchAd(
    call: suspend () -> ApiResult<T>,
    block: ApiCallback<T>.() -> Unit
) {
    val callback = ApiCallback<T>().apply(block)
    lifecycleScope.launch {
        when (val result = call()) {
            is ApiResult.Success -> callback.onSuccess(result.data)
            is ApiResult.Error -> callback.onError(result.code, result.message)
            is ApiResult.Finished -> callback.onFinished()
        }
    }
}
