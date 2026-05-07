import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/providers/inventory_provider.dart';

class MovementsHistoryScreen extends ConsumerWidget {
  const MovementsHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movementsAsync = ref.watch(movementsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial Global de Movimientos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(movementsProvider);
            },
          ),
        ],
      ),
      body: movementsAsync.when(
        data: (movements) {
          if (movements.isEmpty) {
            return const Center(child: Text('No hay movimientos registrados.'));
          }

          // Ordenar por fecha de forma descendente (más recientes primero)
          final sortedMovements = List.of(movements);
          sortedMovements.sort((a, b) => b.date.compareTo(a.date));

          return ListView.builder(
            itemCount: sortedMovements.length,
            itemBuilder: (context, index) {
              final mov = sortedMovements[index];
              final isEntrada = mov.type.toLowerCase() == 'entrada';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isEntrada ? Colors.green.shade50 : Colors.red.shade50,
                    child: Icon(
                      isEntrada ? Icons.arrow_downward : Icons.arrow_upward,
                      color: isEntrada ? Colors.green.shade700 : Colors.red.shade700,
                    ),
                  ),
                  title: Text(
                    mov.productName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text('Tipo: ${mov.type} | Cant: ${mov.quantity} | Por: ${mov.usuarioNombre}'),
                      Text('Fecha: ${mov.date}', style: const TextStyle(fontSize: 12)),
                      if (mov.observation.isNotEmpty)
                        Text('Obs: ${mov.observation}',
                            style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey.shade600, fontSize: 12)),
                    ],
                  ),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error al cargar historial: $err')),
      ),
    );
  }
}
