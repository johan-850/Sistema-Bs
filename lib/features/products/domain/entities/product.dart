// ============================================================
// lib/features/products/domain/entities/product.dart
// Entidad de negocio para el catálogo de productos
// Cubre: US-013, US-014, US-015, US-016
// ============================================================

import 'package:equatable/equatable.dart';

/// Representa un producto del catálogo de la abarrotería.
///
/// Campos principales:
///   - [barcode]: código de barras (opcional, único si existe)
///   - [price]: precio de venta al público
///   - [costPrice]: costo de compra (para cálculo de margen)
///   - [stock]: existencia actual
///   - [minStock]: umbral mínimo para alerta de stock bajo
///   - [unit]: unidad de medida ('unidad', 'kg', 'lt', etc.)
class Product extends Equatable {
  final String id;
  final String? barcode;
  final String name;
  final String? description;
  final String category;
  final double price;
  final double costPrice;
  final int stock;
  final int minStock;
  final String unit;
  final bool isActive;
  final String? imageUrl;
  final String? supplier;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Product({
    required this.id,
    this.barcode,
    required this.name,
    this.description,
    required this.category,
    required this.price,
    required this.costPrice,
    required this.stock,
    required this.minStock,
    required this.unit,
    required this.isActive,
    this.imageUrl,
    this.supplier,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  // ── Helpers de negocio ──────────────────────────────────────

  /// Margen de ganancia en porcentaje: ((precio - costo) / costo) * 100
  /// Retorna 0.0 si el costo es 0 para evitar división por cero.
  double get marginPercent =>
      costPrice > 0 ? ((price - costPrice) / costPrice) * 100 : 0.0;

  /// Ganancia absoluta por unidad vendida
  double get profitPerUnit => price - costPrice;

  /// True si el stock actual está por debajo o igual al mínimo definido
  bool get isLowStock => stock <= minStock;

  /// True si el stock es exactamente 0
  bool get isOutOfStock => stock <= 0;

  Product copyWith({
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
    DateTime? updatedAt,
  }) =>
      Product(
        id: id,
        barcode: barcode ?? this.barcode,
        name: name ?? this.name,
        description: description ?? this.description,
        category: category ?? this.category,
        price: price ?? this.price,
        costPrice: costPrice ?? this.costPrice,
        stock: stock ?? this.stock,
        minStock: minStock ?? this.minStock,
        unit: unit ?? this.unit,
        isActive: isActive ?? this.isActive,
        imageUrl: imageUrl ?? this.imageUrl,
        supplier: supplier ?? this.supplier,
        createdBy: createdBy,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  List<Object?> get props => [id, barcode, name, isActive];
}
