package com.example.cooldemo.native

import android.content.Context
import android.content.SharedPreferences
import com.example.cooldemo.pigeon.UserApi
import com.example.cooldemo.pigeon.ApiResponse
import com.example.cooldemo.pigeon.UserInfo
import org.json.JSONObject

class UserApiImpl(context: Context) : UserApi {

    private val prefs: SharedPreferences =
        context.getSharedPreferences("user_prefs", Context.MODE_PRIVATE)

    companion object {
        private const val KEY_USER_ID = "user_id"
        private const val KEY_NICKNAME = "nickname"
        private const val KEY_AVATAR = "avatar_url"
        private const val KEY_EMAIL = "email"
        private const val KEY_PHONE = "phone"
        private const val KEY_VIP = "vip_level"
        private const val KEY_LOGGED_IN = "is_logged_in"
    }

    override fun getCurrentUser(callback: (Result<ApiResponse>) -> Unit) {
        val userId = prefs.getString(KEY_USER_ID, null)
        if (userId == null) {
            callback(Result.success(ApiResponse(success = true, data = null)))
            return
        }
        val json = JSONObject().apply {
            put("userId", userId)
            put("nickname", prefs.getString(KEY_NICKNAME, null))
            put("avatarUrl", prefs.getString(KEY_AVATAR, null))
            put("email", prefs.getString(KEY_EMAIL, null))
            put("phone", prefs.getString(KEY_PHONE, null))
            put("vipLevel", prefs.getInt(KEY_VIP, 0))
        }
        callback(Result.success(ApiResponse(success = true, data = json.toString())))
    }

    override fun isLoggedIn(callback: (Result<ApiResponse>) -> Unit) {
        val loggedIn = prefs.getBoolean(KEY_LOGGED_IN, false)
        callback(Result.success(ApiResponse(success = true, data = loggedIn.toString())))
    }

    override fun updateUserInfo(userInfo: UserInfo, callback: (Result<ApiResponse>) -> Unit) {
        prefs.edit().apply {
            putString(KEY_USER_ID, userInfo.userId)
            putString(KEY_NICKNAME, userInfo.nickname)
            putString(KEY_AVATAR, userInfo.avatarUrl)
            putString(KEY_EMAIL, userInfo.email)
            putString(KEY_PHONE, userInfo.phone)
            userInfo.vipLevel?.let { putInt(KEY_VIP, it.toInt()) }
            putBoolean(KEY_LOGGED_IN, true)
            apply()
        }
        callback(Result.success(ApiResponse(success = true)))
    }

    override fun logout(callback: (Result<ApiResponse>) -> Unit) {
        prefs.edit().clear().apply()
        callback(Result.success(ApiResponse(success = true)))
    }
}
