// ============================================================
// lib/features/products/presentation/pages/product_form_page.dart
// US-013: Crear producto nuevo con validaciones
// US-015: Editar producto existente
// US-016: Desactivar/reactivar producto
// Diseño: Formulario sectionalizado dark Glassmorphism
// ============================================================

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/scan_feedback_providers.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/barcode_scanner_page.dart';
import '../providers/product_providers.dart';
import '../../domain/entities/product.dart';

class ProductFormPage extends ConsumerStatefulWidget {
  /// Si [productId] es null, estamos en modo creación.
  /// Si no, estamos en modo edición y se carga el producto.
  final String? productId;

  const ProductFormPage({super.key, this.productId});

  @override
  ConsumerState<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends ConsumerState<ProductFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _currencyFmt =
      NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

  // Controladores de texto
  late final TextEditingController _nameCtrl;
  late final TextEditingController _barcodeCtrl;
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _costPriceCtrl;
  late final TextEditingController _stockCtrl;
  late final TextEditingController _minStockCtrl;
  late final TextEditingController _supplierCtrl;

  // Valores de los dropdowns — siempre inicializados a algo válido
  String _selectedCategory = AppConstants.productCategories.first;
  String _selectedUnit = AppConstants.productUnits.first;
  bool _isActive = true;
  bool _isEditMode = false;
  bool _isLoadingProduct = false;
  Product? _existingProduct;

  // Foto de producto
  String? _imageUrl;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _barcodeCtrl = TextEditingController();
    _descriptionCtrl = TextEditingController();
    _priceCtrl = TextEditingController();
    _costPriceCtrl = TextEditingController();
    _stockCtrl = TextEditingController(text: '0');
    _minStockCtrl = TextEditingController(text: '5');
    _supplierCtrl = TextEditingController();

