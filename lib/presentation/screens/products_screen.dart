import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/providers/inventory_provider.dart';
import 'product_detail_screen.dart';
import 'product_form_screen.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  final String? initialCategoryId;
  final bool showLowStockOnly;

  const ProductsScreen({
    super.key,
    this.initialCategoryId,
    this.showLowStockOnly = false,
  });

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.showLowStockOnly ? 'Alertas de Stock' : 'Productos'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar producto o SKU...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                            _searchController.clear();
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
        ),
      ),
      body: productsAsync.when(
        data: (productsWithStock) {
          // Filtrar por categoría si se proporcionó una
          var filtered = productsWithStock;
          if (widget.initialCategoryId != null) {
            filtered = filtered.where((p) => p.product.categoryId == widget.initialCategoryId).toList();
          }

          // Filtrar por alertas de stock
          if (widget.showLowStockOnly) {
            filtered = filtered.where((p) => p.isLowStock).toList();
          }

          // Filtrar por búsqueda
          if (_searchQuery.isNotEmpty) {
            filtered = filtered.where((p) {
              final name = p.product.name.toLowerCase();
              final sku = p.product.skuId.toLowerCase();
              return name.contains(_searchQuery) || sku.contains(_searchQuery);
            }).toList();
          }

          if (filtered.isEmpty) {
            return const Center(child: Text('No se encontraron productos.'));
          }

          return ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final item = filtered[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: item.product.image.isNotEmpty 
                        ? NetworkImage(item.product.image) 
                        : null,
                    child: item.product.image.isEmpty 
                        ? const Icon(Icons.image_not_supported) 
                        : null,
                  ),
                  title: Text(item.product.name),
                  subtitle: Text('SKU: ${item.product.skuId}'),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: item.isLowStock ? Colors.red[100] : Colors.green[100],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Stock: ${item.currentStock}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: item.isLowStock ? Colors.red[900] : Colors.green[900],
                      ),
                    ),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProductDetailScreen(productWithStock: item),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProductFormScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
