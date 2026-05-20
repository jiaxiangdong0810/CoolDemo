package com.example.cooldemo

import android.Manifest
import android.content.SharedPreferences
import android.os.Build
import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import com.example.cooldemo.databinding.ActivityMainBinding
import com.permissionx.guolindev.PermissionX
import kotlin.random.Random

class MainActivity : AppCompatActivity() {

    private lateinit var binding: ActivityMainBinding
    private lateinit var userPrefs: SharedPreferences

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

        userPrefs = getSharedPreferences("user_prefs", MODE_PRIVATE)

        requestStoragePermission()
        updateUserDisplay()

        binding.buttonOpenFeatures.setOnClickListener {
            startActivity(android.content.Intent(this, FeaturesActivity::class.java))
        }

        binding.buttonUpdateUser.setOnClickListener {
            updateUserInfo()
        }
    }

    override fun onResume() {
        super.onResume()
        updateUserDisplay()
    }

    private fun updateUserInfo() {
        val names = listOf("小明", "小红", "张三", "李四", "王五", "Alice", "Bob", "Charlie")
        val randomName = names[Random.nextInt(names.size)]
        val randomVip = Random.nextInt(0, 6)

        userPrefs.edit().apply {
            putString("user_id", "user_${Random.nextInt(1000, 9999)}")
            putString("nickname", randomName)
            putString("avatar_url", null)
            putString("email", "$randomName@example.com")
            putString("phone", "138${Random.nextInt(10000000, 99999999)}")
            putInt("vip_level", randomVip)
            putBoolean("is_logged_in", true)
            apply()
        }

        updateUserDisplay()
    }

    private fun updateUserDisplay() {
        val userId = userPrefs.getString("user_id", null)
        val nickname = userPrefs.getString("nickname", null)
        val display = if (userId != null) {
            "当前用户: ${nickname ?: userId}"
        } else {
            "当前用户: 未设置（点击按钮生成）"
        }
        binding.textCurrentUser.text = display
    }

    private fun requestStoragePermission() {
        val permissions = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            listOf(
                Manifest.permission.READ_MEDIA_IMAGES,
                Manifest.permission.READ_MEDIA_VIDEO,
                Manifest.permission.READ_MEDIA_AUDIO
            )
        } else {
            listOf(Manifest.permission.READ_EXTERNAL_STORAGE)
        }

        PermissionX.init(this)
            .permissions(permissions)
            .onExplainRequestReason { scope, deniedList ->
                scope.showRequestReasonDialog(deniedList, "需要文件读取权限才能正常使用应用功能", "确定")
            }
            .onForwardToSettings { scope, deniedList ->
                scope.showForwardToSettingsDialog(deniedList, "请在设置中开启文件读取权限", "去设置")
            }
            .request { allGranted, _, _ ->
                if (allGranted) {
                    // 权限已授予
                }
            }
    }
}