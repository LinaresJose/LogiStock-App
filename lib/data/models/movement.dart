class MovementModel {
  final String id;
  final String date;
  final String productName; // Antes era skuId, ahora el usuario lo llamó Nombre_Producto
  final String type; // 'Entrada' o 'Salida'
  final int quantity;
  final String observation; // Nueva columna

  MovementModel({
    required this.id,
    required this.date,
    required this.productName,
    required this.type,
    required this.quantity,
    this.observation = '',
  });

  factory MovementModel.fromRow(List<dynamic> row) {
    return MovementModel(
      id: row.isNotEmpty ? row[0].toString() : '',
      date: row.length > 1 ? row[1].toString() : '',
      productName: row.length > 2 ? row[2].toString() : '',
      type: row.length > 3 ? row[3].toString() : '',
      quantity: row.length > 4 ? int.tryParse(row[4].toString()) ?? 0 : 0,
      observation: row.length > 5 ? row[5].toString() : '',
    );
  }

  List<dynamic> toRow() {
    return [id, date, productName, type, quantity, observation];
  }
}
