package com.example.cooldemo

import android.Manifest
import android.content.SharedPreferences
import android.os.Build
import android.os.Bundle
import androidx.activity.viewModels
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.core.view.isVisible
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.repeatOnLifecycle
import androidx.recyclerview.widget.LinearLayoutManager
import com.example.cooldemo.ad.AdInfo
import com.example.cooldemo.ad.AdViewModel
import com.example.cooldemo.ad.ListItemAdapter
import com.example.cooldemo.ad.ListItemViewModel
import com.example.cooldemo.ad.fetchAd
import com.example.cooldemo.databinding.ActivityMainBinding
import com.example.cooldemo.webview.SafeWebViewActivity
import com.permissionx.guolindev.PermissionX
import kotlinx.coroutines.launch
import kotlin.random.Random

class MainActivity : AppCompatActivity() {

    private lateinit var binding: ActivityMainBinding
    private lateinit var userPrefs: SharedPreferences
    private val viewModel: MainViewModel by viewModels()
    private val adViewModel: AdViewModel by viewModels()
    private val listViewModel: ListItemViewModel by viewModels()
    private val listAdapter = ListItemAdapter()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

        userPrefs = getSharedPreferences("user_prefs", MODE_PRIVATE)

        requestStoragePermission()
        updateUserDisplay()
        setupList()

        binding.buttonOpenFeatures.setOnClickListener {
            startActivity(android.content.Intent(this, FeaturesActivity::class.java))
        }

        binding.buttonOpenBaidu.setOnClickListener {
            startActivity(
                SafeWebViewActivity.createIntent(
                    this,
                    "https://www.baidu.com",
                    "百度首页"
                )
            )
        }

        binding.buttonOpenLocalHtml.setOnClickListener {
            startActivity(
                SafeWebViewActivity.createAssetIntent(
                    this,
                    "webview/local_demo.html",
                    "本地 HTML"
                )
            )
        }

        binding.buttonUpdateUser.setOnClickListener {
            updateUserInfo()
        }

        binding.testModel.setOnClickListener {
            viewModel.increment()
        }

        lifecycleScope.launch {
            repeatOnLifecycle(Lifecycle.State.STARTED) {
                viewModel.count.collect { value ->
                    binding.testModelShow.text = value.toString()
                }
            }
        }

        lifecycleScope.launch {
            repeatOnLifecycle(Lifecycle.State.STARTED) {
                viewModel.toastEvent.collect { message ->
                    android.widget.Toast.makeText(this@MainActivity, message, android.widget.Toast.LENGTH_SHORT).show()
                }
            }
        }

        // 启动广告弹窗队列
//        startAdQueue()
    }

    /**
     * 标准 MVVM：RecyclerView + StateFlow 观察
     */
    private fun setupList() {
        binding.recyclerView.layoutManager = LinearLayoutManager(this)
        binding.recyclerView.adapter = listAdapter

        binding.buttonLoadList.setOnClickListener {
            listViewModel.loadList()
        }

        // ── 核心：collect StateFlow，UI 自动更新 ──
        lifecycleScope.launch {
            repeatOnLifecycle(Lifecycle.State.STARTED) {
                listViewModel.uiState.collect { state ->
                    binding.progressBar.isVisible = state.isLoading
                    binding.textError.isVisible = state.errorMessage != null
                    binding.textError.text = state.errorMessage ?: ""
                    binding.recyclerView.isVisible = state.items.isNotEmpty()
                    listAdapter.submitList(state.items)
                }
            }
        }
    }

    /**
     * 广告弹窗队列 — 逐个请求接口，第一个成功的就弹窗，后续不再请求
     */
    private fun startAdQueue() {
        fetchAd(adViewModel::fetchHomeActivityAd) {
            onSuccess = { ad -> showAdDialog(ad) }
            onError = { _, _ -> fetchAd2() }
            onFinished = { fetchAd2() }
        }
    }

    private fun fetchAd2() {
        fetchAd(adViewModel::fetchFlashSaleAd) {
            onSuccess = { ad -> showAdDialog(ad) }
            onError = { _, _ -> fetchAd3() }
            onFinished = { fetchAd3() }
        }
    }

    private fun fetchAd3() {
        fetchAd(adViewModel::fetchNewUserBonusAd) {
            onSuccess = { ad -> showAdDialog(ad) }
            onError = { _, _ -> toast("所有广告已展示完毕") }
            onFinished = { toast("所有广告已展示完毕") }
        }
    }

    private fun toast(msg: String) {
        android.widget.Toast.makeText(this, msg, android.widget.Toast.LENGTH_SHORT).show()
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

    /**
     * 展示广告弹窗，点击任意按钮都只是关闭弹窗
     */
    private fun showAdDialog(ad: AdInfo) {
        AlertDialog.Builder(this)
            .setTitle(ad.title)
            .setMessage(ad.content)
            .setCancelable(false)
            .setNegativeButton("关闭") { dialog, _ -> dialog.dismiss() }
            .setPositiveButton("确认") { dialog, _ -> dialog.dismiss() }
            .show()
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
