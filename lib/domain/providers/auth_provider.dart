import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/permissions.dart';
import '../../data/datasources/auth_sheets_api.dart';
import '../../data/models/user_model.dart';

// ─── Provider de sesión activa ───────────────────────────────────────────────

/// Almacena el usuario autenticado actualmente. `null` = no autenticado.
final currentUserProvider = StateProvider<UserModel?>((ref) => null);

/// Acceso directo a los permisos del usuario activo (nunca null — usa consulta como default).
final currentPermissionsProvider = Provider<RolePermissions>((ref) {
  final user = ref.watch(currentUserProvider);
  return RolePermissions(user?.rol ?? UserRole.consulta);
});

// ─── Provider de lista de usuarios (solo superAdmin) ─────────────────────────

final usersListProvider = FutureProvider<List<UserModel>>((ref) async {
  return await AuthSheetsApi.getUsers();
});

// ─── Controlador de autenticación ────────────────────────────────────────────

final authControllerProvider = Provider<AuthController>((ref) {
  return AuthController(ref);
});

class AuthController {
  final Ref _ref;

  AuthController(this._ref);

  // ── Login / Logout ──────────────────────────────────────────────────────────

  /// Intenta autenticar al usuario con email y contraseña.
  /// Devuelve `null` si las credenciales son correctas, o un mensaje de error.
  Future<String?> login(String email, String password) async {
    if (email.trim().isEmpty || password.isEmpty) {
      return 'Ingresa tu email y contraseña';
    }

    final user = await AuthSheetsApi.login(email, password);
    if (user == null) {
      return 'Credenciales incorrectas o usuario inactivo';
    }

    // Guardar sesión en SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('session_user_id', user.userId);
    await prefs.setString('session_email', user.email);

    _ref.read(currentUserProvider.notifier).state = user;
    return null; // Sin error = éxito
  }

  /// Cierra la sesión del usuario actual.
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session_user_id');
    await prefs.remove('session_email');
    _ref.read(currentUserProvider.notifier).state = null;
  }

  /// Intenta restaurar la sesión guardada en SharedPreferences al iniciar la app.
  /// Devuelve `true` si se restauró correctamente.
  Future<bool> tryRestoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs.getString('session_email');
      if (savedEmail == null) return false;

      // Buscamos al usuario sin reverificar contraseña (ya fue verificada)
      final users = await AuthSheetsApi.getUsers();
      final user = users.where((u) =>
          u.email.toLowerCase() == savedEmail.toLowerCase() && u.activo
      ).firstOrNull;

      if (user != null) {
        _ref.read(currentUserProvider.notifier).state = user;
        return true;
      }
    } catch (_) {}
    return false;
  }

  // ── CRUD Usuarios ────────────────────────────────────────────────────────────

  Future<void> createUser({
    required String nombre,
    required String email,
    required String password,
    required UserRole rol,
  }) async {
    final currentUser = _ref.read(currentUserProvider);
    await AuthSheetsApi.createUser(
      nombre:    nombre,
      email:     email,
      password:  password,
      rol:       rol,
      creadoPor: currentUser?.userId ?? 'sistema',
    );
    _ref.invalidate(usersListProvider);
  }

  Future<void> updateUser(UserModel user) async {
    await AuthSheetsApi.updateUser(user);
    _ref.invalidate(usersListProvider);
  }

  Future<void> changePassword({
    required UserModel user,
    required String newPassword,
  }) async {
    await AuthSheetsApi.changePassword(user: user, newPassword: newPassword);
    _ref.invalidate(usersListProvider);
  }

  Future<void> toggleUserActive(UserModel user) async {
    await AuthSheetsApi.toggleUserActive(user);
    _ref.invalidate(usersListProvider);
  }
}
