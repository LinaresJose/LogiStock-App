import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  final supabase = Supabase.instance.client;
  // Este script es solo para verificar si el método existe en tiempo de compilación (análisis)
  try {
    await supabase.storage.from('test').uploadBinary('test.jpg', Uint8List(0));
    print('uploadBinary exists');
  } catch (e) {
    print('Error: $e');
  }
}
