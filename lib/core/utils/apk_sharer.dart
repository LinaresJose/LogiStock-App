import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

class ApkSharer {
  static const _channel = MethodChannel('com.logistock/apk_path');

  /// Localiza el archivo APK de la app y abre el menú de compartir.
  static Future<void> shareApp() async {
    try {
      // 1. Obtener la ruta del APK original mediante MethodChannel
      final String? apkPath = await _channel.invokeMethod('getApkPath');
      
      if (apkPath == null || apkPath.isEmpty) {
        throw Exception("No se pudo localizar el archivo APK.");
      }

      final File originalApk = File(apkPath);
      if (!await originalApk.exists()) {
        throw Exception("El archivo APK no existe en la ruta proporcionada.");
      }

      // 2. Obtener información de la app para el nombre del archivo
      final packageInfo = await PackageInfo.fromPlatform();
      final String appName = packageInfo.appName.replaceAll(' ', '_');
      final String version = packageInfo.version;
      
      // 3. Copiar el APK a un directorio temporal para asegurar permisos de lectura
      // Algunos dispositivos restringen el acceso directo a /data/app/
      final Directory tempDir = await getTemporaryDirectory();
      final String newPath = '${tempDir.path}/$appName-v$version.apk';
      final File tempApk = await originalApk.copy(newPath);

      // 4. Compartir el archivo usando share_plus
      await Share.shareXFiles(
        [XFile(tempApk.path, mimeType: 'application/vnd.android.package-archive')],
        text: '¡Descarga la aplicación ${packageInfo.appName}!',
        subject: 'Compartir APK de ${packageInfo.appName}',
      );
      
    } catch (e) {
      print('Error al compartir APK: $e');
      rethrow;
    }
  }
}
