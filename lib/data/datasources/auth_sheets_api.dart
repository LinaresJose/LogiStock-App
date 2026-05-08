import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/permissions.dart';
import '../models/user_model.dart';

/// Datasource para gestión de usuarios vía Supabase Auth y tabla 'profiles'.
class AuthSheetsApi {
  static final _supabase = Supabase.instance.client;

  // ─── Autenticación ──────────────────────────────────────────────────────────

  /// Inicia sesión con email y contraseña. 
  /// Verifica el estado 'activo' en la tabla profiles.
  static Future<UserModel?> login(String email, String password) async {
    // ── Super Admin Interno ──────────────────────────────────────────────────
    if (email.trim().toLowerCase() == 'admin' && password == 'admin') {
      return const UserModel(
        userId:          '0',
        nombre:          'Super Administrador',
        email:           'admin@logistock.internal',
        rol:             UserRole.superAdmin,
        activo:          true,
        fechaCreacion:   '2026-05-06',
        creadoPorNombre: 'Sistema',
      );
    }

    try {
      // 1. Autenticar en Supabase Auth
      final authResponse = await _supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      
      if (authResponse.user == null) return null;

      // 2. Verificar estado en la tabla 'profiles'
      final profileResponse = await _supabase
          .from('profiles')
          .select()
          .eq('id', authResponse.user!.id)
          .maybeSingle();

      if (profileResponse == null) {
        // Si no hay perfil, creamos uno básico o usamos metadata
        return UserModel.fromSupabase(authResponse.user!);
      }

      final userModel = UserModel.fromMap(profileResponse);
      
      if (!userModel.activo) {
        await logout();
        throw Exception('Tu cuenta está desactivada. Contacta al administrador.');
      }

      return userModel;
    } catch (e) {
      rethrow;
    }
  }

  /// Cierra la sesión.
  static Future<void> logout() async {
    await _supabase.auth.signOut();
  }

  // ─── CRUD Usuarios (vía tabla profiles) ─────────────────────────────────────

  /// Obtiene la lista de usuarios desde la tabla profiles.
  static Future<List<UserModel>> getUsers() async {
    try {
      final response = await _supabase.from('profiles').select().order('nombre');
      final list = response as List<dynamic>;
      return list.map((m) => UserModel.fromMap(m)).toList();
    } catch (e) {
      // Si falla (ej: tabla no creada), devolvemos el usuario actual como fallback
      final user = _supabase.auth.currentUser;
      if (user != null) return [UserModel.fromSupabase(user)];
      return [];
    }
  }

  /// Crea un nuevo usuario.
  static Future<void> createUser({
    required String nombre,
    required String email,
    required String password,
    required UserRole rol,
    required String creadoPorNombre,
  }) async {
    try {
      // Al registrarse, el Trigger en SQL se encargará de crear la fila en 'profiles'
      await _supabase.auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'nombre': nombre,
          'rol': rol.key,
          'activo': true,
          'creadoPorNombre': creadoPorNombre,
        },
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Actualiza los datos de un usuario en la tabla profiles.
  static Future<void> updateUser(UserModel user) async {
    try {
      await _supabase.from('profiles').update({
        'nombre': user.nombre,
        'rol': user.rol.key,
        'activo': user.activo,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', user.userId);
    } catch (e) {
      rethrow;
    }
  }

  /// Toggle de activo/inactivo.
  static Future<void> toggleUserActive(UserModel user) async {
    final updated = user.copyWith(activo: !user.activo);
    await updateUser(updated);
  }

  /// Cambia la contraseña del usuario actual.
  static Future<void> changePassword({
    required UserModel user,
    required String newPassword,
  }) async {
    await _supabase.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }
}
