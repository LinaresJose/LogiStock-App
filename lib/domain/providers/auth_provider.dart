import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/permissions.dart';
import '../../data/models/user_model.dart';
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

      final prefs = await SharedPreferences.getInstance();
      if (user.userId == '0') {
        await prefs.setBool('internal_admin_logged_in', true);
      } else {
        // Guardar email para persistencia local de la sesión sin Supabase
        await prefs.setString('saved_user_email', user.email);
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
    await prefs.remove('saved_user_email');
    
    await AuthSheetsApi.logout();
    _ref.read(currentUserProvider.notifier).setUser(null);
  }

  /// Intenta restaurar la sesión guardada al iniciar la app.
  Future<bool> tryRestoreSession() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Verificar si era el admin interno
    if (prefs.getBool('internal_admin_logged_in') ?? false) {
      final user = await AuthSheetsApi.login('admin', 'admin');
      if (user != null) {
        _ref.read(currentUserProvider.notifier).setUser(user);
        return true;
      }
    }

    // 2. Verificar si hay un usuario guardado por email
    final savedEmail = prefs.getString('saved_user_email');
    if (savedEmail != null && savedEmail.isNotEmpty) {
      try {
        final users = await AuthSheetsApi.getUsers();
        final user = users.firstWhere(
          (u) => u.email.trim().toLowerCase() == savedEmail.trim().toLowerCase(),
        );
        if (user.activo) {
          _ref.read(currentUserProvider.notifier).setUser(user);
          return true;
        } else {
          await prefs.remove('saved_user_email');
        }
      } catch (_) {
        await prefs.remove('saved_user_email');
      }
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
