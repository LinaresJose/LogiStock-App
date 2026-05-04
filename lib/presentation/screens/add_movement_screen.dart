import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

import '../../domain/providers/inventory_provider.dart';
import '../../domain/providers/auth_provider.dart';
import '../../domain/providers/costs_provider.dart';
import '../../data/models/movement.dart';
import '../../data/models/product.dart';

class AddMovementScreen extends ConsumerStatefulWidget {
  const AddMovementScreen({super.key});

  @override
  ConsumerState<AddMovementScreen> createState() => _AddMovementScreenState();
}

class _AddMovementScreenState extends ConsumerState<AddMovementScreen> {
  final _formKey              = GlobalKey<FormState>();
  String? _selectedSku;
  String? _selectedProductName;
  String  _selectedType       = 'Entrada';
  final   _quantityController    = TextEditingController();
  final   _observationController = TextEditingController();
  // ── Campos de costo ──────────────────────────────────────────────────────
  final   _costoController       = TextEditingController();
  bool    _registrarCosto        = false;
  bool    _isLoading             = false;

  @override
  void dispose() {
    _quantityController.dispose();
    _observationController.dispose();
    _costoController.dispose();
    super.dispose();
  }

  void _showProductSearch(List<ProductWithStock> products) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => _ProductSearchSheet(
        products: products,
        onSelected: (product) {
          setState(() {
            _selectedSku         = product.skuId;
            _selectedProductName = product.name;
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _selectedProductName == null) {
      if (_selectedProductName == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Por favor selecciona un producto'),
          backgroundColor: Colors.orange,
        ));
      }
      return;
    }

    setState(() => _isLoading = true);

    final currentUser = ref.read(currentUserProvider);
    final movementId  = const Uuid().v4().substring(0, 8);
    final hasCoste    = _registrarCosto &&
        _selectedType == 'Entrada' &&
        _costoController.text.isNotEmpty;

    final movement = MovementModel(
      id:          movementId,
      date:        DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
      productName: _selectedProductName!,
      type:        _selectedType,
      quantity:    int.parse(_quantityController.text),
      observation: _observationController.text.trim(),
      userId:      currentUser?.userId ?? '',
      tieneCosto:  hasCoste,
    );

    try {
      // 1. Guardar el movimiento
      await ref.read(inventoryControllerProvider).addMovement(movement);

      // 2. Si es una Entrada con costo, registrar en Historial_Costos
      if (hasCoste && _selectedSku != null) {
        final costo    = double.tryParse(_costoController.text) ?? 0.0;
        final cantidad = int.tryParse(_quantityController.text) ?? 0;
        if (costo > 0 && cantidad > 0) {
          await ref.read(costsControllerProvider).addCostEntry(
            skuId:         _selectedSku!,
            costoUnitario: costo,
            cantidad:      cantidad,
            tipoOrigen:    'entrada_stock',
            movimientoId:  movementId,
            observacion:   _observationController.text.trim(),
          );
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Movimiento registrado exitosamente')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    final canSeeCosts   = ref.watch(currentPermissionsProvider).canRegisterCosts;
    final isEntrada     = _selectedType == 'Entrada';

    return Scaffold(
      appBar: AppBar(title: const Text('Registrar Movimiento')),
      body: productsAsync.when(
        data: (products) => SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Selector de producto ──────────────────────────────────
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
                            _selectedProductName ?? 'Toca para buscar...',
                            style: TextStyle(
                                color: _selectedProductName != null
                                    ? Colors.black
                                    : Colors.grey),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Tipo de movimiento ────────────────────────────────────
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                      labelText: 'Tipo de Movimiento',
                      border: OutlineInputBorder()),
                  value: _selectedType,
                  items: ['Entrada', 'Salida'].map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Row(children: [
                        Icon(
                            type == 'Entrada'
                                ? Icons.arrow_downward
                                : Icons.arrow_upward,
                            color: type == 'Entrada' ? Colors.green : Colors.red,
                            size: 20),
                        const SizedBox(width: 8),
                        Text(type),
                      ]),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() {
                    _selectedType = value!;
                    // Si cambia a Salida, desactivar costo
                    if (_selectedType == 'Salida') _registrarCosto = false;
                  }),
                ),
                const SizedBox(height: 16),

                // ── Cantidad ──────────────────────────────────────────────
                TextFormField(
                  controller: _quantityController,
                  decoration: const InputDecoration(
                      labelText: 'Cantidad', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Ingresa la cantidad';
                    if (int.tryParse(v) == null) return 'Debe ser un número válido';
                    if (int.parse(v) <= 0) return 'Debe ser mayor a cero';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // ── Observación ───────────────────────────────────────────
                TextFormField(
                  controller: _observationController,
                  decoration: const InputDecoration(
                    labelText: 'Observación (Opcional)',
                    border: OutlineInputBorder(),
                    hintText: 'Ej: Factura #123, Deterioro, etc.',
                  ),
                  maxLines: 2,
                ),

                // ── Sección de Costo (solo Entradas + permiso) ────────────
                if (isEntrada && canSeeCosts) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(Icons.attach_money, color: Colors.green.shade700),
                          const SizedBox(width: 8),
                          Text('Costo de Compra',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade800,
                                fontSize: 15,
                              )),
                        ]),
                        const SizedBox(height: 4),
                        Text(
                          'Registra el costo unitario para el historial financiero',
                          style: TextStyle(
                              fontSize: 12, color: Colors.green.shade600),
                        ),
                        SwitchListTile(
                          value: _registrarCosto,
                          onChanged: (v) => setState(() => _registrarCosto = v),
                          title: const Text('Registrar costo unitario',
                              style: TextStyle(fontSize: 14)),
                          activeColor: Colors.green.shade700,
                          contentPadding: EdgeInsets.zero,
                        ),
                        if (_registrarCosto) ...[
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _costoController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Costo Unitario de Compra',
                              prefixText: '\$ ',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              fillColor: Colors.white,
                              filled: true,
                            ),
                            validator: (v) {
                              if (_registrarCosto) {
                                if (v == null || v.isEmpty) return 'Ingresa el costo';
                                if (double.tryParse(v) == null) return 'Número inválido';
                                if (double.parse(v) <= 0) return 'Debe ser mayor a 0';
                              }
                              return null;
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 32),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Guardar Movimiento',
                            style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Error al cargar productos')),
      ),
    );
  }
}

// ─── Sheet de búsqueda de producto ──────────────────────────────────────────

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
      final s = '${p.product.name} ${p.product.skuId}'.toLowerCase();
      return s.contains(_query.toLowerCase());
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        const Text('Buscar Producto',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        TextField(
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Nombre o SKU...',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onChanged: (v) => setState(() => _query = v),
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
                subtitle: Text(
                    'SKU: ${item.product.skuId} | Stock: ${item.currentStock}'),
                onTap: () => widget.onSelected(item.product),
              );
            },
          ),
        ),
      ]),
    );
  }
}
