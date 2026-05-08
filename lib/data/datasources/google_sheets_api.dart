import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis_auth/auth_io.dart';

import '../../core/constants.dart';
import '../models/category.dart';
import '../models/product.dart';
import '../models/movement.dart';

class GoogleSheetsApi {
  static sheets.SheetsApi? _sheetsApi;

  static Future<void> init() async {
    final credentialsJson = await rootBundle.loadString('assets/credentials.json');
    final credentials = ServiceAccountCredentials.fromJson(json.decode(credentialsJson));
    final scopes = [sheets.SheetsApi.spreadsheetsScope];
    final client = await clientViaServiceAccount(credentials, scopes);
    _sheetsApi = sheets.SheetsApi(client);
  }

  // ── Auxiliares ──────────────────────────────────────────────────────────────

  static Future<String> _getNextId(String range) async {
    if (_sheetsApi == null) await init();
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

  // ── Lecturas ────────────────────────────────────────────────────────────────

  static Future<List<CategoryModel>> getCategories() async {
    if (_sheetsApi == null) await init();
    final response = await _sheetsApi!.spreadsheets.values.get(
      AppConstants.spreadsheetId,
      AppConstants.categoriesRange,
    );
    final rows = response.values ?? [];
    return rows
        .where((row) => row.isNotEmpty && row[0].toString().trim().isNotEmpty)
        .map((row) => CategoryModel.fromRow(row))
        .toList();
  }

  static Future<List<ProductModel>> getProducts() async {
    if (_sheetsApi == null) await init();
    final response = await _sheetsApi!.spreadsheets.values.get(
      AppConstants.spreadsheetId,
      AppConstants.productsRange, // A2:H (incluye costoPromedio)
    );
    final rows = response.values ?? [];
    return rows
        .where((row) => row.isNotEmpty && row[0].toString().trim().isNotEmpty)
        .map((row) => ProductModel.fromRow(row))
        .toList();
  }

  static Future<List<MovementModel>> getMovements() async {
    if (_sheetsApi == null) await init();
    final response = await _sheetsApi!.spreadsheets.values.get(
      AppConstants.spreadsheetId,
      AppConstants.movementsRange, // A2:H (incluye usuarioNombre, tieneCosto)
    );
    final rows = response.values ?? [];
    return rows
        .where((row) => row.isNotEmpty && row[0].toString().trim().isNotEmpty)
        .map((row) => MovementModel.fromRow(row))
        .toList();
  }

  // ── Movimientos ─────────────────────────────────────────────────────────────

  static Future<void> addMovement(MovementModel movement) async {
    if (_sheetsApi == null) await init();
    final nextId = await _getNextId(AppConstants.movementsRange);
    
    // Crear copia con el nuevo ID
    final finalMovement = MovementModel(
      id:            nextId,
      date:          movement.date,
      productName:   movement.productName,
      type:          movement.type,
      quantity:      movement.quantity,
      observation:   movement.observation,
      usuarioNombre: movement.usuarioNombre,
      tieneCosto:    movement.tieneCosto,
    );

    final valueRange = sheets.ValueRange(values: [finalMovement.toRow()]);
    await _sheetsApi!.spreadsheets.values.append(
      valueRange,
      AppConstants.spreadsheetId,
      AppConstants.movementsRange,
      valueInputOption: 'USER_ENTERED',
    );
  }

  // ── CRUD CATEGORÍAS ─────────────────────────────────────────────────────────

  static Future<int> _findCategoryRowIndex(String id) async {
    final response = await _sheetsApi!.spreadsheets.values.get(
      AppConstants.spreadsheetId,
      AppConstants.categoriesRange,
    );
    final rows = response.values ?? [];
    for (int i = 0; i < rows.length; i++) {
      if (rows[i].isNotEmpty && rows[i][0].toString() == id) return i + 2;
    }
    return -1;
  }

  static Future<void> addCategory(CategoryModel category) async {
    if (_sheetsApi == null) await init();
    final nextId = await _getNextId(AppConstants.categoriesRange);
    
    final finalCategory = CategoryModel(
      id: nextId,
      name: category.name,
    );

    final valueRange = sheets.ValueRange(values: [finalCategory.toRow()]);
    await _sheetsApi!.spreadsheets.values.append(
      valueRange,
      AppConstants.spreadsheetId,
      AppConstants.categoriesRange,
      valueInputOption: 'USER_ENTERED',
    );
  }

  static Future<void> updateCategory(CategoryModel category) async {
    if (_sheetsApi == null) await init();
    final rowIndex = await _findCategoryRowIndex(category.id);
    if (rowIndex == -1) throw Exception('Categoría no encontrada');
    final valueRange = sheets.ValueRange(values: [category.toRow()]);
    await _sheetsApi!.spreadsheets.values.update(
      valueRange,
      AppConstants.spreadsheetId,
      'Categorías!A$rowIndex:B$rowIndex',
      valueInputOption: 'USER_ENTERED',
    );
  }

  static Future<void> deleteCategory(String id) async {
    if (_sheetsApi == null) await init();
    final rowIndex = await _findCategoryRowIndex(id);
    if (rowIndex == -1) throw Exception('Categoría no encontrada');
    final request = sheets.ClearValuesRequest();
    await _sheetsApi!.spreadsheets.values.clear(
      request,
      AppConstants.spreadsheetId,
      'Categorías!A$rowIndex:B$rowIndex',
    );
  }

  // ── CRUD PRODUCTOS ──────────────────────────────────────────────────────────

  static Future<int> _findProductRowIndex(String skuId) async {
    final response = await _sheetsApi!.spreadsheets.values.get(
      AppConstants.spreadsheetId,
      AppConstants.productsRange,
    );
    final rows = response.values ?? [];
    for (int i = 0; i < rows.length; i++) {
      if (rows[i].isNotEmpty && rows[i][0].toString() == skuId) return i + 2;
    }
    return -1;
  }

  static Future<void> addProduct(ProductModel product) async {
    if (_sheetsApi == null) await init();
    
    // Usamos el skuId que viene del formulario (autogenerado en UI)
    final finalProduct = ProductModel(
      skuId:         product.skuId,
      name:          product.name,
      categoryId:    product.categoryId,
      image:         product.image,
      minStock:      product.minStock,
      leadTime:      product.leadTime,
      initialStock:  product.initialStock,
      costoPromedio: product.costoPromedio,
    );

    final valueRange = sheets.ValueRange(values: [finalProduct.toRow()]);
    await _sheetsApi!.spreadsheets.values.append(
      valueRange,
      AppConstants.spreadsheetId,
      AppConstants.productsRange,
      valueInputOption: 'USER_ENTERED',
    );
  }

  static Future<void> updateProduct(ProductModel product) async {
    if (_sheetsApi == null) await init();
    final rowIndex = await _findProductRowIndex(product.skuId);
    if (rowIndex == -1) throw Exception('Producto no encontrado');
    final valueRange = sheets.ValueRange(values: [product.toRow()]);
    await _sheetsApi!.spreadsheets.values.update(
      valueRange,
      AppConstants.spreadsheetId,
      'Productos!A$rowIndex:G$rowIndex', // Reducido a G
      valueInputOption: 'USER_ENTERED',
    );
  }

  static Future<void> deleteProduct(String skuId) async {
    if (_sheetsApi == null) await init();
    final rowIndex = await _findProductRowIndex(skuId);
    if (rowIndex == -1) throw Exception('Producto no encontrado');
    final request = sheets.ClearValuesRequest();
    await _sheetsApi!.spreadsheets.values.clear(
      request,
      AppConstants.spreadsheetId,
      'Productos!A$rowIndex:G$rowIndex', // Reducido a G
    );
  }
}
