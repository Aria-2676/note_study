package com.noteapp.taskmaster

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "flutter.native/helper"
    private var intentExtras: Map<String, Any>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // 保存 intent extras
        intent?.extras?.let { extras ->
            val map = mutableMapOf<String, Any>()
            if (extras.containsKey("refresh_widget")) {
                map["refresh_widget"] = extras.getBoolean("refresh_widget")
            }
            intentExtras = map
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getIntentExtras" -> {
                    result.success(intentExtras)
                    // 获取后清空，避免重复刷新
                    intentExtras = null
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // 处理新的 intent
        intent.extras?.let { extras ->
            val map = mutableMapOf<String, Any>()
            if (extras.containsKey("refresh_widget")) {
                map["refresh_widget"] = extras.getBoolean("refresh_widget")
            }
            intentExtras = map
        }
    }
}