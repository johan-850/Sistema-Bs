// ============================================================
// lib/features/products/domain/repositories/product_repository.dart
// Contrato del repositorio de productos — Clean Architecture
// ============================================================

import 'dart:typed_data';
import '../entities/product.dart';
import '../../../../core/errors/failures.dart';

/// Result record para operaciones que devuelven un solo producto
typedef ProductResult = ({Product? product, Failure? failure});

/// Result record para listados de productos
typedef ProductListResult = ({List<Product> products, Failure? failure});

/// Contrato que define las operaciones de persistencia de productos.
/// La implementación concreta vive en la capa data/.
abstract class ProductRepository {
  /// Obtiene la lista de productos con soporte de paginación y búsqueda.
  ///
  /// [query]: texto libre para filtrar por nombre o código de barras.
  /// [category]: filtra por categoría exacta (null = todas).
  /// [activeOnly]: si es true, solo devuelve productos activos.
  /// [page]: número de página (0-indexed).
  /// [pageSize]: cantidad de resultados por página.
  Future<ProductListResult> getProducts({
    String? query,
    String? category,
    bool activeOnly = true,
    int page = 0,
    int pageSize = 20,
  });

  /// Obtiene un producto por su ID.
  Future<ProductResult> getProductById(String productId);

  /// Busca un producto por su código de barras.
  /// Retorna product=null si no se encuentra (no es un error).
  Future<ProductResult> getProductByBarcode(String barcode);

  /// Crea un nuevo producto. Devuelve el producto creado con su ID generado.
  Future<ProductResult> createProduct({
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
  });

  /// Actualiza un producto existente. Solo envía los campos modificados.
  Future<ProductResult> updateProduct({
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
  });

  /// Sube una foto de producto y devuelve su URL pública.
  Future<({String? url, Failure? failure})> uploadProductImage(
    Uint8List bytes,
    String fileExt,
  );

  /// Borra una foto de producto previamente subida (best-effort).
  Future<void> deleteProductImage(String imageUrl);
}
