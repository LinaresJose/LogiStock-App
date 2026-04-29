import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/google_sheets_api.dart';
import '../../data/models/category.dart';
import '../../data/models/product.dart';
import '../../data/models/movement.dart';

// Provider para Categorías
final categoriesProvider = FutureProvider<List<CategoryModel>>((ref) async {
  return await GoogleSheetsApi.getCategories();
});

// Provider para Movimientos
final movementsProvider = FutureProvider<List<MovementModel>>((ref) async {
  return await GoogleSheetsApi.getMovements();
});

// Modelo de Producto con Stock Calculado
class ProductWithStock {
  final ProductModel product;
  final int currentStock;
  final bool isLowStock;

  ProductWithStock({
    required this.product,
    required this.currentStock,
    required this.isLowStock,
  });
}

// Provider para Productos (depende de movimientos para calcular stock)
final productsProvider = FutureProvider<List<ProductWithStock>>((ref) async {
  final products = await GoogleSheetsApi.getProducts();
  final movementsAsync = ref.watch(movementsProvider);

  // Si los movimientos aún no cargan o hay error, solo usamos stock inicial
  final movements = movementsAsync.value ?? [];

  return products.map((product) {
    // Calcular Entradas y Salidas
    int totalIn = 0;
    int totalOut = 0;

    for (var mov in movements) {
      if (mov.skuId == product.skuId) {
        if (mov.type.toLowerCase() == 'entrada') {
          totalIn += mov.quantity;
        } else if (mov.type.toLowerCase() == 'salida') {
          totalOut += mov.quantity;
        }
      }
    }

    final currentStock = product.initialStock + totalIn - totalOut;
    final isLowStock = currentStock <= product.minStock;

    return ProductWithStock(
      product: product,
      currentStock: currentStock,
      isLowStock: isLowStock,
    );
  }).toList();
});

// Provider para agregar movimientos y refrescar datos
final inventoryControllerProvider = Provider((ref) {
  return InventoryController(ref);
});

class InventoryController {
  final Ref _ref;

  InventoryController(this._ref);

  Future<void> addMovement(MovementModel movement) async {
    await GoogleSheetsApi.addMovement(movement);
    _ref.invalidate(movementsProvider);
    _ref.invalidate(productsProvider);
  }

  // --- CRUD CATEGORÍAS ---
  Future<void> addCategory(CategoryModel category) async {
    await GoogleSheetsApi.addCategory(category);
    _ref.invalidate(categoriesProvider);
  }

  Future<void> updateCategory(CategoryModel category) async {
    await GoogleSheetsApi.updateCategory(category);
    _ref.invalidate(categoriesProvider);
  }

  Future<void> deleteCategory(String id) async {
    await GoogleSheetsApi.deleteCategory(id);
    _ref.invalidate(categoriesProvider);
  }

  // --- CRUD PRODUCTOS ---
  Future<void> addProduct(ProductModel product) async {
    await GoogleSheetsApi.addProduct(product);
    _ref.invalidate(productsProvider);
  }

  Future<void> updateProduct(ProductModel product) async {
    await GoogleSheetsApi.updateProduct(product);
    _ref.invalidate(productsProvider);
  }

  Future<void> deleteProduct(String skuId) async {
    await GoogleSheetsApi.deleteProduct(skuId);
    _ref.invalidate(productsProvider);
  }
}
