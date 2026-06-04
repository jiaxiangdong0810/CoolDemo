package com.example.cooldemo

import android.content.Context
import android.content.Intent
import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import com.example.cooldemo.databinding.ActivityNativeHopBinding

class NativeHopActivity : AppCompatActivity() {

    companion object {
        private const val EXTRA_TITLE = "extra_title"
        private const val EXTRA_CHAIN = "extra_chain"

        fun createIntent(context: Context, title: String, chain: String): Intent {
            return Intent(context, NativeHopActivity::class.java).apply {
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_CHAIN, chain)
            }
        }
    }

    private lateinit var binding: ActivityNativeHopBinding

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityNativeHopBinding.inflate(layoutInflater)
        setContentView(binding.root)

        val title = intent.getStringExtra(EXTRA_TITLE) ?: "原生页面"
        val chain = intent.getStringExtra(EXTRA_CHAIN) ?: "Flutter -> 原生"

        binding.textTitle.text = title
        binding.textChain.text = chain
        binding.buttonBack.setOnClickListener {
            finish()
        }
        binding.buttonOpenFlutter.setOnClickListener {
            startActivity(
                FlutterHybrid.open(
                    this,
                    FlowConfig(
                        flowId = "nav_case_native_to_flutter",
                        initialRoute = "/nav_case_native_to_flutter"
                    )
                )
            )
        }
    }
}
