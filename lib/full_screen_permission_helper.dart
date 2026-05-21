import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class FullScreenPermissionHelper {
  static Future<void> abrirConfiguracionPermiso() async {
    try {
      final pkgInfo = await PackageInfo.fromPlatform();
      final AndroidIntent intent = AndroidIntent(
        action: 'android.settings.MANAGE_APP_USE_FULL_SCREEN_INTENT',
        data: 'package:${pkgInfo.packageName}',
      );

      await intent.launch();
    } catch (e) {
      debugPrint("No se pudo abrir la configuración: $e");
    }
  }
}
