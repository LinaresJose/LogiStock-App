import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis_auth/auth_io.dart';

import '../../core/constants.dart';
import '../models/cost_entry_model.dart';
import '../models/product.dart';

/// Datasource para el historial de costos (hoja: Historial_Costos).
class CostsSheetsApi {
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

  // ── Auxiliares ──────────────────────────────────────────────────────────────

  static Future<String> _getNextId(String range) async {
    await _init();
    final response = await _sheetsApi!.spreadsheets.values.get(
      AppConstants.spreadsheetId,
      range,
    );
    final rows = response.values ?? [];
    if (rows.isEmpty) return '1';

    int maxId = 0;
    for (var row in rows) {
      if (row.isNotEmpty) {
        final id = int.tryParse(row[0].toString()) ?? 0;
        if (id > maxId) maxId = id;
      }
    }
    return (maxId + 1).toString();
  }

  // ─── Consultas ──────────────────────────────────────────────────────────────

  /// Devuelve TODAS las entradas del historial de costos.
  static Future<List<CostEntryModel>> getAllCostEntries() async {
    await _init();
    final response = await _sheetsApi!.spreadsheets.values.get(
      AppConstants.spreadsheetId,
      AppConstants.costHistoryRange,
    );
    final rows = response.values ?? [];
    return rows
        .where((row) => row.isNotEmpty && row[0].toString().trim().isNotEmpty)
        .map((row) => CostEntryModel.fromRow(row))
        .toList();
  }

  /// Devuelve el historial de costos filtrado por [productName].
  static Future<List<CostEntryModel>> getCostHistory(String productName) async {
    final all = await getAllCostEntries();
    return all.where((e) => e.productName == productName).toList();
  }

  /// Calcula el costo promedio ponderado actual para un producto.
  static Future<double> getAverageCost(String productName) async {
    final history = await getCostHistory(productName);
    return CostEntryModel.calcularCostoPromedio(history);
  }

  // ─── Escritura ───────────────────────────────────────────────────────────────

  /// Registra una nueva entrada de costo en la hoja Historial_Costos.
  static Future<void> addCostEntry(CostEntryModel entry) async {
    await _init();
    final nextId = await _getNextId(AppConstants.costHistoryRange);
    
    final finalEntry = CostEntryModel(
      costoId:       nextId,
      productName:   entry.productName,
      fecha:         entry.fecha,
      costoUnitario: entry.costoUnitario,
      cantidad:      entry.cantidad,
      tipoOrigen:    entry.tipoOrigen,
      movimientoId:  entry.movimientoId,
      usuarioNombre: entry.usuarioNombre,
      observacion:   entry.observacion,
    );

    final valueRange = sheets.ValueRange(values: [finalEntry.toRow()]);
    await _sheetsApi!.spreadsheets.values.append(
      valueRange,
      AppConstants.spreadsheetId,
      AppConstants.costHistoryRange,
      valueInputOption: 'USER_ENTERED',
    );
  }

  /// Actualiza el campo `costoPromedio` (columna H) en la hoja Productos
  /// tras registrar una nueva entrada de costo.
  static Future<void> updateProductAverageCost({
    required String productName,
    required double newAverage,
    required int productRowIndex, // fila real en la hoja (1-indexed)
  }) async {
    await _init();
    final valueRange = sheets.ValueRange(values: [[newAverage]]);
    await _sheetsApi!.spreadsheets.values.update(
      valueRange,
      AppConstants.spreadsheetId,
      'Productos!H$productRowIndex',
      valueInputOption: 'USER_ENTERED',
    );
  }

  /// Encuentra la fila de un producto en la hoja Productos por su nombre.
  static Future<int> findProductRowIndex(String productName) async {
    await _init();
    final response = await _sheetsApi!.spreadsheets.values.get(
      AppConstants.spreadsheetId,
      'Productos!B2:B', // Columna B es Nombre
    );
    final rows = response.values ?? [];
    for (int i = 0; i < rows.length; i++) {
      if (rows[i].isNotEmpty && rows[i][0].toString() == productName) {
        return i + 2;
      }
    }
    return -1;
  }
}
