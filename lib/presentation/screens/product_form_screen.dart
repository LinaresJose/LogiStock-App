import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/models/product.dart';
import '../../domain/providers/inventory_provider.dart';
import '../../domain/providers/auth_provider.dart';
import '../../domain/providers/costs_provider.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  final ProductWithStock? productWithStock;

  const ProductFormScreen({super.key, this.productWithStock});

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _skuController;
  late TextEditingController _nameController;
  String? _selectedCategoryId;
  late TextEditingController _imageController;
  late TextEditingController _minStockController;
  late TextEditingController _leadTimeController;
  late TextEditingController _initialStockController;
  // Costo inicial (solo para productos nuevos)
  final _costoInicialController = TextEditingController();
  bool _registrarCosto = false;

  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final p = widget.productWithStock?.product;
    _skuController          = TextEditingController(text: p?.skuId ?? '');
    _nameController         = TextEditingController(text: p?.name ?? '');
    _selectedCategoryId     = p?.categoryId;
    _imageController        = TextEditingController(text: p?.image ?? '');
    _minStockController     = TextEditingController(text: p?.minStock.toString() ?? '0');
    _leadTimeController     = TextEditingController(text: p?.leadTime.toString() ?? '0');
    _initialStockController = TextEditingController(text: p?.initialStock.toString() ?? '0');

    if (widget.productWithStock == null) {
      _nameController.addListener(_onNameChanged);
    }
  }

  void _onNameChanged() {
    final name = _nameController.text.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
    if (name.length < 4) { _skuController.text = ''; return; }
    final prefix   = name.substring(0, 4);
    final products = ref.read(productsProvider).value ?? [];
    int maxNum = 0;
    for (var p in products) {
      final sku = p.product.skuId;
      if (sku.startsWith(prefix) && sku.length == 7) {
        final num = int.tryParse(sku.substring(4));
        if (num != null && num > maxNum) maxNum = num;
      }
    }
    _skuController.text = '$prefix${(maxNum + 1).toString().padLeft(3, '0')}';
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source, maxWidth: 800, maxHeight: 800, imageQuality: 85);
      if (pickedFile != null) {
        setState(() => _imageController.text = pickedFile.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al capturar imagen: $e')));
      }
    }
  }

  void _showImageSourceActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Galería'),
            onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); },
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera),
            title: const Text('Cámara'),
            onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); },
          ),
        ]),
      ),
    );
  }

  @override
  void dispose() {
    _skuController.dispose();
    _nameController.dispose();
    _imageController.dispose();
    _minStockController.dispose();
    _leadTimeController.dispose();
    _initialStockController.dispose();
    _costoInicialController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate() && _selectedCategoryId != null) {
      setState(() => _isLoading = true);

      final newProduct = ProductModel(
        skuId:        _skuController.text.trim(),
        name:         _nameController.text.trim(),
        categoryId:   _selectedCategoryId!,
        image:        _imageController.text.trim(),
        minStock:     int.tryParse(_minStockController.text) ?? 0,
        leadTime:     int.tryParse(_leadTimeController.text) ?? 0,
        initialStock: int.tryParse(_initialStockController.text) ?? 0,
      );

      try {
        if (widget.productWithStock == null) {
          await ref.read(inventoryControllerProvider).addProduct(newProduct);

          // Registrar costo inicial si el usuario lo indicó
          if (_registrarCosto && _costoInicialController.text.isNotEmpty) {
            final costo = double.tryParse(_costoInicialController.text) ?? 0.0;
            final cantidad = int.tryParse(_initialStockController.text) ?? 0;
            if (costo > 0 && cantidad > 0) {
              await ref.read(costsControllerProvider).addCostEntry(
                skuId:        newProduct.skuId,
                costoUnitario: costo,
                cantidad:     cantidad,
                tipoOrigen:   'nuevo_producto',
                observacion:  'Costo inicial al crear producto',
              );
            }
          }
        } else {
          await ref.read(inventoryControllerProvider).updateProduct(newProduct);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Producto guardado exitosamente')));
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
    } else if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Por favor selecciona una categoría'),
        backgroundColor: Colors.orange,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing    = widget.productWithStock != null;
    final categoriesAsync = ref.watch(categoriesProvider);
    ref.watch(productsProvider);

    // Solo usuarios con permiso de costos pueden ver/registrar costo inicial
    final canRegisterCosts = ref.watch(currentPermissionsProvider).canRegisterCosts;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Producto' : 'Nuevo Producto'),
      ),
      body: categoriesAsync.when(
        data: (categories) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Imagen ─────────────────────────────────────────────
                  Center(
                    child: GestureDetector(
                      onTap: () => _showImageSourceActionSheet(context),
                      child: Container(
                        height: 150,
                        width: 150,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: _imageController.text.isEmpty
                            ? const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo, size: 40, color: Colors.grey),
                                  SizedBox(height: 8),
                                  Text('Añadir Foto', style: TextStyle(color: Colors.grey)),
                                ],
                              )
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: _imageController.text.startsWith('http')
                                    ? Image.network(_imageController.text, fit: BoxFit.cover)
                                    : (kIsWeb
                                        ? Image.network(_imageController.text, fit: BoxFit.cover)
                                        : Image.file(File(_imageController.text), fit: BoxFit.cover)),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Campos del producto ────────────────────────────────
                  TextFormField(
                    controller: _skuController,
                    decoration: const InputDecoration(
                        labelText: 'SKU ID', border: OutlineInputBorder()),
                    enabled: false,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                        labelText: 'Nombre del Producto',
                        border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                        labelText: 'Categoría', border: OutlineInputBorder()),
                    value: _selectedCategoryId,
                    items: categories.map((c) => DropdownMenuItem(
                      value: c.id, child: Text(c.name))).toList(),
                    onChanged: (v) => setState(() => _selectedCategoryId = v),
                    validator: (v) => v == null ? 'Selecciona una categoría' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _imageController,
                    decoration: const InputDecoration(
                      labelText: 'URL de Imagen o Ruta',
                      border: OutlineInputBorder(),
                      helperText: 'Puedes usar la cámara arriba o pegar una URL aquí',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                      child: TextFormField(
                        controller: _minStockController,
                        decoration: const InputDecoration(
                            labelText: 'Stock Mínimo', border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                        validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _leadTimeController,
                        decoration: const InputDecoration(
                            labelText: 'Lead Time (días)',
                            border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                        validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _initialStockController,
                    decoration: const InputDecoration(
                        labelText: 'Stock Inicial', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    enabled: !isEditing,
                    validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                  ),

                  // ── Sección de Costo Inicial (solo nuevos + con permiso) ──
                  if (!isEditing && canRegisterCosts) ...[
                    const SizedBox(height: 24),
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
                          Row(
                            children: [
                              Icon(Icons.attach_money, color: Colors.green.shade700),
                              const SizedBox(width: 8),
                              Text(
                                'Costo de Compra (Opcional)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade800,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Registra el costo unitario para trazabilidad financiera',
                            style: TextStyle(
                                fontSize: 12, color: Colors.green.shade600),
                          ),
                          const SizedBox(height: 12),
                          SwitchListTile(
                            value: _registrarCosto,
                            onChanged: (v) =>
                                setState(() => _registrarCosto = v),
                            title: const Text('Registrar costo inicial',
                                style: TextStyle(fontSize: 14)),
                            activeColor: Colors.green.shade700,
                            contentPadding: EdgeInsets.zero,
                          ),
                          if (_registrarCosto) ...[
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _costoInicialController,
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
                          : Text(isEditing ? 'Actualizar Producto' : 'Guardar Producto',
                              style: const TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error al cargar categorías: $error')),
      ),
    );
  }
}
