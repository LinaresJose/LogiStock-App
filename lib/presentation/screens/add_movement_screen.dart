import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

import '../../domain/providers/inventory_provider.dart';
import '../../data/models/movement.dart';
import '../../data/models/product.dart';

class AddMovementScreen extends ConsumerStatefulWidget {
  const AddMovementScreen({super.key});

  @override
  ConsumerState<AddMovementScreen> createState() => _AddMovementScreenState();
}

class _AddMovementScreenState extends ConsumerState<AddMovementScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedSku;
  String? _selectedProductName;
  String _selectedType = 'Entrada';
  final _quantityController = TextEditingController();
  final _observationController = TextEditingController(); // Nuevo controlador
  bool _isLoading = false;

  @override
  void dispose() {
    _quantityController.dispose();
    _observationController.dispose();
    super.dispose();
  }

  void _showProductSearch(List<ProductWithStock> products) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return _ProductSearchSheet(
          products: products,
          onSelected: (product) {
            setState(() {
              _selectedSku = product.skuId;
              _selectedProductName = product.name;
            });
            Navigator.pop(context);
          },
        );
      },
    );
  }

  void _submit() async {
    if (_formKey.currentState!.validate() && _selectedProductName != null) {
      setState(() => _isLoading = true);
      
      final movement = MovementModel(
        id: const Uuid().v4().substring(0, 8),
        date: DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
        productName: _selectedProductName!, // Ahora enviamos el nombre
        type: _selectedType,
        quantity: int.parse(_quantityController.text),
        observation: _observationController.text.trim(), // Capturar observación
      );

      try {
        await ref.read(inventoryControllerProvider).addMovement(movement);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Movimiento registrado exitosamente')),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } else if (_selectedProductName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor selecciona un producto'), backgroundColor: Colors.orange),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Movimiento'),
      ),
      body: productsAsync.when(
        data: (products) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InkWell(
                    onTap: () => _showProductSearch(products),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Seleccionar Producto',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.search),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _selectedProductName != null
                                  ? '$_selectedProductName'
                                  : 'Toca para buscar...',
                              style: TextStyle(
                                color: _selectedProductName != null ? Colors.black : Colors.grey,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Tipo de Movimiento',
                      border: OutlineInputBorder(),
                    ),
                    value: _selectedType,
                    items: ['Entrada', 'Salida'].map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Row(
                          children: [
                            Icon(
                              type == 'Entrada' ? Icons.arrow_downward : Icons.arrow_upward,
                              color: type == 'Entrada' ? Colors.green : Colors.red,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(type),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedType = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _quantityController,
                    decoration: const InputDecoration(
                      labelText: 'Cantidad',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Ingresa la cantidad';
                      if (int.tryParse(value) == null) return 'Debe ser un número válido';
                      if (int.parse(value) <= 0) return 'Debe ser mayor a cero';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  // --- NUEVO CAMPO: OBSERVACIÓN ---
                  TextFormField(
                    controller: _observationController,
                    decoration: const InputDecoration(
                      labelText: 'Observación (Opcional)',
                      border: OutlineInputBorder(),
                      hintText: 'Ej: Factura #123, Deterioro, etc.',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading 
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Guardar Movimiento', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error al cargar productos')),
      ),
    );
  }
}

class _ProductSearchSheet extends StatefulWidget {
  final List<ProductWithStock> products;
  final Function(ProductModel) onSelected;

  const _ProductSearchSheet({required this.products, required this.onSelected});

  @override
  State<_ProductSearchSheet> createState() => _ProductSearchSheetState();
}

class _ProductSearchSheetState extends State<_ProductSearchSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.products.where((p) {
      final searchString = '${p.product.name} ${p.product.skuId}'.toLowerCase();
      return searchString.contains(_query.toLowerCase());
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text(
            'Buscar Producto',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Nombre o SKU...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final item = filtered[index];
                return ListTile(
                  leading: const Icon(Icons.inventory_2_outlined),
                  title: Text(item.product.name),
                  subtitle: Text('SKU: ${item.product.skuId} | Stock: ${item.currentStock}'),
                  onTap: () => widget.onSelected(item.product),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
