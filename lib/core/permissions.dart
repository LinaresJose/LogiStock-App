/// Sistema de Roles y Permisos (RBAC)
enum UserRole {
  superAdmin, // Acceso total
  admin,      // Todo excepto gestión de usuarios
  operativo,  // Solo registrar movimientos
  consulta,   // Solo lectura
}

/// Extensión con etiqueta legible para UI
extension UserRoleLabel on UserRole {
  String get label {
    switch (this) {
      case UserRole.superAdmin:
        return 'Super Admin';
      case UserRole.admin:
        return 'Administrador';
      case UserRole.operativo:
        return 'Operativo (Movimientos)';
      case UserRole.consulta:
        return 'Consulta (Solo Lectura)';
    }
  }

  String get key {
    switch (this) {
      case UserRole.superAdmin:
        return 'super_admin';
      case UserRole.admin:
        return 'admin';
      case UserRole.operativo:
        return 'operativo';
      case UserRole.consulta:
        return 'consulta';
    }
  }

  static UserRole fromKey(String key) {
    switch (key) {
      case 'super_admin':
        return UserRole.superAdmin;
      case 'admin':
        return UserRole.admin;
      case 'operativo':
        return UserRole.operativo;
      case 'consulta':
        return UserRole.consulta;
      default:
        return UserRole.consulta;
    }
  }
}

/// Clase que centraliza la lógica de permisos por rol.
/// Uso: `RolePermissions(role).canRegisterMovements`
class RolePermissions {
  final UserRole role;

  const RolePermissions(this.role);

  // --- Inventario ---
  /// Puede ver el inventario, productos y movimientos
  bool get canViewInventory => true; // Todos los roles

  /// Puede registrar entradas y salidas de mercancía
  bool get canRegisterMovements =>
      role == UserRole.superAdmin ||
      role == UserRole.admin ||
      role == UserRole.operativo;

  // --- Productos y Categorías ---
  /// Puede crear, editar y eliminar productos
  bool get canManageProducts =>
      role == UserRole.superAdmin || role == UserRole.admin;

  /// Puede crear, editar y eliminar categorías
  bool get canManageCategories =>
      role == UserRole.superAdmin || role == UserRole.admin;

  // --- Costos ---
  /// Puede ver el historial de costos y reportes financieros
  bool get canViewCosts =>
      role == UserRole.superAdmin || role == UserRole.admin;

  /// Puede registrar costos de compra en entradas de stock
  bool get canRegisterCosts =>
      role == UserRole.superAdmin || role == UserRole.admin;

  // --- Usuarios ---
  /// Puede ver, crear, editar y eliminar usuarios del sistema
  bool get canManageUsers => role == UserRole.superAdmin;

  // --- Eliminación ---
  /// Puede eliminar registros permanentemente
  bool get canDeleteRecords =>
      role == UserRole.superAdmin || role == UserRole.admin;
}
