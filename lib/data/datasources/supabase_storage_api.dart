import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as p;

class SupabaseStorageApi {
  static final _supabase = Supabase.instance.client;
  static const String bucketName = 'product_images';

  /// Sube los bytes de una imagen a Supabase Storage y devuelve la URL pública.
  static Future<String> uploadProductImage({
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
      throw Exception('Error al subir imagen: $e');
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
  static Future<void> deleteProductImage(String skuId) async {
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

  /// Obtiene un mapa de SKU -> URL de imagen desde Supabase
  static Future<Map<String, String>> getAllProductImages() async {
    try {
      final response = await _supabase.from('product_images').select('sku_id, image_url');
      final data = response as List<dynamic>;
      return {for (var item in data) item['sku_id']: item['image_url']};
    } catch (e) {
      return {};
    }
  }
}
