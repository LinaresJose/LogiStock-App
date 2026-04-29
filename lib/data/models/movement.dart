class MovementModel {
  final String id;
  final String date;
  final String skuId;
  final String type; // 'Entrada' o 'Salida'
  final int quantity;

  MovementModel({
    required this.id,
    required this.date,
    required this.skuId,
    required this.type,
    required this.quantity,
  });

  factory MovementModel.fromRow(List<dynamic> row) {
    return MovementModel(
      id: row.isNotEmpty ? row[0].toString() : '',
      date: row.length > 1 ? row[1].toString() : '',
      skuId: row.length > 2 ? row[2].toString() : '',
      type: row.length > 3 ? row[3].toString() : '',
      quantity: row.length > 4 ? int.tryParse(row[4].toString()) ?? 0 : 0,
    );
  }

  List<dynamic> toRow() {
    return [id, date, skuId, type, quantity];
  }
}
