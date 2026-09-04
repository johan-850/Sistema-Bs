// ============================================================
// lib/features/inventory/domain/entities/stock_movement.dart
// Entidad de negocio para movimientos de stock — EP-04
// Cubre: US-021, US-022 (parcial), US-023
// ============================================================

import 'package:equatable/equatable.dart';

/// Registro de auditoría de un ajuste de stock (entrada o salida).
///
/// [reason] puede ser 'venta' (reservado para cuando exista el flujo de
/// ventas de EP-05), 'recepcion', 'merma', 'devolucion' o 'ajuste'.
class StockMovement extends Equatable {
  final String id;
  final String productId;
  final String movementType; // 'entrada' | 'salida'
  final String reason;
  final int quantity;
  final int previousStock;
  final int newStock;
  final String? notes;
  final String? userId;
  final String? userName;
  final DateTime createdAt;

  const StockMovement({
    required this.id,
    required this.productId,
    required this.movementType,
    required this.reason,
    required this.quantity,
    required this.previousStock,
    required this.newStock,
    this.notes,
    this.userId,
    this.userName,
    required this.createdAt,
  });

  bool get isEntrada => movementType == 'entrada';

  @override
  List<Object?> get props => [id, productId, movementType, quantity, createdAt];
}
