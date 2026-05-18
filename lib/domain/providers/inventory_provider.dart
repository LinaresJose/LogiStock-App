import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/google_sheets_api.dart';
import '../../data/models/category.dart';
import '../../data/models/product.dart';
import '../../data/models/movement.dart';
import 'auth_provider.dart';
import '../../data/datasources/supabase_storage_api.dart';

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


// Provider para Productos (depende de movimientos para calcular stock e imágenes de Supabase)
final productsProvider = FutureProvider<List<ProductWithStock>>((ref) async {
  // 1. Cargar productos de Sheets e imágenes de Supabase en paralelo
  final results = await Future.wait([
    GoogleSheetsApi.getProducts(),
    SupabaseStorageApi.getAllProductImages(),
  ]);

  final List<ProductModel> products = results[0] as List<ProductModel>;
  final Map<String, String> imageMap = results[1] as Map<String, String>;
  
  final movementsAsync = ref.watch(movementsProvider);
  final movements = movementsAsync.value ?? [];

  return products.map((product) {
    // 2. Asociar la imagen de Supabase al producto
    final updatedProduct = product.copyWithImage(imageMap[product.skuId] ?? '');

    // 3. Calcular Entradas y Salidas
    int totalIn = 0;
    int totalOut = 0;

    for (var mov in movements) {
      if (mov.productName == updatedProduct.name) {
        if (mov.type.toLowerCase() == 'entrada') {
          totalIn += mov.quantity;
        } else if (mov.type.toLowerCase() == 'salida') {
          totalOut += mov.quantity;
        }
      }
    }

    final currentStock = updatedProduct.initialStock + totalIn - totalOut;
    final isLowStock = currentStock <= updatedProduct.minStock;

    return ProductWithStock(
      product: updatedProduct,
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
    final currentUser = _ref.read(currentUserProvider);
    
    // Validación de negocio: la cantidad de salida no puede ser mayor al stock disponible
    if (movement.type.toLowerCase() == 'salida') {
      final productsList = await _ref.read(productsProvider.future);
      final matchedProduct = productsList.firstWhere(
        (p) => p.product.name == movement.productName,
        orElse: () => throw Exception('Producto no encontrado'),
      );
      if (movement.quantity > matchedProduct.currentStock) {
        throw Exception(
          'No se puede registrar la salida. El stock disponible de "${movement.productName}" es ${matchedProduct.currentStock}, menor que la cantidad solicitada (${movement.quantity}).'
        );
      }
    }
    
    final finalMovement = MovementModel(
      id:            '', // El API generará el auto-incremento
      date:          movement.date,
      productName:   movement.productName,
      type:          movement.type,
      quantity:      movement.quantity,
      observation:   movement.observation,
      usuarioNombre: currentUser?.nombre ?? 'Sistema',
      tieneCosto:    movement.tieneCosto,
    );

    await GoogleSheetsApi.addMovement(finalMovement);
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
