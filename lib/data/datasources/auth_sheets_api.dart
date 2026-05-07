import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/permissions.dart';
import '../models/user_model.dart';

/// Datasource para gestión de usuarios vía Supabase Auth.
class AuthSheetsApi {
  static final _supabase = Supabase.instance.client;

  // ─── Autenticación ──────────────────────────────────────────────────────────

  /// Inicia sesión con email y contraseña en Supabase.
  /// Incluye un Super Admin interno (admin/admin).
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
      final response = await _supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      
      if (response.user != null) {
        return UserModel.fromSupabase(response.user!);
      }
    } catch (e) {
      rethrow;
    }
    return null;
  }

  /// Cierra la sesión en Supabase.
  static Future<void> logout() async {
    await _supabase.auth.signOut();
  }

  // ─── CRUD Usuarios ──────────────────────────────────────────────────────────

  /// Obtiene la lista de usuarios. 
  /// NOTA: Supabase no permite listar todos los usuarios desde el cliente por seguridad.
  /// Para esto se suele usar una tabla 'profiles' sincronizada o una Edge Function.
  /// Como solución temporal, devolveremos una lista vacía o el usuario actual.
  static Future<List<UserModel>> getUsers() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      return [UserModel.fromSupabase(user)];
    }
    return [];
  }

  /// Crea un nuevo usuario en Supabase Auth.
  /// Requiere que el registro de usuarios esté habilitado o usar service_role.
  static Future<void> createUser({
    required String nombre,
    required String email,
    required String password,
    required UserRole rol,
    required String creadoPorNombre,
  }) async {
    try {
      // Usamos signUp para crear el usuario y guardar metadata
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

  /// Actualiza la metadata del usuario.
  static Future<void> updateUser(UserModel user) async {
    try {
      await _supabase.auth.updateUser(
        UserAttributes(
          data: {
            'nombre': user.nombre,
            'rol': user.rol.key,
            'activo': user.activo,
          },
        ),
      );
    } catch (e) {
      rethrow;
    }
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

  /// Toggle de activo/inactivo (vía metadata).
  static Future<void> toggleUserActive(UserModel user) async {
    final updated = user.copyWith(activo: !user.activo);
    await updateUser(updated);
  }
}