    _isEditMode = widget.productId != null;
    if (_isEditMode) {
      _loadProduct();
    }
  }

  Future<void> _loadProduct() async {
    setState(() => _isLoadingProduct = true);

    final result =
        await ref.read(productRepositoryProvider).getProductById(widget.productId!);

    if (result.product != null) {
      final p = result.product!;
      _existingProduct = p;
      _nameCtrl.text = p.name;
      _barcodeCtrl.text = p.barcode ?? '';
      _descriptionCtrl.text = p.description ?? '';
      _priceCtrl.text = p.price.toStringAsFixed(0);
      _costPriceCtrl.text = p.costPrice.toStringAsFixed(0);
      _stockCtrl.text = p.stock.toString();
      _minStockCtrl.text = p.minStock.toString();
      _imageUrl = p.imageUrl;
      _supplierCtrl.text = p.supplier ?? '';
      // Asegurar que el valor del dropdown exista en la lista
      _selectedCategory = AppConstants.productCategories.contains(p.category)
          ? p.category
          : AppConstants.productCategories.first;
      _selectedUnit = AppConstants.productUnits.contains(p.unit)
          ? p.unit
          : AppConstants.productUnits.first;
      _isActive = p.isActive;
    } else if (result.failure != null) {
      if (mounted) {
        AppSnackbar.error(context, result.failure!.message);
      }
    }

    setState(() => _isLoadingProduct = false);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _barcodeCtrl.dispose();
    _descriptionCtrl.dispose();
    _priceCtrl.dispose();
    _costPriceCtrl.dispose();
    _stockCtrl.dispose();
    _minStockCtrl.dispose();
    _supplierCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(productFormProvider);

    // Escuchar resultados del formulario
    ref.listen<ProductFormState>(productFormProvider, (_, next) {
      if (next.failure != null) {
        AppSnackbar.error(context, next.failure!.message);
      }
      if (next.success) {
        AppSnackbar.success(
          context,
          _isEditMode ? 'Producto actualizado' : 'Producto creado exitosamente',
        );
        ref.read(productListProvider.notifier).refresh();
        context.go('/admin/products');
      }
    });

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(_isEditMode ? 'Editar Producto' : 'Nuevo Producto'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/admin/products'),
        ),
        actions: [
          // US-016: Toggle activo/inactivo (solo en modo edición)
          if (_isEditMode && _existingProduct != null)
            IconButton(
              icon: Icon(
                _isActive ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
                size: 32,
                color: _isActive ? AppColors.success : AppColors.error,
              ),
              tooltip: _isActive ? 'Desactivar producto' : 'Reactivar producto',
              onPressed: _confirmToggleStatus,
            ),
        ],
      ),
      body: _isLoadingProduct
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                children: [
                  // ── Foto de producto ──
                  Center(child: _buildPhotoPicker()),
                  const SizedBox(height: 28),

                  // ── Sección: Información Básica ──
                  const _SectionHeader(
                    icon: Icons.info_outline_rounded,
                    label: 'Información Básica',
                  ),
                  const SizedBox(height: 12),

                  // Nombre del producto
                  TextFormField(
                    controller: _nameCtrl,
                    style: const TextStyle(color: AppColors.textPrimary),
                    maxLength: AppConstants.maxProductNameLength,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del producto *',
                      prefixIcon: Icon(Icons.label_outline_rounded),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'El nombre es obligatorio' : null,
                  ),
                  const SizedBox(height: 8),

                  // Código de barras (US-013/US-018: escaneo con cámara)
                  TextFormField(
                    controller: _barcodeCtrl,
                    style: const TextStyle(color: AppColors.textPrimary),
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Código de barras (opcional)',
                      prefixIcon: const Icon(Icons.qr_code_2_rounded),
                      suffixIcon: IconButton(
                        tooltip: 'Escanear con la cámara',
                        icon: const Icon(Icons.qr_code_scanner_rounded),
                        onPressed: _scanBarcode,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Descripción
                  TextFormField(
                    controller: _descriptionCtrl,
                    style: const TextStyle(color: AppColors.textPrimary),
                    maxLength: AppConstants.maxDescriptionLength,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Descripción (opcional)',
                      prefixIcon: Icon(Icons.description_outlined),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ── Categoría y Unidad (row) ──
                  // Usamos value: en lugar de initialValue: (que no existe en Dropdown)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedCategory,
                          dropdownColor: AppColors.surfaceElevated,
                          isExpanded: true,
                          style: const TextStyle(
                              color: AppColors.textPrimary, fontSize: 14),
                          decoration: const InputDecoration(
                            labelText: 'Categoría',
                            prefixIcon: Icon(Icons.category_outlined),
                          ),
                          items: AppConstants.productCategories
                              .map((c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c,
                                        overflow: TextOverflow.ellipsis),
                                  ))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _selectedCategory = v ?? AppConstants.productCategories.first),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedUnit,
                          dropdownColor: AppColors.surfaceElevated,
                          isExpanded: true,
                          style: const TextStyle(
                              color: AppColors.textPrimary, fontSize: 14),
                          decoration: const InputDecoration(
                            labelText: 'Unidad',
                            prefixIcon: Icon(Icons.straighten_rounded),
                          ),
                          items: AppConstants.productUnits
                              .map((u) => DropdownMenuItem(
                                    value: u,
                                    child: Text(u,
                                        overflow: TextOverflow.ellipsis),
                                  ))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _selectedUnit = v ?? AppConstants.productUnits.first),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // ── Sección: Precios ──
                  const _SectionHeader(
                    icon: Icons.attach_money_rounded,
                    label: 'Precios',
                  ),
                  const SizedBox(height: 12),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _priceCtrl,
                          style: const TextStyle(color: AppColors.textPrimary),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Precio de venta *',
                            prefixIcon: Icon(Icons.sell_outlined),
                            prefixText: '\$ ',
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Obligatorio';
                            final val = double.tryParse(v);
                            if (val == null || val <= 0) return 'Debe ser > \$0';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _costPriceCtrl,
                          style: const TextStyle(color: AppColors.textPrimary),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Costo de compra *',
                            prefixIcon: Icon(Icons.shopping_cart_outlined),
                            prefixText: '\$ ',
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Obligatorio';
                            final val = double.tryParse(v);
                            if (val == null || val < 0) return 'Inválido';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Preview de margen
                  _MarginPreview(
                    price: double.tryParse(_priceCtrl.text) ?? 0,
                    costPrice: double.tryParse(_costPriceCtrl.text) ?? 0,
                    currencyFmt: _currencyFmt,
                  ),

                  const SizedBox(height: 28),

                  // ── Sección: Inventario ──
                  const _SectionHeader(
                    icon: Icons.inventory_2_outlined,
                    label: 'Inventario',
                  ),
                  const SizedBox(height: 12),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _stockCtrl,
                          style: const TextStyle(color: AppColors.textPrimary),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: const InputDecoration(
                            labelText: 'Stock inicial',
                            prefixIcon: Icon(Icons.add_box_outlined),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Obligatorio';
                            final val = int.tryParse(v);
                            if (val == null || val < 0) return 'Inválido';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _minStockCtrl,
                          style: const TextStyle(color: AppColors.textPrimary),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: const InputDecoration(
                            labelText: 'Stock mínimo',
                            prefixIcon: Icon(Icons.warning_amber_rounded),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Obligatorio';
                            final val = int.tryParse(v);
                            if (val == null || val < 0) return 'Inválido';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // ── Sección: Información Adicional ──
                  const _SectionHeader(
                    icon: Icons.more_horiz_rounded,
                    label: 'Información Adicional',
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _supplierCtrl,
                    style: const TextStyle(color: AppColors.textPrimary),
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Proveedor (opcional)',
                      prefixIcon: Icon(Icons.local_shipping_outlined),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── Botón de guardar ──
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: formState.isLoading ? null : _submit,
                      icon: formState.isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : Icon(_isEditMode
                              ? Icons.save_rounded
                              : Icons.add_rounded),
                      label: Text(
                          _isEditMode ? 'Guardar Cambios' : '+ Crear Producto'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  /// US-013/US-018: Escanea un código de barras con la cámara y avisa
  /// de inmediato si ya pertenece a otro producto (la validación
  /// definitiva contra duplicados ocurre igual en CreateProductUseCase).
  Future<void> _scanBarcode() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerPage()),
    );
    if (code == null || !mounted) return;

    setState(() => _barcodeCtrl.text = code);

    final result =
        await ref.read(getProductByBarcodeUseCaseProvider)(code);
    if (!mounted) return;

    final feedback = ref.read(scanFeedbackProvider);
    final found = result.product;

    // US-057: el código duplicado es el caso que el usuario necesita
    // notar — se le avisa también con sonido/vibración de error, no
    // solo con un snackbar que puede pasar desapercibido.
    if (found != null && found.id != _existingProduct?.id) {
      await feedback.failure();
      if (!mounted) return;
      AppSnackbar.warning(
        context,
        'Este código ya pertenece a "${found.name}".',
      );
      return;
    }

    await feedback.success();
  }

  // ── Foto de producto ──────────────────────────────────────────

  bool get _hasImage => _imageUrl != null && _imageUrl!.isNotEmpty;

  Widget _buildPhotoPicker() {
    return GestureDetector(
      onTap: _isUploadingImage ? null : _showImageSourceSheet,
      child: Container(
        width: 96,
        height: 96,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_hasImage)
              CachedNetworkImage(
                imageUrl: _imageUrl!,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => const Icon(
                  Icons.broken_image_outlined,
                  color: AppColors.textDisabled,
                  size: 32,
                ),
              )
            else
              const Icon(
                Icons.add_a_photo_outlined,
                color: AppColors.textSecondary,
                size: 32,
              ),
            if (_isUploadingImage)
              Container(
                color: Colors.black.withValues(alpha: 0.5),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 2,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
              title: const Text('Tomar foto', style: TextStyle(color: AppColors.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUploadImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
              title: const Text('Elegir de galería', style: TextStyle(color: AppColors.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUploadImage(ImageSource.gallery);
              },
            ),
            if (_hasImage)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                title: const Text('Eliminar foto', style: TextStyle(color: AppColors.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  _removeImage();
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    final XFile? picked;
    try {
      picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1024,
        imageQuality: 80,
      );
    } catch (_) {
      if (mounted) AppSnackbar.error(context, 'No se pudo acceder a la cámara/galería.');
      return;
    }
    if (picked == null || !mounted) return;

    setState(() => _isUploadingImage = true);

    final bytes = await picked.readAsBytes();
    final ext = picked.name.contains('.') ? picked.name.split('.').last : 'jpg';
    final result = await ref.read(uploadProductImageUseCaseProvider)(bytes, ext);

    if (!mounted) return;

    if (result.failure != null) {
      setState(() => _isUploadingImage = false);
      AppSnackbar.error(context, result.failure!.message);
      return;
    }

    final oldUrl = _hasImage ? _imageUrl : null;
    setState(() {
      _imageUrl = result.url;
      _isUploadingImage = false;
    });

    // Best-effort: borrar la foto anterior si se reemplazó
    if (oldUrl != null) {
      unawaited(ref.read(deleteProductImageUseCaseProvider)(oldUrl));
    }
  }

  Future<void> _removeImage() async {
    final oldUrl = _imageUrl;
    setState(() => _imageUrl = null);
    if (oldUrl != null && oldUrl.isNotEmpty) {
      unawaited(ref.read(deleteProductImageUseCaseProvider)(oldUrl));
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final notifier = ref.read(productFormProvider.notifier);
    final price = double.tryParse(_priceCtrl.text) ?? 0;
    final costPrice = double.tryParse(_costPriceCtrl.text) ?? 0;

    // Validación cruzada: costo vs precio
    if (costPrice > price) {
      AppSnackbar.warning(
          context, 'El costo no puede ser mayor que el precio de venta.');
      return;
    }

    if (_isEditMode) {
      notifier.update(
        productId: widget.productId!,
        barcode: _barcodeCtrl.text.isEmpty ? null : _barcodeCtrl.text,
        name: _nameCtrl.text,
        description: _descriptionCtrl.text.isEmpty ? null : _descriptionCtrl.text,
        category: _selectedCategory,
        price: price,
        costPrice: costPrice,
        stock: int.tryParse(_stockCtrl.text) ?? 0,
        minStock: int.tryParse(_minStockCtrl.text) ?? 5,
        unit: _selectedUnit,
        imageUrl: _imageUrl ?? '',
        supplier: _supplierCtrl.text.isEmpty ? null : _supplierCtrl.text,
      );
    } else {
      notifier.create(
        barcode: _barcodeCtrl.text.isEmpty ? null : _barcodeCtrl.text,
        name: _nameCtrl.text,
        description: _descriptionCtrl.text.isEmpty ? null : _descriptionCtrl.text,
        category: _selectedCategory,
        price: price,
        costPrice: costPrice,
        stock: int.tryParse(_stockCtrl.text) ?? 0,
        minStock: int.tryParse(_minStockCtrl.text) ?? 5,
        unit: _selectedUnit,
        imageUrl: _imageUrl,
        supplier: _supplierCtrl.text.isEmpty ? null : _supplierCtrl.text,
      );
    }
  }

  /// US-016: Confirmar desactivación/reactivación
  void _confirmToggleStatus() {
    final action = _isActive ? 'desactivar' : 'reactivar';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: Text(
          '${_isActive ? "Desactivar" : "Reactivar"} producto',
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          '¿Estás seguro de que quieres $action "${_existingProduct?.name}"?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _isActive ? AppColors.error : AppColors.success,
            ),
            onPressed: () async {
              Navigator.pop(context);
              final notifier = ref.read(productFormProvider.notifier);
              final success = await notifier.update(
                productId: widget.productId!,
                isActive: !_isActive,
              );
              if (success && mounted) {
                setState(() => _isActive = !_isActive);
              }
            },
            child: Text(_isActive ? 'Desactivar' : 'Reactivar'),
          ),
        ],
      ),
    );
  }
}

// ── Section Header ────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primary, size: 18),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}

// ── Margin Preview ────────────────────────────────────────────

class _MarginPreview extends StatelessWidget {
  final double price;
  final double costPrice;
  final NumberFormat currencyFmt;

  const _MarginPreview({
    required this.price,
    required this.costPrice,
    required this.currencyFmt,
  });

  @override
  Widget build(BuildContext context) {
    final profit = price - costPrice;
    final margin = costPrice > 0 ? (profit / costPrice) * 100 : 0.0;
    final isValid = price > 0 && costPrice >= 0 && costPrice <= price;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isValid
            ? AppColors.success.withValues(alpha: 0.08)
            : AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isValid
              ? AppColors.success.withValues(alpha: 0.3)
              : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.trending_up_rounded : Icons.trending_flat_rounded,
            color: isValid ? AppColors.success : AppColors.textDisabled,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            'Ganancia: ',
            style: TextStyle(
              color: isValid ? AppColors.textSecondary : AppColors.textDisabled,
              fontSize: 13,
            ),
          ),
          Text(
            isValid ? currencyFmt.format(profit) : '--',
            style: TextStyle(
              color: isValid ? AppColors.success : AppColors.textDisabled,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          Text(
            'Margen: ',
            style: TextStyle(
              color: isValid ? AppColors.textSecondary : AppColors.textDisabled,
              fontSize: 13,
            ),
          ),
          Text(
            isValid ? '${margin.toStringAsFixed(1)}%' : '--',
            style: TextStyle(
              color: isValid ? AppColors.primary : AppColors.textDisabled,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
