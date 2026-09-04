// ============================================================
// lib/features/inventory/domain/use_cases/inventory_use_cases.dart
// Casos de uso de la Épica 4 — Gestión de Inventario y Stock
// US-021/US-022: Ajuste (y a futuro, venta) de stock
// US-023: Historial de movimientos
// US-024: Solicitudes de restock
// ============================================================

import '../repositories/inventory_repository.dart';

/// US-021: Ajusta el stock de un producto (entrada o salida).
class AdjustStockUseCase {
  final InventoryRepository _repository;
  const AdjustStockUseCase(this._repository);

  Future<StockMovementResult> call({
    required String productId,
    required String movementType,
    required String reason,
    required int quantity,
    String? notes,
  }) =>
      _repository.adjustStock(
        productId: productId,
        movementType: movementType,
        reason: reason,
        quantity: quantity,
        notes: notes,
      );
}

/// US-023: Obtiene el historial de movimientos de un producto.
class GetStockMovementsUseCase {
  final InventoryRepository _repository;
  const GetStockMovementsUseCase(this._repository);

  Future<StockMovementListResult> call({
    required String productId,
    DateTime? from,
    DateTime? to,
  }) =>
      _repository.getStockMovements(productId: productId, from: from, to: to);
}

/// US-024: Marca un producto como "pedido realizado".
class RequestRestockUseCase {
  final InventoryRepository _repository;
  const RequestRestockUseCase(this._repository);

  Future<RestockRequestResult> call({
    required String productId,
    String? notes,
  }) =>
      _repository.requestRestock(productId: productId, notes: notes);
}

/// US-024: Lista las solicitudes de restock aún no cumplidas.
class GetOpenRestockRequestsUseCase {
  final InventoryRepository _repository;
  const GetOpenRestockRequestsUseCase(this._repository);

  Future<RestockRequestListResult> call() => _repository.getOpenRestockRequests();
}
