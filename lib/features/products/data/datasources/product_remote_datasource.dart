// ============================================================
// lib/features/products/data/datasources/product_remote_datasource.dart
// Datasource remoto — Supabase queries para la tabla products
// ============================================================

import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/product.dart';
import '../../../../core/constants/app_constants.dart';

/// Acceso directo a la tabla `products` en Supabase.
/// Toda la lógica de serialización/deserialización vive aquí.
class ProductRemoteDatasource {
  final SupabaseClient _client;
  const ProductRemoteDatasource(this._client);

  // ── Deserialización ─────────────────────────────────────────

  /// Convierte un mapa JSON de Supabase a la entidad [Product].
  Product _fromJson(Map<String, dynamic> json) => Product(
        id: json['id'] as String,
        barcode: json['barcode'] as String?,
        name: json['name'] as String,
        description: json['description'] as String?,
        category: (json['category'] as String?) ?? 'General',
        price: (json['price'] as num).toDouble(),
        costPrice: (json['cost_price'] as num).toDouble(),
        stock: (json['stock'] as num).toInt(),
        minStock: (json['min_stock'] as num).toInt(),
        unit: (json['unit'] as String?) ?? 'unidad',
        isActive: json['is_active'] as bool? ?? true,
        imageUrl: json['image_url'] as String?,
        supplier: json['supplier'] as String?,
        createdBy: json['created_by'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  // ── US-014: Listar productos ───────────────────────────────

  /// Obtiene productos con paginación, búsqueda y filtro de categoría.
  ///
  /// La búsqueda con [query] filtra por nombre (ilike) o código de barras exacto.
  /// Los filtros se aplican ANTES de order() y range() para mantener
  /// el tipo PostgrestFilterBuilder correcto.
  Future<List<Product>> getProducts({
    String? query,
    String? category,
    bool activeOnly = true,
    int page = 0,
    int pageSize = 20,
  }) async {
    var q = _client.from(AppConstants.tableProducts).select();

    // Filtro de estado
    if (activeOnly) {
      q = q.eq('is_active', true);
    }

    // Filtro de categoría
    if (category != null && category.isNotEmpty) {
      q = q.eq('category', category);
    }

    // Búsqueda por nombre o código de barras
    if (query != null && query.trim().isNotEmpty) {
      final term = query.trim();
      // Buscar por código de barras exacto O nombre parcial (ilike)
      q = q.or('barcode.eq.$term,name.ilike.%$term%');
    }

    // Ordenar y paginar DESPUÉS de aplicar filtros
    final results = await q
        .order('name', ascending: true)
        .range(page * pageSize, (page + 1) * pageSize - 1);

    return results.map<Product>(_fromJson).toList();
  }

  // ── US-014: Obtener por ID ─────────────────────────────────

  /// Obtiene un producto por su UUID.
  Future<Product> getProductById(String productId) async {
    final result = await _client
        .from(AppConstants.tableProducts)
        .select()
        .eq('id', productId)
        .single();

    return _fromJson(result);
  }

  // ── US-014: Buscar por código de barras ────────────────────

  /// Busca un producto por su código de barras.
  /// Retorna null si no se encuentra (no es un error).
  Future<Product?> getProductByBarcode(String barcode) async {
    final result = await _client
        .from(AppConstants.tableProducts)
        .select()
        .eq('barcode', barcode)
        .maybeSingle();

    if (result == null) return null;
    return _fromJson(result);
  }

  // ── US-013: Crear producto ─────────────────────────────────

  /// Inserta un nuevo producto en la tabla `products`.
  Future<Product> createProduct({
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
    final userId = _client.auth.currentUser?.id;

    final payload = <String, dynamic>{
      'name': name,
      'category': category,
      'price': price,
      'cost_price': costPrice,
      'stock': stock,
      'min_stock': minStock,
      'unit': unit,
      'is_active': true,
      if (barcode != null) 'barcode': barcode,
      if (description != null) 'description': description,
      if (imageUrl != null) 'image_url': imageUrl,
      if (supplier != null) 'supplier': supplier,
      if (userId != null) 'created_by': userId,
    };

    final result = await _client
        .from(AppConstants.tableProducts)
        .insert(payload)
        .select()
        .single();

    return _fromJson(result);
  }

  // ── US-015: Actualizar producto ────────────────────────────

  /// Actualiza campos específicos de un producto existente.
  /// Solo envía los campos que no son null para minimizar la query.
  Future<Product> updateProduct({
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
    final payload = <String, dynamic>{
      if (barcode != null) 'barcode': barcode,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (category != null) 'category': category,
      if (price != null) 'price': price,
      if (costPrice != null) 'cost_price': costPrice,
      if (stock != null) 'stock': stock,
      if (minStock != null) 'min_stock': minStock,
      if (unit != null) 'unit': unit,
      if (isActive != null) 'is_active': isActive,
      if (imageUrl != null) 'image_url': imageUrl,
      if (supplier != null) 'supplier': supplier,
    };

    final result = await _client
        .from(AppConstants.tableProducts)
        .update(payload)
        .eq('id', productId)
        .select()
        .single();

    return _fromJson(result);
  }

  // ── Foto de producto ────────────────────────────────────────

  /// Sube una imagen al bucket de Storage y devuelve su URL pública.
  Future<String> uploadProductImage(Uint8List bytes, String fileExt) async {
    final path = 'products/${const Uuid().v4()}.$fileExt';
    await _client.storage
        .from(AppConstants.storageBucketProductImages)
        .uploadBinary(path, bytes, fileOptions: const FileOptions(upsert: true));

    return _client.storage
        .from(AppConstants.storageBucketProductImages)
        .getPublicUrl(path);
  }

  /// Borra una imagen del bucket a partir de su URL pública.
  /// Best-effort: si falla (ej. URL externa que no vive en nuestro bucket),
  /// no se propaga el error porque no es crítico para el flujo del usuario.
  Future<void> deleteProductImage(String imageUrl) async {
    try {
      final marker = '/object/public/${AppConstants.storageBucketProductImages}/';
      final idx = imageUrl.indexOf(marker);
      if (idx == -1) return;
      final path = imageUrl.substring(idx + marker.length);
      await _client.storage
          .from(AppConstants.storageBucketProductImages)
          .remove([path]);
    } catch (_) {
      /* No crítico */
    }
  }
}
