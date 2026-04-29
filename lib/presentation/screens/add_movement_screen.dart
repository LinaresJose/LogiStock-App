import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

import '../../domain/providers/inventory_provider.dart';
import '../../data/models/movement.dart';

class AddMovementScreen extends ConsumerStatefulWidget {
  const AddMovementScreen({super.key});

  @override
  ConsumerState<AddMovementScreen> createState() => _AddMovementScreenState();
}

class _AddMovementScreenState extends ConsumerState<AddMovementScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedSku;
  String _selectedType = 'Entrada';
  final _quantityController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_formKey.currentState!.validate() && _selectedSku != null) {
      setState(() => _isLoading = true);
      
      final movement = MovementModel(
        id: const Uuid().v4().substring(0, 8),
        date: DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
        skuId: _selectedSku!,
        type: _selectedType,
        quantity: int.parse(_quantityController.text),
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
    } else if (_selectedSku == null) {
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
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Producto (SKU)',
                      border: OutlineInputBorder(),
                    ),
                    value: _selectedSku,
                    items: products.map((p) {
                      return DropdownMenuItem(
                        value: p.product.skuId,
                        child: Text('${p.product.name} (${p.product.skuId})'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedSku = value;
                      });
                    },
                    validator: (value) => value == null ? 'Selecciona un producto' : null,
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
                        child: Text(type),
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
