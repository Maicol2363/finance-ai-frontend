package com.nullcorvus.finance_ai

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var speech: LocalSpeechBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        speech = LocalSpeechBridge(this).also {
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "finance_ai/speech")
                .setMethodCallHandler(it)
            EventChannel(flutterEngine.dartExecutor.binaryMessenger, "finance_ai/speech/events")
                .setStreamHandler(it)
        }
    }

    override fun onPause() { speech?.pause(); super.onPause() }
    override fun onDestroy() { speech?.dispose(); speech = null; super.onDestroy() }
}
