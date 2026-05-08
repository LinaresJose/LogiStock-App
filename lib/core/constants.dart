class AppConstants {
  static const String spreadsheetId = '1j365hrxZIFwDGMRd7NNodtHHRTFqHkPUAVH3Yej6eb8';
  static const String categoriesRange  = 'Categorías!A2:B';
  static const String productsRange    = 'Productos!A2:G';       // Reducido a G (Imagen ahora en Supabase)
  static const String movementsRange   = 'Movimientos!A2:H';     // +columnas G: usuario_id, H: tiene_costo
  static const String usersRange       = 'Usuarios!A2:H';
  static const String costHistoryRange = 'Historial_Costos!A2:I';

  // Supabase Config
  static const String supabaseUrl = 'https://qclegocvwkisuqkxdhxo.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFjbGVnb2N2d2tpc3Vxa3hkaHhvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgxMTI4NDIsImV4cCI6MjA5MzY4ODg0Mn0.SnQuiGYby2YiXfI_SNcML8BZFO1a13CjoCAicii8dy4';
}
