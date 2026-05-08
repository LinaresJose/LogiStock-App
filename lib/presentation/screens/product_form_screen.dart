import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../../data/models/product.dart';
import '../../domain/providers/inventory_provider.dart';
import '../../domain/providers/auth_provider.dart';
import '../../domain/providers/costs_provider.dart';
import '../../data/datasources/supabase_storage_api.dart';

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
  String? _existingImageUrl;
  XFile? _pickedFile;
  late TextEditingController _minStockController;
  late TextEditingController _leadTimeController;
  late TextEditingController _initialStockController;
  // Costo inicial (solo para productos nuevos)
  final _costoInicialController = TextEditingController();
  bool _registrarCosto = false;

  bool _isLoading = false;
  bool _imageWasDeleted = false; // Nueva bandera
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final p = widget.productWithStock?.product;
    _skuController          = TextEditingController(text: p?.skuId ?? '');
    _nameController         = TextEditingController(text: p?.name ?? '');
    _selectedCategoryId     = p?.categoryId;
    _existingImageUrl       = p?.image;
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
        setState(() {
          _pickedFile = pickedFile;
          _imageWasDeleted = false;
        });
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
    _minStockController.dispose();
    _leadTimeController.dispose();
    _initialStockController.dispose();
    _costoInicialController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate() && _selectedCategoryId != null) {
      setState(() => _isLoading = true);

      String finalImageUrl = _existingImageUrl ?? '';

      try {
        // 1. Si el usuario marcó para borrar y no hay nueva imagen seleccionada
        if (_imageWasDeleted && _pickedFile == null) {
          await SupabaseStorageApi.deleteProductImage(_skuController.text.trim());
          finalImageUrl = '';
        }
        // 2. Si se seleccionó una nueva imagen, extraer bytes y subir a Supabase
        else if (_pickedFile != null) {
          final Uint8List bytes = await _pickedFile!.readAsBytes();
          final String skuId    = _skuController.text.trim();
          final String extension = p.extension(_pickedFile!.name);
          
          finalImageUrl = await SupabaseStorageApi.uploadProductImage(
            bytes:    bytes,
            fileName: '$skuId$extension',
          );
        }

        final newProduct = ProductModel(
          skuId: _skuController.text.trim(),
          name: _nameController.text.trim(),
          categoryId: _selectedCategoryId!,
          image: finalImageUrl,
          minStock: int.tryParse(_minStockController.text) ?? 0,
          leadTime: int.tryParse(_leadTimeController.text) ?? 0,
          initialStock: int.tryParse(_initialStockController.text) ?? 0,
        );

        if (widget.productWithStock == null) {
          await ref.read(inventoryControllerProvider).addProduct(newProduct);

          // Registrar costo inicial si el usuario lo indicó
          if (_registrarCosto && _costoInicialController.text.isNotEmpty) {
            final costo = double.tryParse(_costoInicialController.text) ?? 0.0;
            final cantidad = int.tryParse(_initialStockController.text) ?? 0;
            if (costo > 0 && cantidad > 0) {
              await ref.read(costsControllerProvider).addCostEntry(
                productName:  newProduct.name,
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
                    child: Stack(
                      children: [
                        GestureDetector(
                          onTap: () => _showImageSourceActionSheet(context),
                          child: Container(
                            height: 150,
                            width: 150,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: _pickedFile == null && (_existingImageUrl == null || _existingImageUrl!.isEmpty)
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
                                    child: _pickedFile != null
                                        ? Image.network(_pickedFile!.path, fit: BoxFit.cover) // En Web, path es un blob URL
                                        : Image.network(_existingImageUrl!, fit: BoxFit.cover),
                                  ),
                          ),
                        ),
                        if (_pickedFile != null || (_existingImageUrl != null && _existingImageUrl!.isNotEmpty))
                          Positioned(
                            top: 0,
                            right: 0,
                            child: IconButton(
                              icon: const CircleAvatar(
                                radius: 14,
                                backgroundColor: Colors.red,
                                child: Icon(Icons.close, size: 18, color: Colors.white),
                              ),
                              onPressed: () {
                                setState(() {
                                  _pickedFile = null;
                                  _existingImageUrl = null;
                                  _imageWasDeleted = true;
                                });
                              },
                            ),
                          ),
                      ],
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
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                      child: TextFormField(
                        controller: _minStockController,
                        decoration: const InputDecoration(
                            labelText: 'Stock Mínimo', border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                                if (_registrarCosto && v != null && v.isNotEmpty) {
                                  if (double.tryParse(v) == null) return 'Número inválido';
                                  if (double.parse(v) < 0) return 'No puede ser negativo';
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
