import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/providers/inventory_provider.dart';

class ProductDetailScreen extends ConsumerWidget {
  final ProductWithStock productWithStock;

  const ProductDetailScreen({super.key, required this.productWithStock});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movementsAsync = ref.watch(movementsProvider);
    final product = productWithStock.product;

    return Scaffold(
      appBar: AppBar(
        title: Text(product.name),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                product.image.isNotEmpty
                    ? Image.network(product.image, width: 80, height: 80, fit: BoxFit.cover)
                    : const Icon(Icons.image, size: 80, color: Colors.grey),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('SKU: ${product.skuId}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('Stock Inicial: ${product.initialStock}'),
                      Text('Mínimo: ${product.minStock} | Lead Time: ${product.leadTime} días'),
                      const SizedBox(height: 8),
                      Text(
                        'Stock Actual: ${productWithStock.currentStock}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: productWithStock.isLowStock ? Colors.red : Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Historial de Movimientos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: movementsAsync.when(
              data: (movements) {
                final productMovements = movements.where((m) => m.skuId == product.skuId).toList();
                
                if (productMovements.isEmpty) {
                  return const Center(child: Text('No hay movimientos registrados.'));
                }

                // Ordenar por fecha descendente
                productMovements.sort((a, b) => b.date.compareTo(a.date));

                return ListView.builder(
                  itemCount: productMovements.length,
                  itemBuilder: (context, index) {
                    final mov = productMovements[index];
                    final isEntrada = mov.type.toLowerCase() == 'entrada';
                    
                    return ListTile(
                      leading: Icon(
                        isEntrada ? Icons.arrow_downward : Icons.arrow_upward,
                        color: isEntrada ? Colors.green : Colors.red,
                      ),
                      title: Text('${mov.type} - Cantidad: ${mov.quantity}'),
                      subtitle: Text('Fecha: ${mov.date} | ID: ${mov.id}'),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('Error: $error')),
            ),
          ),
        ],
      ),
    );
  }
}
