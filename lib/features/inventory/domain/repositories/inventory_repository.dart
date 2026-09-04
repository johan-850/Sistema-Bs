// ============================================================
// lib/features/inventory/domain/repositories/inventory_repository.dart
// Contrato del repositorio de inventario — Clean Architecture
// ============================================================

import '../entities/stock_movement.dart';
import '../entities/restock_request.dart';
import '../../../../core/errors/failures.dart';

typedef StockMovementResult = ({StockMovement? movement, Failure? failure});
typedef StockMovementListResult = ({List<StockMovement> movements, Failure? failure});
typedef RestockRequestResult = ({RestockRequest? request, Failure? failure});
typedef RestockRequestListResult = ({List<RestockRequest> requests, Failure? failure});

/// Contrato de operaciones de inventario y stock (EP-04).
abstract class InventoryRepository {
  /// US-021/US-022: Ajusta el stock de un producto de forma atómica
  /// (vía función RPC en Supabase) y registra el movimiento.
  Future<StockMovementResult> adjustStock({
    required String productId,
    required String movementType,
    required String reason,
    required int quantity,
    String? notes,
  });

  /// US-023: Historial de movimientos de un producto, opcionalmente
  /// filtrado por rango de fechas.
  Future<StockMovementListResult> getStockMovements({
    required String productId,
    DateTime? from,
    DateTime? to,
  });

  /// US-024: Marca un producto como "pedido realizado".
  Future<RestockRequestResult> requestRestock({
    required String productId,
    String? notes,
  });

  /// US-024: Solicitudes de restock aún no cumplidas.
  Future<RestockRequestListResult> getOpenRestockRequests();
}
