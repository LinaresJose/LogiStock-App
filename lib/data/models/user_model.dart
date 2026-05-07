import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/permissions.dart';

/// Modelo que representa un usuario del sistema (Auth via Supabase)
class UserModel {
  final String userId;
  final String nombre;
  final String email;
  final UserRole rol;
  final bool activo;
  final String fechaCreacion;
  final String creadoPorNombre;

  const UserModel({
    required this.userId,
    required this.nombre,
    required this.email,
    required this.rol,
    required this.activo,
    required this.fechaCreacion,
    required this.creadoPorNombre,
  });

  /// Crea un UserModel a partir de un objeto User de Supabase.
  factory UserModel.fromSupabase(User user) {
    final metadata = user.userMetadata ?? {};
    return UserModel(
      userId:          user.id,
      nombre:          metadata['nombre'] ?? 'Usuario',
      email:           user.email ?? '',
      rol:             UserRoleLabel.fromKey(metadata['rol'] ?? 'consulta'),
      activo:          metadata['activo'] ?? true,
      fechaCreacion:   user.createdAt,
      creadoPorNombre: metadata['creadoPorNombre'] ?? 'sistema',
    );
  }

  /// Crea un UserModel a partir de una fila de Google Sheets (Legacy).
  factory UserModel.fromRow(List<dynamic> row) {
    return UserModel(
      userId:          row.isNotEmpty      ? row[0].toString() : '',
      nombre:          row.length > 1      ? row[1].toString() : '',
      email:           row.length > 2      ? row[2].toString() : '',
      rol:             row.length > 4
          ? UserRoleLabel.fromKey(row[4].toString())
          : UserRole.consulta,
      activo:          row.length > 5
          ? row[5].toString().toUpperCase() == 'TRUE'
          : false,
      fechaCreacion:   row.length > 6      ? row[6].toString() : '',
      creadoPorNombre: row.length > 7      ? row[7].toString() : '',
    );
  }

  /// Serializa el modelo a lista para escribir en Google Sheets (Legacy).
  List<dynamic> toRow() {
    return [
      userId,
      nombre,
      email,
      '', // passwordHash vacío
      rol.key,
      activo ? 'TRUE' : 'FALSE',
      fechaCreacion,
      creadoPorNombre,
    ];
  }

  /// Crea una copia del modelo con campos modificados.
  UserModel copyWith({
    String?   userId,
    String?   nombre,
    String?   email,
    UserRole? rol,
    bool?     activo,
    String?   fechaCreacion,
    String?   creadoPorNombre,
  }) {
    return UserModel(
      userId:          userId          ?? this.userId,
      nombre:          nombre          ?? this.nombre,
      email:           email           ?? this.email,
      rol:             rol             ?? this.rol,
      activo:          activo          ?? this.activo,
      fechaCreacion:   fechaCreacion   ?? this.fechaCreacion,
      creadoPorNombre: creadoPorNombre ?? this.creadoPorNombre,
    );
  }
}
