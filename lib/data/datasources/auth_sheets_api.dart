import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis_auth/auth_io.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../core/permissions.dart';
import '../models/user_model.dart';

/// Datasource para gestión de usuarios en la hoja "Usuarios".
/// El hash de contraseñas se genera con SHA-256 en el cliente.
class AuthSheetsApi {
  static sheets.SheetsApi? _sheetsApi;

  static Future<void> _init() async {
    if (_sheetsApi != null) return;
    final credentialsJson =
        await rootBundle.loadString('assets/credentials.json');
    final credentials =
        ServiceAccountCredentials.fromJson(json.decode(credentialsJson));
    final client = await clientViaServiceAccount(
        credentials, [sheets.SheetsApi.spreadsheetsScope]);
    _sheetsApi = sheets.SheetsApi(client);
  }

  // ─── Hashing ────────────────────────────────────────────────────────────────

  /// Genera el hash SHA-256 de una contraseña en texto plano.
  static String hashPassword(String plainText) {
    final bytes = utf8.encode(plainText);
    return sha256.convert(bytes).toString();
  }

  // ─── Autenticación ──────────────────────────────────────────────────────────

  /// Busca un usuario por email y verifica la contraseña.
  /// Devuelve [UserModel] si las credenciales son válidas, o `null` si no.
  static Future<UserModel?> login(String email, String password) async {
    await _init();
    final hash = hashPassword(password);

    final response = await _sheetsApi!.spreadsheets.values.get(
      AppConstants.spreadsheetId,
      AppConstants.usersRange,
    );

    final rows = response.values ?? [];
    for (final row in rows) {
      if (row.length < 6) continue;
      final rowEmail = row[2].toString().trim().toLowerCase();
      final rowHash  = row[3].toString().trim();
      final rowActivo = row[5].toString().toUpperCase() == 'TRUE';

      if (rowEmail == email.trim().toLowerCase() &&
          rowHash == hash &&
          rowActivo) {
        return UserModel.fromRow(row);
      }
    }
    return null;
  }

  // ─── CRUD Usuarios ──────────────────────────────────────────────────────────

  static Future<List<UserModel>> getUsers() async {
    await _init();
    final response = await _sheetsApi!.spreadsheets.values.get(
      AppConstants.spreadsheetId,
      AppConstants.usersRange,
    );
    final rows = response.values ?? [];
    return rows
        .where((row) => row.isNotEmpty && row[0].toString().trim().isNotEmpty)
        .map((row) => UserModel.fromRow(row))
        .toList();
  }

  static Future<void> createUser({
    required String nombre,
    required String email,
    required String password,
    required UserRole rol,
    required String creadoPor,
  }) async {
    await _init();
    final user = UserModel(
      userId:        'USR-${const Uuid().v4().substring(0, 8).toUpperCase()}',
      nombre:        nombre,
      email:         email,
      passwordHash:  hashPassword(password),
      rol:           rol,
      activo:        true,
      fechaCreacion: DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
      creadoPor:     creadoPor,
    );

    final valueRange = sheets.ValueRange(values: [user.toRow()]);
    await _sheetsApi!.spreadsheets.values.append(
      valueRange,
      AppConstants.spreadsheetId,
      AppConstants.usersRange,
      valueInputOption: 'USER_ENTERED',
    );
  }

  static Future<void> updateUser(UserModel user) async {
    await _init();
    final rowIndex = await _findUserRowIndex(user.userId);
    if (rowIndex == -1) throw Exception('Usuario no encontrado');

    final valueRange = sheets.ValueRange(values: [user.toRow()]);
    await _sheetsApi!.spreadsheets.values.update(
      valueRange,
      AppConstants.spreadsheetId,
      'Usuarios!A$rowIndex:H$rowIndex',
      valueInputOption: 'USER_ENTERED',
    );
  }

  /// Cambia la contraseña de un usuario (genera nuevo hash).
  static Future<void> changePassword({
    required UserModel user,
    required String newPassword,
  }) async {
    final updated = user.copyWith(passwordHash: hashPassword(newPassword));
    await updateUser(updated);
  }

  static Future<void> toggleUserActive(UserModel user) async {
    final updated = user.copyWith(activo: !user.activo);
    await updateUser(updated);
  }

  static Future<int> _findUserRowIndex(String userId) async {
    final response = await _sheetsApi!.spreadsheets.values.get(
      AppConstants.spreadsheetId,
      AppConstants.usersRange,
    );
    final rows = response.values ?? [];
    for (int i = 0; i < rows.length; i++) {
      if (rows[i].isNotEmpty && rows[i][0].toString() == userId) {
        return i + 2; // +2 porque la fila 1 es el encabezado
      }
    }
    return -1;
  }
}
