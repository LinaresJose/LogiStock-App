import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../data/datasources/costs_sheets_api.dart';
import '../../data/models/cost_entry_model.dart';
import 'auth_provider.dart';

// ─── Provider de historial por producto (familia) ─────────────────────────────

/// Historial de costos para un SKU específico.
/// Uso: `ref.watch(costHistoryProvider('ABCD001'))`
final costHistoryProvider =
    FutureProvider.family<List<CostEntryModel>, String>((ref, skuId) async {
  return await CostsSheetsApi.getCostHistory(skuId);
});

/// Costo promedio ponderado para un SKU específico.
final averageCostProvider =
    FutureProvider.family<double, String>((ref, skuId) async {
  return await CostsSheetsApi.getAverageCost(skuId);
});

/// Todas las entradas del historial de costos (para reportes de admin).
final allCostEntriesProvider =
    FutureProvider<List<CostEntryModel>>((ref) async {
  return await CostsSheetsApi.getAllCostEntries();
});

// ─── Controlador de costos ───────────────────────────────────────────────────

final costsControllerProvider = Provider<CostsController>((ref) {
  return CostsController(ref);
});

class CostsController {
  final Ref _ref;

  CostsController(this._ref);

  /// Registra una entrada de costo y actualiza el costo promedio en Productos.
  ///
  /// [skuId]         — SKU del producto.
  /// [costoUnitario] — Precio unitario de compra.
  /// [cantidad]      — Unidades recibidas.
  /// [tipoOrigen]    — 'nuevo_producto' o 'entrada_stock'.
  /// [movimientoId]  — ID del movimiento asociado (puede estar vacío si es alta de producto).
  /// [observacion]   — Nota libre opcional.
  Future<void> addCostEntry({
    required String skuId,
    required double costoUnitario,
    required int cantidad,
    required String tipoOrigen,
    String movimientoId = '',
    String observacion = '',
  }) async {
    final currentUser = _ref.read(currentUserProvider);

    final entry = CostEntryModel(
      costoId:       'CST-${const Uuid().v4().substring(0, 8).toUpperCase()}',
      skuId:         skuId,
      fecha:         DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
      costoUnitario: costoUnitario,
      cantidad:      cantidad,
      tipoOrigen:    tipoOrigen,
      movimientoId:  movimientoId,
      usuarioId:     currentUser?.userId ?? 'sistema',
      observacion:   observacion,
    );

    // 1. Escribir la entrada en Historial_Costos
    await CostsSheetsApi.addCostEntry(entry);

    // 2. Recalcular costo promedio y actualizarlo en la hoja Productos
    final history = await CostsSheetsApi.getCostHistory(skuId);
    final newAverage = CostEntryModel.calcularCostoPromedio(history);
    final rowIndex = await CostsSheetsApi.findProductRowIndex(skuId);
    if (rowIndex != -1) {
      await CostsSheetsApi.updateProductAverageCost(
        skuId:            skuId,
        newAverage:       newAverage,
        productRowIndex:  rowIndex,
      );
    }

    // 3. Invalidar providers afectados
    _ref.invalidate(costHistoryProvider(skuId));
    _ref.invalidate(averageCostProvider(skuId));
    _ref.invalidate(allCostEntriesProvider);
  }
}
