package com.example.cooldemo

import android.Manifest
import android.content.ComponentName
import android.content.Intent
import android.os.Build
import android.os.Bundle
import androidx.fragment.app.Fragment
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import com.example.cooldemo.databinding.FragmentFirstBinding
import com.permissionx.guolindev.PermissionX
import io.flutter.embedding.android.FlutterActivity

class FirstFragment : Fragment() {

    private var _binding: FragmentFirstBinding? = null
    private val binding get() = _binding!!

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentFirstBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        requestStoragePermission()

        binding.buttonOpenFlutter.setOnClickListener {
            val intent = FlutterActivity.withCachedEngine(FlutterEngineManager.getDefaultEngineId())
                .build(requireContext())
            intent.component = ComponentName(requireContext(), CustomFlutterActivity::class.java)
            startActivity(intent)
        }

        binding.buttonOpenAiChat.setOnClickListener {
            val intent = FlutterActivity.withCachedEngine(FlutterEngineManager.getDefaultEngineId())
                .build(requireContext())
            intent.component = ComponentName(requireContext(), CustomFlutterActivity::class.java)
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

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}
