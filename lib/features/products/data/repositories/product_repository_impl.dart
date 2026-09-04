// ============================================================
// lib/features/products/data/repositories/product_repository_impl.dart
// Implementación del repositorio — convierte excepciones a Failures
// ============================================================

import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/product.dart';
import '../../domain/repositories/product_repository.dart';
import '../datasources/product_remote_datasource.dart';
import '../../../../core/errors/failures.dart';

class ProductRepositoryImpl implements ProductRepository {
  final ProductRemoteDatasource _datasource;
  const ProductRepositoryImpl(this._datasource);

  /// Mapea excepciones de Supabase/red a Failures tipados.
  Failure _mapException(Object e) {
    if (e is PostgrestException) {
      // Código de barras duplicado (violación UNIQUE)
      if (e.code == '23505') {
        return const ValidationFailure('Ya existe un producto con ese código de barras.');
      }
      if (e.code == '42501' || e.message.contains('policy')) {
        return const PermissionFailure();
      }
      return ServerFailure(e.message);
    }
    return UnexpectedFailure(e.toString());
  }

  @override
  Future<ProductListResult> getProducts({
    String? query,
    String? category,
    bool activeOnly = true,
    int page = 0,
    int pageSize = 20,
  }) async {
    try {
      final products = await _datasource.getProducts(
        query: query,
        category: category,
        activeOnly: activeOnly,
        page: page,
        pageSize: pageSize,
      );
      return (products: products, failure: null);
    } catch (e) {
      return (products: <Product>[], failure: _mapException(e));
    }
  }

  @override
  Future<ProductResult> getProductById(String productId) async {
    try {
      final product = await _datasource.getProductById(productId);
      return (product: product, failure: null);
    } catch (e) {
      return (product: null, failure: _mapException(e));
    }
  }

  @override
  Future<ProductResult> getProductByBarcode(String barcode) async {
    try {
      final product = await _datasource.getProductByBarcode(barcode);
      return (product: product, failure: null);
    } catch (e) {
      return (product: null, failure: _mapException(e));
    }
  }

  @override
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
  }) async {
    try {
      final product = await _datasource.createProduct(
        barcode: barcode,
        name: name,
        description: description,
        category: category,
        price: price,
        costPrice: costPrice,
        stock: stock,
        minStock: minStock,
        unit: unit,
        imageUrl: imageUrl,
        supplier: supplier,
      );
      return (product: product, failure: null);
    } catch (e) {
      return (product: null, failure: _mapException(e));
    }
  }

  @override
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
  }) async {
    try {
      final product = await _datasource.updateProduct(
        productId: productId,
        barcode: barcode,
        name: name,
        description: description,
        category: category,
        price: price,
        costPrice: costPrice,
        stock: stock,
        minStock: minStock,
        unit: unit,
        isActive: isActive,
        imageUrl: imageUrl,
        supplier: supplier,
      );
      return (product: product, failure: null);
    } catch (e) {
      return (product: null, failure: _mapException(e));
    }
  }

  @override
  Future<({String? url, Failure? failure})> uploadProductImage(
    Uint8List bytes,
    String fileExt,
  ) async {
    try {
      final url = await _datasource.uploadProductImage(bytes, fileExt);
      return (url: url, failure: null);
    } catch (e) {
      return (url: null, failure: _mapException(e));
    }
  }

  @override
  Future<void> deleteProductImage(String imageUrl) =>
      _datasource.deleteProductImage(imageUrl);
}
