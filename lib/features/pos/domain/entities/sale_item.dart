// ============================================================
// lib/features/pos/domain/entities/sale_item.dart
// Ítem de una venta histórica — EP-08 (US-044/US-047/US-049)
// El flujo de cobro usa CartItem en memoria; esta entidad es solo
// para releer sale_items ya persistidos (historial del AdminMaster).
// ============================================================

import 'package:equatable/equatable.dart';

class SaleItem extends Equatable {
  final String id;
  final String saleId;
  final String productId;

  /// Snapshot del momento de la venta — no cambia si el producto se
  /// edita o archiva después.
  final String productName;
  final int quantity;
  final double unitPrice;
  final double subtotal;

  /// US-049: si el producto sigue existiendo pero está archivado
  /// (`products.is_active = false`) hoy — se resuelve en el datasource,
  /// no viene de sale_items.
  final bool isProductArchived;

  const SaleItem({
    required this.id,
    required this.saleId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    this.isProductArchived = false,
  });

  @override
  List<Object?> get props => [id];
}
