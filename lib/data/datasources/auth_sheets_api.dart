import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis_auth/auth_io.dart';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants.dart';
import '../../core/permissions.dart';
import '../models/user_model.dart';

/// Datasource para gestión completa de usuarios y autenticación 100% vía Google Sheets.
class AuthSheetsApi {
  static sheets.SheetsApi? _sheetsApi;

  // ─── Inicialización de Google Sheets API ──────────────────────────────────────

  static Future<sheets.SheetsApi> _getSheetsApi() async {
    if (_sheetsApi != null) return _sheetsApi!;
    final credentialsJson = await rootBundle.loadString('assets/credentials.json');
    final credentials = ServiceAccountCredentials.fromJson(json.decode(credentialsJson));
    final scopes = [sheets.SheetsApi.spreadsheetsScope];
    final client = await clientViaServiceAccount(credentials, scopes);
    _sheetsApi = sheets.SheetsApi(client);
    return _sheetsApi!;
  }

  // ─── Auxiliares de Criptografía e IDs ──────────────────────────────────────────

  /// Genera un hash SHA-256 de una contraseña.
  static String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // ─── Auxiliares para Google Sheets ───────────────────────────────────────────

  /// Encuentra la fila del usuario en la hoja de cálculo por su userId (columna A).
  static Future<int> _findUserRowIndex(String userId) async {
    final sheetsApi = await _getSheetsApi();
    final response = await sheetsApi.spreadsheets.values.get(
      AppConstants.spreadsheetId,
      AppConstants.usersRange,
    );
    final rows = response.values ?? [];
    for (int i = 0; i < rows.length; i++) {
      if (rows[i].isNotEmpty && rows[i][0].toString() == userId) {
        return i + 2; // +2 porque el rango empieza en A2 (índice 0 = fila 2)
      }
    }
    return -1;
  }

  /// Registra una nueva fila de usuario en la hoja de cálculo.
  static Future<void> appendUserToSheets(UserModel user, {String? password}) async {
    final sheetsApi = await _getSheetsApi();
    final valueRange = sheets.ValueRange(values: [user.toRow(password: password)]);
    await sheetsApi.spreadsheets.values.append(
      valueRange,
      AppConstants.spreadsheetId,
      AppConstants.usersRange,
      valueInputOption: 'USER_ENTERED',
    );
  }

  // ─── Autenticación ──────────────────────────────────────────────────────────

  /// Inicia sesión con email y contraseña.
  /// Valida las credenciales comparándolas contra la pestaña "Usuarios" en Google Sheets (soporta texto plano y hash).
  static Future<UserModel?> login(String email, String password) async {
    // ── Super Admin Interno (Bypass Offline) ───────────────────────────────────
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
      final sheetsApi = await _getSheetsApi();
      final response = await sheetsApi.spreadsheets.values.get(
        AppConstants.spreadsheetId,
        AppConstants.usersRange,
      );
      final rows = response.values ?? [];

      for (var row in rows) {
        if (row.length > 2 && row[2].toString().trim().toLowerCase() == email.trim().toLowerCase()) {
          final storedPassword = row.length > 3 ? row[3].toString() : '';
          final typedHash = hashPassword(password);

          // Soporta tanto contraseñas en texto plano como hashes SHA-256 para máxima facilidad en edición manual
          final isMatch = (storedPassword == password) || (storedPassword == typedHash);

          if (isMatch) {
            final userModel = UserModel.fromRow(row);
            
            if (!userModel.activo) {
              throw Exception('Tu cuenta está desactivada. Contacta al administrador.');
            }
            return userModel;
          }
        }
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  /// Cierra la sesión activa.
  static Future<void> logout() async {
    // No requiere Supabase Auth
  }

  // ─── CRUD de Usuarios (vía Google Sheets) ───────────────────────────────────

  /// Obtiene la lista completa de usuarios desde la hoja de Google Sheets.
  static Future<List<UserModel>> getUsers() async {
    try {
      final sheetsApi = await _getSheetsApi();
      final response = await sheetsApi.spreadsheets.values.get(
        AppConstants.spreadsheetId,
        AppConstants.usersRange,
      );
      final rows = response.values ?? [];
      return rows
          .where((row) => row.isNotEmpty && row[0].toString().trim().isNotEmpty)
          .map((row) => UserModel.fromRow(row))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Registra un nuevo usuario en la hoja de cálculo.
  static Future<void> createUser({
    required String nombre,
    required String email,
    required String password,
    required UserRole rol,
    required String creadoPorNombre,
  }) async {
    try {
      // 1. Generar un nuevo UUID localmente
      final String newUserId = const Uuid().v4();

      // 2. Guardar el perfil en Google Sheets con contraseña hasheada
      final newUser = UserModel(
        userId:          newUserId,
        nombre:          nombre,
        email:           email.trim(),
        rol:             rol,
        activo:          true,
        fechaCreacion:   DateTime.now().toIso8601String(),
        creadoPorNombre: creadoPorNombre,
      );
      await appendUserToSheets(newUser, password: hashPassword(password));
    } catch (e) {
      rethrow;
    }
  }

  /// Actualiza los datos de un usuario en Google Sheets, preservando su contraseña actual.
  static Future<void> updateUser(UserModel user) async {
    try {
      final sheetsApi = await _getSheetsApi();

      // 1. Encontrar la fila del usuario y obtener su contraseña actual para preservarla
      final response = await sheetsApi.spreadsheets.values.get(
        AppConstants.spreadsheetId,
        AppConstants.usersRange,
      );
      final rows = response.values ?? [];

      int rowIndex = -1;
      String existingPassword = '';

      for (int i = 0; i < rows.length; i++) {
        if (rows[i].isNotEmpty && rows[i][0].toString() == user.userId) {
          rowIndex = i + 2; // +2 porque el rango empieza en A2 (índice 0 = fila 2)
          existingPassword = rows[i].length > 3 ? rows[i][3].toString() : '';
          break;
        }
      }

      if (rowIndex == -1) {
        await appendUserToSheets(user);
        return;
      }

      // 2. Actualizar conservando la contraseña actual
      final valueRange = sheets.ValueRange(values: [user.toRow(password: existingPassword)]);
      await sheetsApi.spreadsheets.values.update(
        valueRange,
        AppConstants.spreadsheetId,
        'Usuarios!A$rowIndex:H$rowIndex',
        valueInputOption: 'USER_ENTERED',
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Cambia el estado Activo/Inactivo de un usuario en Google Sheets.
  static Future<void> toggleUserActive(UserModel user) async {
    final updated = user.copyWith(activo: !user.activo);
    await updateUser(updated);
  }

  /// Cambia la contraseña de un usuario directamente en Google Sheets.
  static Future<void> changePassword({
    required UserModel user,
    required String newPassword,
  }) async {
    try {
      final sheetsApi = await _getSheetsApi();
      final rowIndex = await _findUserRowIndex(user.userId);
      if (rowIndex == -1) throw Exception('Usuario no encontrado');

      final hashed = hashPassword(newPassword);
      final valueRange = sheets.ValueRange(values: [[hashed]]);
      await sheetsApi.spreadsheets.values.update(
        valueRange,
        AppConstants.spreadsheetId,
        'Usuarios!D$rowIndex:D$rowIndex', // Columna D (Contraseña)
        valueInputOption: 'USER_ENTERED',
      );
    } catch (e) {
      rethrow;
    }
  }
}
