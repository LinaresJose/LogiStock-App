import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/providers/costs_provider.dart';

class CostsReportScreen extends ConsumerWidget {
  const CostsReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final costsAsync = ref.watch(allCostEntriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reporte de Costos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(allCostEntriesProvider);
            },
          ),
        ],
      ),
      body: costsAsync.when(
        data: (costs) {
          if (costs.isEmpty) {
            return const Center(child: Text('No hay registros de costos.'));
          }

          // Ordenar por fecha descendente
          final sortedCosts = List.of(costs);
          sortedCosts.sort((a, b) => b.fecha.compareTo(a.fecha));

          return ListView.builder(
            itemCount: sortedCosts.length,
            itemBuilder: (context, index) {
              final cost = sortedCosts[index];
              final totalCost = cost.costoUnitario * cost.cantidad;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.blueGrey.shade100),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'SKU: ${cost.skuId}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '\$${totalCost.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(cost.fecha, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Origen: ${cost.tipoOrigen.replaceAll('_', ' ').toUpperCase()}'),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Cant: ${cost.cantidad}'),
                          Text('Unitario: \$${cost.costoUnitario.toStringAsFixed(2)}'),
                        ],
                      ),
                      if (cost.observacion.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text('Obs: ${cost.observacion}',
                            style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey.shade700, fontSize: 12)),
                      ]
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error al cargar costos: $err')),
      ),
    );
  }
}
