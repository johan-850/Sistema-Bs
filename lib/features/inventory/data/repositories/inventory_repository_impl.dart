// ============================================================
// lib/features/inventory/data/repositories/inventory_repository_impl.dart
// Implementación del repositorio — convierte excepciones a Failures
// ============================================================

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/stock_movement.dart';
import '../../domain/entities/restock_request.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../datasources/inventory_remote_datasource.dart';
import '../../../../core/errors/failures.dart';

class InventoryRepositoryImpl implements InventoryRepository {
  final InventoryRemoteDatasource _datasource;
  const InventoryRepositoryImpl(this._datasource);

  /// Mapea excepciones de Supabase/red a Failures tipados.
  /// Los errores de la función `adjust_product_stock` (RAISE EXCEPTION)
  /// llegan como PostgrestException con un mensaje ya listo para el
  /// usuario (ej. "El ajuste dejaría el stock en negativo").
  Failure _mapException(Object e) {
    if (e is PostgrestException) {
      if (e.code == '42501' || e.message.contains('policy')) {
        return const PermissionFailure();
      }
      return ValidationFailure(e.message);
    }
    return UnexpectedFailure(e.toString());
  }

  @override
  Future<StockMovementResult> adjustStock({
    required String productId,
    required String movementType,
    required String reason,
    required int quantity,
    String? notes,
  }) async {
    try {
      final movement = await _datasource.adjustStock(
        productId: productId,
        movementType: movementType,
        reason: reason,
        quantity: quantity,
        notes: notes,
      );
      return (movement: movement, failure: null);
    } catch (e) {
      return (movement: null, failure: _mapException(e));
    }
  }

  @override
  Future<StockMovementListResult> getStockMovements({
    required String productId,
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final movements = await _datasource.getStockMovements(
        productId: productId,
        from: from,
        to: to,
      );
      return (movements: movements, failure: null);
    } catch (e) {
      return (movements: const <StockMovement>[], failure: _mapException(e));
    }
  }

  @override
  Future<RestockRequestResult> requestRestock({
    required String productId,
    String? notes,
  }) async {
    try {
      final request = await _datasource.requestRestock(productId: productId, notes: notes);
      return (request: request, failure: null);
    } catch (e) {
      return (request: null, failure: _mapException(e));
    }
  }

  @override
  Future<RestockRequestListResult> getOpenRestockRequests() async {
    try {
      final requests = await _datasource.getOpenRestockRequests();
      return (requests: requests, failure: null);
    } catch (e) {
      return (requests: const <RestockRequest>[], failure: _mapException(e));
    }
  }
}
