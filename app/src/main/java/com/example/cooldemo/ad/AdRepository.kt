package com.example.cooldemo.ad

import kotlinx.coroutines.delay

/**
 * 广告数据仓库 — 模拟 Retrofit 接口请求
 * 三个独立接口，各自不同的地址和参数
 */
class AdRepository {

    /**
     * 接口1：获取首页活动广告
     * GET /api/ad/home/activity?position=banner_top
     */
    suspend fun fetchHomeActivityAd(position: String): ApiResult<AdInfo> {
        delay(800)
        return ApiResult.Success(
            data = AdInfo(id = 1, title = "夏日特惠", content = "全场商品低至5折，限时抢购！")
        )
    }

    /**
     * 接口2：获取限时促销广告
     * GET /api/ad/flash-sale?category=electronics&region=china
     */
    suspend fun fetchFlashSaleAd(category: String, region: String): ApiResult<AdInfo> {
        delay(600)
        // 模拟接口报错
        return ApiResult.Error(
            code = "AD_NOT_FOUND",
            message = "限时促销广告资源不存在"
        )
    }

    /**
     * 接口3：获取新用户专享广告
     * GET /api/ad/new-user-bonus?userId=12345&source=app_launch
     */
    suspend fun fetchNewUserBonusAd(userId: String, source: String): ApiResult<AdInfo> {
        delay(500)
        return ApiResult.Success(
            data = AdInfo(id = 3, title = "新用户专享", content = "注册即送100元优惠券，快来领取！")
        )
    }
}
