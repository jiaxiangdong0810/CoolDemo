package com.example.cooldemo

import android.Manifest
import android.content.ComponentName
import android.content.Intent
import android.os.Build
import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import io.flutter.embedding.android.FlutterActivity
import com.example.cooldemo.databinding.ActivityMainBinding
import com.permissionx.guolindev.PermissionX

class MainActivity : AppCompatActivity() {

    private lateinit var binding: ActivityMainBinding

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

        requestStoragePermission()

        binding.buttonOpenAiChat.setOnClickListener {
            val engineId = "ai_chat_engine"
            FlutterEngineManager.createEngineWithRoute(this, engineId, "/model_setup")
            val intent = FlutterActivity.withCachedEngine(engineId)
                .build(this)
            intent.component = ComponentName(this, CustomFlutterActivity::class.java)
            startActivity(intent)
        }
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