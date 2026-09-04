// ============================================================
// lib/features/inventory/domain/entities/restock_request.dart
// Entidad de negocio para "pedido realizado" — US-024
// ============================================================

import 'package:equatable/equatable.dart';

/// Marca de que un producto bajo stock mínimo ya fue solicitado al proveedor.
class RestockRequest extends Equatable {
  final String id;
  final String productId;
  final DateTime requestedAt;
  final String? requestedByName;
  final String? notes;
  final bool fulfilled;

  const RestockRequest({
    required this.id,
    required this.productId,
    required this.requestedAt,
    this.requestedByName,
    this.notes,
    required this.fulfilled,
  });

  @override
  List<Object?> get props => [id, productId, fulfilled];
}
