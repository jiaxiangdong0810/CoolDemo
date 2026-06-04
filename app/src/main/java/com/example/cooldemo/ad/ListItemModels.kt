package com.example.cooldemo.ad

data class ListItem(
    val id: Int,
    val title: String,
    val subtitle: String
)

data class ListUiState(
    val isLoading: Boolean = false,
    val items: List<ListItem> = emptyList(),
    val errorMessage: String? = null
)
