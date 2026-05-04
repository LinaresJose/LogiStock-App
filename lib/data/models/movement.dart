class MovementModel {
  final String id;
  final String date;
  final String productName;
  final String type;       // 'Entrada' o 'Salida'
  final int quantity;
  final String observation;
  final String userId;     // Quién registró el movimiento (G)
  final bool tieneCosto;   // Si se registró costo asociado (H)

  MovementModel({
    required this.id,
    required this.date,
    required this.productName,
    required this.type,
    required this.quantity,
    this.observation = '',
    this.userId = '',
    this.tieneCosto = false,
  });

  factory MovementModel.fromRow(List<dynamic> row) {
    return MovementModel(
      id:          row.isNotEmpty ? row[0].toString() : '',
      date:        row.length > 1 ? row[1].toString() : '',
      productName: row.length > 2 ? row[2].toString() : '',
      type:        row.length > 3 ? row[3].toString() : '',
      quantity:    row.length > 4 ? int.tryParse(row[4].toString()) ?? 0 : 0,
      observation: row.length > 5 ? row[5].toString() : '',
      userId:      row.length > 6 ? row[6].toString() : '',
      tieneCosto:  row.length > 7
          ? row[7].toString().toUpperCase() == 'TRUE'
          : false,
    );
  }

  List<dynamic> toRow() {
    return [
      id,
      date,
      productName,
      type,
      quantity,
      observation,
      userId,
      tieneCosto ? 'TRUE' : 'FALSE',
    ];
  }
}
