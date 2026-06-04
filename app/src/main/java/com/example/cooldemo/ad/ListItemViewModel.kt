package com.example.cooldemo.ad

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

class ListItemViewModel : ViewModel() {

    private val repository = ListItemRepository()

    // ── 核心：只暴露一个 StateFlow，UI 观察它 ──
    private val _uiState = MutableStateFlow(ListUiState())
    val uiState: StateFlow<ListUiState> = _uiState.asStateFlow()

    // ── 公开方法：UI 触发请求 ──
    fun loadList() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, errorMessage = null) }

            when (val result = repository.fetchListItems()) {
                is ApiResult.Success -> {
                    _uiState.update {
                        it.copy(isLoading = false, items = result.data)
                    }
                }
                is ApiResult.Error -> {
                    _uiState.update {
                        it.copy(isLoading = false, errorMessage = result.message)
                    }
                }
                is ApiResult.Finished -> {
                    _uiState.update { it.copy(isLoading = false) }
                }
            }
        }
    }
}
