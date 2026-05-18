import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as p;

class SupabaseStorageApi {
  static final _supabase = Supabase.instance.client;
  static const String bucketName = 'product_images';

  /// Sube los bytes de una imagen a Supabase Storage y devuelve la URL pública.
  /// Auto-recuperación: Si falla por sesión de autenticación perdida, limpia y reintenta anónimamente.
  static Future<String> uploadProductImage({
    required Uint8List bytes, 
    required String fileName,
  }) async {
    try {
      return await _uploadProductImageInternal(bytes: bytes, fileName: fileName);
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      if (e is AuthException || 
          errStr.contains('authsessionmissingexception') || 
          errStr.contains('session missing') || 
          errStr.contains('session_missing') || 
          errStr.contains('session expired')) {
        // La sesión está corrupta o expiró. La limpiamos y reintentamos de forma anónima.
        try {
          await _supabase.auth.signOut();
        } catch (_) {}
        // Reintentar una vez con cliente limpio (anónimo)
        return await _uploadProductImageInternal(bytes: bytes, fileName: fileName);
      }
      rethrow;
    }
  }

  static Future<String> _uploadProductImageInternal({
    required Uint8List bytes, 
    required String fileName,
  }) async {
    try {
      final filePath = 'products/$fileName';

      // 1. Subir los bytes usando el método binario sugerido
      await _supabase.storage.from(bucketName).uploadBinary(
        filePath,
        bytes,
        fileOptions: FileOptions(
          upsert: true,
          contentType: _getContentType(fileName),
        ),
      );

      // 2. Obtener la URL pública
      final String publicUrl = _supabase.storage
          .from(bucketName)
          .getPublicUrl(filePath);

      // 3. Guardar/Actualizar la referencia en la tabla SQL 'product_images'
      await _supabase.from('product_images').upsert({
        'sku_id': p.basenameWithoutExtension(fileName),
        'image_url': publicUrl,
        'updated_at': DateTime.now().toIso8601String(),
      });

      return publicUrl;
    } on StorageException catch (e) {
      throw Exception('Error en el almacenamiento de Supabase: ${e.message}');
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('socket') || errStr.contains('connection') || errStr.contains('failed to host')) {
        throw Exception('Error de conexión: Verifica tu internet.');
      }
      if (errStr.contains('memory') || e is OutOfMemoryError) {
        throw Exception('Error de memoria: La imagen es demasiado grande.');
      }
      rethrow; // Propagar para que el catch superior maneje problemas de Auth
    }
  }

  static String _getContentType(String fileName) {
    final ext = p.extension(fileName).toLowerCase();
    switch (ext) {
      case '.jpg':
      case '.jpeg': return 'image/jpeg';
      case '.png':  return 'image/png';
      case '.gif':  return 'image/gif';
      default:      return 'application/octet-stream';
    }
  }

  /// Elimina la imagen de un producto de Storage y de la tabla SQL.
  /// Auto-recuperación en caso de error de sesión.
  static Future<void> deleteProductImage(String skuId) async {
    try {
      await _deleteProductImageInternal(skuId);
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      if (e is AuthException || 
          errStr.contains('authsessionmissingexception') || 
          errStr.contains('session missing') || 
          errStr.contains('session_missing') || 
          errStr.contains('session expired')) {
        try {
          await _supabase.auth.signOut();
        } catch (_) {}
        await _deleteProductImageInternal(skuId);
        return;
      }
      rethrow;
    }
  }

  static Future<void> _deleteProductImageInternal(String skuId) async {
    try {
      // 1. Obtener la ruta del archivo desde la base de datos antes de borrar la fila
      final response = await _supabase
          .from('product_images')
          .select('image_url')
          .eq('sku_id', skuId)
          .maybeSingle();

      if (response != null) {
        final imageUrl = response['image_url'] as String;
        // Extraer el nombre del archivo de la URL
        final fileName = imageUrl.split('/').last;
        final filePath = 'products/$fileName';

        // 2. Eliminar del Storage
        await _supabase.storage.from(bucketName).remove([filePath]);
      }

      // 3. Eliminar de la tabla SQL
      await _supabase.from('product_images').delete().eq('sku_id', skuId);
    } catch (e) {
      throw Exception('Error al eliminar imagen de Supabase: $e');
    }
  }

  /// Obtiene un mapa de SKU -> URL de imagen desde Supabase.
  /// Auto-recuperación en caso de error de sesión.
  static Future<Map<String, String>> getAllProductImages() async {
    try {
      return await _getAllProductImagesInternal();
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      if (e is AuthException || 
          errStr.contains('authsessionmissingexception') || 
          errStr.contains('session missing') || 
          errStr.contains('session_missing') || 
          errStr.contains('session expired')) {
        try {
          await _supabase.auth.signOut();
        } catch (_) {}
        return await _getAllProductImagesInternal();
      }
      return {};
    }
  }

  static Future<Map<String, String>> _getAllProductImagesInternal() async {
    try {
      final response = await _supabase.from('product_images').select('sku_id, image_url');
      final data = response as List<dynamic>;
      return {for (var item in data) item['sku_id']: item['image_url']};
    } catch (e) {
      return {};
    }
  }
}
