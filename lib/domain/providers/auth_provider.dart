import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/permissions.dart';
import '../models/user_model.dart';
import '../../data/datasources/auth_sheets_api.dart';

// ─── Provider de sesión activa ───────────────────────────────────────────────

/// Almacena el usuario autenticado actualmente. `null` = no autenticado.
final currentUserProvider = NotifierProvider<CurrentUserNotifier, UserModel?>(CurrentUserNotifier.new);

class CurrentUserNotifier extends Notifier<UserModel?> {
  @override
  UserModel? build() => null;
  void setUser(UserModel? user) => state = user;
}

/// Acceso directo a los permisos del usuario activo (nunca null — usa consulta como default).
final currentPermissionsProvider = Provider<RolePermissions>((ref) {
  final user = ref.watch(currentUserProvider);
  return RolePermissions(user?.rol ?? UserRole.consulta);
});

// ─── Provider de lista de usuarios ─────────────────────────

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
  Future<String?> login(String email, String password) async {
    try {
      if (email.trim().isEmpty || password.isEmpty) {
        return 'Ingresa tu email y contraseña';
      }

      final user = await AuthSheetsApi.login(email, password);
      if (user == null) {
        return 'Credenciales incorrectas o usuario inactivo';
      }

      // Si es el admin interno, guardar bandera para persistencia
      if (user.userId == '0') {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('internal_admin_logged_in', true);
      }

      _ref.read(currentUserProvider.notifier).setUser(user);
      return null; 
    } catch (e) {
      return e.toString();
    }
  }

  /// Cierra la sesión del usuario actual.
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('internal_admin_logged_in');
    
    await AuthSheetsApi.logout();
    _ref.read(currentUserProvider.notifier).setUser(null);
  }

  /// Intenta restaurar la sesión guardada al iniciar la app.
  Future<bool> tryRestoreSession() async {
    // 1. Verificar si era el admin interno
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('internal_admin_logged_in') ?? false) {
      final user = await AuthSheetsApi.login('admin', 'admin');
      if (user != null) {
        _ref.read(currentUserProvider.notifier).setUser(user);
        return true;
      }
    }

    // 2. Si no, verificar Supabase
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null && session.user != null) {
      final user = UserModel.fromSupabase(session.user!);
      _ref.read(currentUserProvider.notifier).setUser(user);
      return true;
    }
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
      nombre:          nombre,
      email:           email,
      password:        password,
      rol:             rol,
      creadoPorNombre: currentUser?.nombre ?? 'Sistema',
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
