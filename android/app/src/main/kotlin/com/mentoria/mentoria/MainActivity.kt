package com.mentoria.mentoria

import android.content.Context
import android.media.AudioManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Uygulama sesleri medya yolundan çalar (kulaklık takılıysa yalnızca
        // kulaklıktan); telefon sessiz / titreşimdeyse çalmamak için zil
        // modu buradan okunur (bkz. lib/core/sound/app_sounds.dart).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mentoria/sound")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isSilent" -> {
                        val audio = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                        result.success(audio.ringerMode != AudioManager.RINGER_MODE_NORMAL)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
