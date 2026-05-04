import '../../../core/permissions.dart';

/// Modelo que representa un usuario del sistema (hoja: Usuarios)
class UserModel {
  final String userId;
  final String nombre;
  final String email;
  final String passwordHash; // SHA-256, nunca texto plano
  final UserRole rol;
  final bool activo;
  final String fechaCreacion;
  final String creadoPor;

  const UserModel({
    required this.userId,
    required this.nombre,
    required this.email,
    required this.passwordHash,
    required this.rol,
    required this.activo,
    required this.fechaCreacion,
    required this.creadoPor,
  });

  /// Crea un UserModel a partir de una fila de Google Sheets.
  /// Columnas: A=userId, B=nombre, C=email, D=passwordHash,
  ///           E=rol, F=activo, G=fechaCreacion, H=creadoPor
  factory UserModel.fromRow(List<dynamic> row) {
    return UserModel(
      userId:        row.isNotEmpty      ? row[0].toString() : '',
      nombre:        row.length > 1      ? row[1].toString() : '',
      email:         row.length > 2      ? row[2].toString() : '',
      passwordHash:  row.length > 3      ? row[3].toString() : '',
      rol:           row.length > 4
          ? UserRoleLabel.fromKey(row[4].toString())
          : UserRole.consulta,
      activo:        row.length > 5
          ? row[5].toString().toUpperCase() == 'TRUE'
          : false,
      fechaCreacion: row.length > 6      ? row[6].toString() : '',
      creadoPor:     row.length > 7      ? row[7].toString() : '',
    );
  }

  /// Serializa el modelo a lista para escribir en Google Sheets.
  List<dynamic> toRow() {
    return [
      userId,
      nombre,
      email,
      passwordHash,
      rol.key,
      activo ? 'TRUE' : 'FALSE',
      fechaCreacion,
      creadoPor,
    ];
  }

  /// Crea una copia del modelo con campos modificados.
  UserModel copyWith({
    String?   userId,
    String?   nombre,
    String?   email,
    String?   passwordHash,
    UserRole? rol,
    bool?     activo,
    String?   fechaCreacion,
    String?   creadoPor,
  }) {
    return UserModel(
      userId:        userId        ?? this.userId,
      nombre:        nombre        ?? this.nombre,
      email:         email         ?? this.email,
      passwordHash:  passwordHash  ?? this.passwordHash,
      rol:           rol           ?? this.rol,
      activo:        activo        ?? this.activo,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      creadoPor:     creadoPor     ?? this.creadoPor,
    );
  }
}
