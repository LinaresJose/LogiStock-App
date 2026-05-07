class AppConstants {
  static const String spreadsheetId = '1j365hrxZIFwDGMRd7NNodtHHRTFqHkPUAVH3Yej6eb8';
  static const String categoriesRange  = 'Categorías!A2:B';
  static const String productsRange    = 'Productos!A2:H';       // +columna H: costo_promedio
  static const String movementsRange   = 'Movimientos!A2:H';     // +columnas G: usuario_id, H: tiene_costo
  static const String usersRange       = 'Usuarios!A2:H';
  static const String costHistoryRange = 'Historial_Costos!A2:I';

  // Supabase Config
  static const String supabaseUrl = 'https://qclegocvwkisuqkxdhxo.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_4UH2al80_kHf8wAZze66PA_ncu0Kcib';
}
