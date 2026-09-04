// ============================================================
// lib/features/pos/domain/entities/sale.dart
// Venta confirmada — US-030, US-031
// ============================================================

import 'package:equatable/equatable.dart';

class Sale extends Equatable {
  final String id;
  final double total;
  final String paymentMethod; // 'efectivo' | 'transferencia' | 'mixto'
  final double? cashAmount;
  final double? transferAmount;
  final double? changeAmount;
  final String? receiptPhotoUrl;

  /// EP-08: campos que el flujo de cobro nunca necesitó (el cajero ya
  /// sabe quién es y en qué caja está) pero que sí hacen falta para el
  /// historial del AdminMaster.
  final String? cashierId;
  final String? cashierName;
  final String? cashRegisterId;

  /// 'completed' es el único valor posible hoy — no existe todavía un
  /// flujo para anular una venta ya confirmada (solo cancelar el
  /// carrito *antes* de cobrar). Se deja listo para cuando exista.
  final String status;

  /// EP-08 (US-044): resumen de "producto xCantidad" para mostrar en la
  /// fila del historial sin abrir el detalle — viene embebido en la
  /// misma consulta de getSalesHistory (join a sale_items). Vacío en
  /// cualquier otro contexto (ej. el que devuelve confirm_sale).
  final List<String> itemsPreview;

  final DateTime createdAt;

  const Sale({
    required this.id,
    required this.total,
    required this.paymentMethod,
    this.cashAmount,
    this.transferAmount,
    this.changeAmount,
    this.receiptPhotoUrl,
    this.cashierId,
    this.cashierName,
    this.cashRegisterId,
    this.status = 'completed',
    this.itemsPreview = const [],
    required this.createdAt,
  });

  bool get isCash => paymentMethod == 'efectivo';
  bool get isMixed => paymentMethod == 'mixto';
  bool get isTransfer => paymentMethod == 'transferencia';
  bool get isCancelled => status != 'completed';

  @override
  List<Object?> get props => [id];
}
