import 'package:supabase_flutter/supabase_flutter.dart';

/// Script de utilidad para verificar la conexión y visibilidad de los buckets.
Future<void> debugSupabaseBuckets() async {
  final supabase = Supabase.instance.client;
  
  try {
    print('--- Iniciando Debug de Buckets ---');
    
    // 1. Intentar listar todos los buckets
    final List<Bucket> buckets = await supabase.storage.listBuckets();
    
    if (buckets.isEmpty) {
      print('AVISO: No se encontraron buckets. ¿Ya creaste alguno en la consola?');
    } else {
      print('Buckets encontrados (${buckets.length}):');
      for (var b in buckets) {
        print('- ID: ${b.id} | Público: ${b.public}');
      }
    }
    
    // 2. Verificar específicamente el bucket 'product_images'
    final exists = buckets.any((b) => b.id == 'product_images');
    if (exists) {
      print('ÉXITO: El bucket "product_images" es visible para el cliente.');
    } else {
      print('ERROR: El bucket "product_images" NO existe o no tienes permisos para verlo.');
    }
    
    print('--- Fin del Debug ---');
  } catch (e) {
    print('ERROR CRÍTICO al conectar con Supabase Storage: $e');
  }
}
