import '../../core/utils/string_utils.dart';

/// Modelo que representa una entrada en el historial de costos
/// (hoja: Historial_Costos)
class CostEntryModel {
  final String costoId;
  final String productName;
  final String fecha;
  final double costoUnitario;
  final int cantidad;
  final String tipoOrigen; // 'nuevo_producto' | 'entrada_stock'
  final String movimientoId;
  final String usuarioNombre;
  final String observacion;

  const CostEntryModel({
    required this.costoId,
    required this.productName,
    required this.fecha,
    required this.costoUnitario,
    required this.cantidad,
    required this.tipoOrigen,
    required this.movimientoId,
    required this.usuarioNombre,
    this.observacion = '',
  });

  /// Columnas: A=costoId, B=productName, C=fecha, D=costoUnitario, E=cantidad,
  ///           F=tipoOrigen, G=movimientoId, H=usuarioNombre, I=observacion
  factory CostEntryModel.fromRow(List<dynamic> row) {
    return CostEntryModel(
      costoId:      row.isNotEmpty ? row[0].toString() : '',
      productName:  row.length > 1 ? row[1].toString() : '',
      fecha:        row.length > 2 ? row[2].toString() : '',
      costoUnitario: row.length > 3
          ? double.tryParse(row[3].toString()) ?? 0.0
          : 0.0,
      cantidad:     row.length > 4
          ? int.tryParse(row[4].toString()) ?? 0
          : 0,
      tipoOrigen:   row.length > 5 ? row[5].toString() : '',
      movimientoId: row.length > 6 ? row[6].toString() : '',
      usuarioNombre: row.length > 7 ? row[7].toString() : '',
      observacion:  row.length > 8 ? row[8].toString() : '',
    );
  }

  List<dynamic> toRow() {
    return [
      costoId,
      productName, // Ya viene capitalizado del modelo Product
      fecha,
      costoUnitario,
      cantidad,
      tipoOrigen,
      movimientoId,
      usuarioNombre,
      StringExtensions.capitalize(observacion),
    ];
  }

  // ─── Helpers de Cálculo ───────────────────────────────────────

  /// Costo total de esta entrada (costo unitario × cantidad)
  double get costoTotal => costoUnitario * cantidad;

  /// Calcula el costo promedio ponderado de una lista de entradas.
  static double calcularCostoPromedio(List<CostEntryModel> entries) {
    if (entries.isEmpty) return 0.0;
    final totalCantidad = entries.fold<int>(0, (sum, e) => sum + e.cantidad);
    if (totalCantidad == 0) return 0.0;
    final totalCosto = entries.fold<double>(0.0, (sum, e) => sum + e.costoTotal);
    return totalCosto / totalCantidad;
  }

  /// Devuelve las entradas ordenadas por fecha para cálculo FIFO.
  static List<CostEntryModel> ordenarParaFIFO(List<CostEntryModel> entries) {
    final sorted = List<CostEntryModel>.from(entries);
    sorted.sort((a, b) => a.fecha.compareTo(b.fecha));
    return sorted;
  }
}
