// ============================================================
// lib/features/products/domain/use_cases/product_use_cases.dart
// Casos de uso de la Épica 3 — CRUD de Productos
// US-013: Registrar producto nuevo con validaciones
// US-014: Listar productos con búsqueda y filtros
// US-015: Editar producto existente
// US-016: Desactivar producto (soft delete)
// ============================================================

import 'dart:typed_data';
import '../repositories/product_repository.dart';
import '../../../../core/errors/failures.dart';

// ── US-014: Listar productos ─────────────────────────────────

/// Obtiene la lista de productos con filtros opcionales.
class GetProductsUseCase {
  final ProductRepository _repository;
  const GetProductsUseCase(this._repository);

  Future<ProductListResult> call({
    String? query,
    String? category,
    bool activeOnly = true,
    int page = 0,
    int pageSize = 20,
  }) =>
      _repository.getProducts(
        query: query,
        category: category,
        activeOnly: activeOnly,
        page: page,
        pageSize: pageSize,
      );
}

// ── US-014: Buscar por código de barras ──────────────────────

/// Busca un producto específico por su código de barras.
class GetProductByBarcodeUseCase {
  final ProductRepository _repository;
  const GetProductByBarcodeUseCase(this._repository);

  Future<ProductResult> call(String barcode) =>
      _repository.getProductByBarcode(barcode);
}

// ── US-013: Registrar producto nuevo ─────────────────────────

/// Crea un nuevo producto con las validaciones de negocio necesarias.
///
/// Validaciones:
///   - El nombre no puede estar vacío
///   - El precio debe ser mayor que 0
///   - El costo no puede ser mayor que el precio
///   - El stock inicial no puede ser negativo
class CreateProductUseCase {
  final ProductRepository _repository;
  const CreateProductUseCase(this._repository);

  Future<ProductResult> call({
    String? barcode,
    required String name,
    String? description,
    required String category,
    required double price,
    required double costPrice,
    required int stock,
    required int minStock,
    required String unit,
    String? imageUrl,
    String? supplier,
  }) async {
    // ── Validaciones de negocio ──
    if (name.trim().isEmpty) {
      return (product: null, failure: const ValidationFailure('El nombre del producto es obligatorio.'));
    }
    if (price <= 0) {
      return (product: null, failure: const ValidationFailure('El precio de venta debe ser mayor a \$0.'));
    }
    if (costPrice < 0) {
      return (product: null, failure: const ValidationFailure('El costo no puede ser negativo.'));
    }
    if (costPrice > price) {
      return (product: null, failure: const ValidationFailure('El costo no puede ser mayor que el precio de venta.'));
    }
    if (stock < 0) {
      return (product: null, failure: const ValidationFailure('El stock inicial no puede ser negativo.'));
    }
    if (minStock < 0) {
      return (product: null, failure: const ValidationFailure('El stock mínimo no puede ser negativo.'));
    }

    // ── Verificar código de barras único ──
    if (barcode != null && barcode.trim().isNotEmpty) {
      final existing = await _repository.getProductByBarcode(barcode.trim());
      if (existing.product != null) {
        return (
          product: null,
          failure: const ValidationFailure('Ya existe un producto con ese código de barras.'),
        );
      }
    }

    return _repository.createProduct(
      barcode: barcode?.trim().isEmpty == true ? null : barcode?.trim(),
      name: name.trim(),
      description: description?.trim(),
      category: category,
      price: price,
      costPrice: costPrice,
      stock: stock,
      minStock: minStock,
      unit: unit,
      imageUrl: imageUrl?.trim(),
      supplier: supplier?.trim(),
    );
  }
}

// ── US-015: Editar producto existente ─────────────────────────

/// Actualiza los campos de un producto existente.
class UpdateProductUseCase {
  final ProductRepository _repository;
  const UpdateProductUseCase(this._repository);

  Future<ProductResult> call({
    required String productId,
    String? barcode,
    String? name,
    String? description,
    String? category,
    double? price,
    double? costPrice,
    int? stock,
    int? minStock,
    String? unit,
    bool? isActive,
    String? imageUrl,
    String? supplier,
  }) async {
    // ── Validaciones parciales (solo los campos enviados) ──
    if (name != null && name.trim().isEmpty) {
      return (product: null, failure: const ValidationFailure('El nombre no puede estar vacío.'));
    }
    if (price != null && price <= 0) {
      return (product: null, failure: const ValidationFailure('El precio debe ser mayor a \$0.'));
    }
    if (costPrice != null && costPrice < 0) {
      return (product: null, failure: const ValidationFailure('El costo no puede ser negativo.'));
    }

    return _repository.updateProduct(
      productId: productId,
      barcode: barcode?.trim(),
      name: name?.trim(),
      description: description?.trim(),
      category: category,
      price: price,
      costPrice: costPrice,
      stock: stock,
      minStock: minStock,
      unit: unit,
      isActive: isActive,
      imageUrl: imageUrl?.trim(),
      supplier: supplier?.trim(),
    );
  }
}

// ── US-016: Desactivar producto (soft delete) ────────────────

/// Desactiva (o reactiva) un producto sin borrarlo de la BD.
class ToggleProductStatusUseCase {
  final ProductRepository _repository;
  const ToggleProductStatusUseCase(this._repository);

  Future<ProductResult> call({
    required String productId,
    required bool isActive,
  }) =>
      _repository.updateProduct(productId: productId, isActive: isActive);
}

// ── Foto de producto ──────────────────────────────────────────

/// Sube una foto de producto (cámara o galería) y devuelve su URL pública.
class UploadProductImageUseCase {
  final ProductRepository _repository;
  const UploadProductImageUseCase(this._repository);

  Future<({String? url, Failure? failure})> call(Uint8List bytes, String fileExt) =>
      _repository.uploadProductImage(bytes, fileExt);
}

/// Borra una foto de producto previamente subida (best-effort).
class DeleteProductImageUseCase {
  final ProductRepository _repository;
  const DeleteProductImageUseCase(this._repository);

  Future<void> call(String imageUrl) => _repository.deleteProductImage(imageUrl);
}
