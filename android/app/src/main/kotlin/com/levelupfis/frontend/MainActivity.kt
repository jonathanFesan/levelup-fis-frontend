package com.levelupfis.frontend

import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Canal nativo mínimo pra ligar/desligar FLAG_SECURE (bloqueia
 * screenshot e gravação de tela de verdade) enquanto a tela de Resumo
 * (PDF) estiver aberta — ver resumo_screen.dart no lado Flutter.
 *
 * Implementado direto aqui, sem depender de pacote de terceiro
 * (flutter_windowmanager foi removido: estava abandonado desde 2021,
 * usava jcenter() — que não existe mais — e quebrava o build com
 * versões novas do Android Gradle Plugin). FLAG_SECURE é uma API
 * simples do Android, não precisa de plugin nenhum pra isso.
 */
class MainActivity : FlutterActivity() {
    private val CHANNEL = "levelup_fis/screen_security"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "enableSecure" -> {
                    window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    result.success(null)
                }
                "disableSecure" -> {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
