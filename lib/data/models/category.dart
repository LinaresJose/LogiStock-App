class CategoryModel {
  final String id;
  final String name;

  CategoryModel({required this.id, required this.name});

  factory CategoryModel.fromRow(List<dynamic> row) {
    return CategoryModel(
      id: row.isNotEmpty ? row[0].toString() : '',
      name: row.length > 1 ? row[1].toString() : '',
    );
  }

  List<dynamic> toRow() {
    return [id, name];
  }
}
