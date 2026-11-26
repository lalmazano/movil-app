package com.igss.movil_app

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Instalador de actualizaciones: el APK lo descarga Dart desde Firestore.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "club.frijol/instalador")
            .setMethodCallHandler { llamada, resultado ->
                when (llamada.method) {
                    "puedeInstalar" -> resultado.success(puedeInstalar())
                    "abrirPermiso" -> {
                        abrirPermiso()
                        resultado.success(null)
                    }
                    "instalar" -> {
                        val ruta = llamada.argument<String>("ruta")
                        if (ruta == null) {
                            resultado.error("sin_ruta", "Falta la ruta del APK", null)
                        } else {
                            try {
                                instalar(File(ruta))
                                resultado.success(null)
                            } catch (e: Exception) {
                                resultado.error("instalar", e.message, null)
                            }
                        }
                    }
                    else -> resultado.notImplemented()
                }
            }
    }

    private fun puedeInstalar(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
            packageManager.canRequestPackageInstalls()

    private fun abrirPermiso() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startActivity(
                Intent(
                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    Uri.parse("package:$packageName"),
                ),
            )
        }
    }

    private fun instalar(apk: File) {
        val uri = FileProvider.getUriForFile(this, "$packageName.instalador", apk)
        val intento = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intento)
    }
}
