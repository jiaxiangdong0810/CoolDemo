package com.example.cooldemo

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

class MainViewModel : ViewModel() {

    // StateFlow：用于 UI 状态（有状态，新订阅者立即拿到最新值）
    private val _count = MutableStateFlow(1)
    val count: StateFlow<Int> = _count.asStateFlow()

    // SharedFlow：用于一次性事件（如 Toast、导航）
    private val _toastEvent = MutableSharedFlow<String>()
    val toastEvent: SharedFlow<String> = _toastEvent.asSharedFlow()

    fun increment() {
        _count.update { it + 1 }

        // 每增加 5 次发送一个事件
        if (_count.value % 5 == 0) {
            viewModelScope.launch {
                _toastEvent.emit("已达到 ${_count.value}！")
            }
        }
    }
}
