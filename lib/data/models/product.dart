class ProductModel {
  final String skuId;
  final String name;
  final String categoryId;
  final String image;
  final int minStock;
  final int leadTime;
  final int initialStock;
  final double costoPromedio; // columna H (referencial, fuente de verdad = Historial_Costos)

  ProductModel({
    required this.skuId,
    required this.name,
    required this.categoryId,
    required this.image,
    required this.minStock,
    required this.leadTime,
    required this.initialStock,
    this.costoPromedio = 0.0,
  });

  factory ProductModel.fromRow(List<dynamic> row) {
    return ProductModel(
      skuId:         row.isNotEmpty ? row[0].toString() : '',
      name:          row.length > 1 ? row[1].toString() : '',
      categoryId:    row.length > 2 ? row[2].toString() : '',
      image:         row.length > 3 ? row[3].toString() : '',
      minStock:      row.length > 4 ? int.tryParse(row[4].toString()) ?? 0 : 0,
      leadTime:      row.length > 5 ? int.tryParse(row[5].toString()) ?? 0 : 0,
      initialStock:  row.length > 6 ? int.tryParse(row[6].toString()) ?? 0 : 0,
      costoPromedio: row.length > 7 ? double.tryParse(row[7].toString()) ?? 0.0 : 0.0,
    );
  }

  List<dynamic> toRow() {
    return [
      skuId,
      name,
      categoryId,
      image,
      minStock,
      leadTime,
      initialStock,
      costoPromedio,
    ];
  }

  ProductModel copyWith({double? costoPromedio}) {
    return ProductModel(
      skuId:         skuId,
      name:          name,
      categoryId:    categoryId,
      image:         image,
      minStock:      minStock,
      leadTime:      leadTime,
      initialStock:  initialStock,
      costoPromedio: costoPromedio ?? this.costoPromedio,
    );
  }
}
