package com.example.cooldemo.native

import android.content.Context
import android.content.SharedPreferences
import android.os.Build
import com.example.cooldemo.pigeon.SettingApi
import com.example.cooldemo.pigeon.ApiResponse
import org.json.JSONObject

class SettingApiImpl(context: Context) : SettingApi {

    private val prefs: SharedPreferences =
        context.getSharedPreferences("setting_prefs", Context.MODE_PRIVATE)

    companion object {
        private const val KEY_NOTIFICATION = "notification_enabled"
        private const val KEY_DARK_MODE = "dark_mode"
        private const val KEY_LANGUAGE = "language"
        private const val KEY_FONT_SIZE = "font_size"
        private const val KEY_AUTO_PLAY = "auto_play"
    }

    init {
        if (prefs.all.isEmpty()) {
            prefs.edit().apply {
                putString(KEY_NOTIFICATION, "true")
                putString(KEY_DARK_MODE, "system")
                putString(KEY_LANGUAGE, "zh")
                putString(KEY_FONT_SIZE, "medium")
                putString(KEY_AUTO_PLAY, "false")
                apply()
            }
        }
    }

    override fun getAllSettings(callback: (Result<ApiResponse>) -> Unit) {
        val json = JSONObject().apply {
            put(KEY_NOTIFICATION, prefs.getString(KEY_NOTIFICATION, "true"))
            put(KEY_DARK_MODE, prefs.getString(KEY_DARK_MODE, "system"))
            put(KEY_LANGUAGE, prefs.getString(KEY_LANGUAGE, "zh"))
            put(KEY_FONT_SIZE, prefs.getString(KEY_FONT_SIZE, "medium"))
            put(KEY_AUTO_PLAY, prefs.getString(KEY_AUTO_PLAY, "false"))
        }
        callback(Result.success(ApiResponse(success = true, data = json.toString())))
    }

    override fun getSetting(key: String, callback: (Result<ApiResponse>) -> Unit) {
        val value = prefs.getString(key, null)
        callback(Result.success(ApiResponse(success = true, data = value)))
    }

    override fun updateSetting(key: String, value: String?, callback: (Result<ApiResponse>) -> Unit) {
        prefs.edit().putString(key, value).apply()
        callback(Result.success(ApiResponse(success = true)))
    }

    override fun getDeviceInfo(callback: (Result<ApiResponse>) -> Unit) {
        val json = JSONObject().apply {
            put("platform", "Android")
            put("osVersion", Build.VERSION.RELEASE)
            put("deviceModel", Build.MODEL)
            put("appVersion", "1.0.0")
        }
        callback(Result.success(ApiResponse(success = true, data = json.toString())))
    }
}
