package com.example.cooldemo.ad

import androidx.lifecycle.ViewModel

class AdViewModel : ViewModel() {

    private val repository = AdRepository()

    /**
     * 接口1：首页活动广告
     */
    suspend fun fetchHomeActivityAd(): ApiResult<AdInfo> {
        return repository.fetchHomeActivityAd(position = "banner_top")
    }

    /**
     * 接口2：限时促销广告
     */
    suspend fun fetchFlashSaleAd(): ApiResult<AdInfo> {
        return repository.fetchFlashSaleAd(category = "electronics", region = "china")
    }

    /**
     * 接口3：新用户专享广告
     */
    suspend fun fetchNewUserBonusAd(): ApiResult<AdInfo> {
        return repository.fetchNewUserBonusAd(userId = "12345", source = "app_launch")
    }
}
