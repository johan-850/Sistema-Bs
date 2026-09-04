// ============================================================
// lib/features/inventory/data/datasources/inventory_remote_datasource.dart
// Datasource remoto — Supabase queries de inventario (EP-04)
// ============================================================

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/stock_movement.dart';
import '../../domain/entities/restock_request.dart';
import '../../../../core/constants/app_constants.dart';

class InventoryRemoteDatasource {
  final SupabaseClient _client;
  const InventoryRemoteDatasource(this._client);

  StockMovement _movementFromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    return StockMovement(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      movementType: json['movement_type'] as String,
      reason: json['reason'] as String,
      quantity: (json['quantity'] as num).toInt(),
      previousStock: (json['previous_stock'] as num).toInt(),
      newStock: (json['new_stock'] as num).toInt(),
      notes: json['notes'] as String?,
      userId: json['user_id'] as String?,
      userName: profile?['name'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  RestockRequest _restockFromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    return RestockRequest(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      requestedAt: DateTime.parse(json['requested_at'] as String),
      requestedByName: profile?['name'] as String?,
      notes: json['notes'] as String?,
      fulfilled: json['fulfilled'] as bool? ?? false,
    );
  }

  // ── US-021/US-022: Ajuste atómico de stock vía RPC ────────────

  Future<StockMovement> adjustStock({
    required String productId,
    required String movementType,
    required String reason,
    required int quantity,
    String? notes,
  }) async {
    final response = await _client.rpc(AppConstants.rpcAdjustStock, params: {
      'p_product_id': productId,
      'p_movement_type': movementType,
      'p_reason': reason,
      'p_quantity': quantity,
      'p_notes': notes,
    });

    return _movementFromJson(response as Map<String, dynamic>);
  }

  // ── US-023: Historial de movimientos ──────────────────────────

  Future<List<StockMovement>> getStockMovements({
    required String productId,
    DateTime? from,
    DateTime? to,
  }) async {
    var query = _client
        .from(AppConstants.tableStockMovements)
        .select('*, profiles(name)')
        .eq('product_id', productId);

    if (from != null) {
      query = query.gte('created_at', from.toIso8601String());
    }
    if (to != null) {
      query = query.lte('created_at', to.toIso8601String());
    }

    final results = await query.order('created_at', ascending: false);
    return results.map<StockMovement>(_movementFromJson).toList();
  }

  // ── US-024: Solicitudes de restock ────────────────────────────

  Future<RestockRequest> requestRestock({
    required String productId,
    String? notes,
  }) async {
    final userId = _client.auth.currentUser?.id;

    final result = await _client
        .from(AppConstants.tableRestockRequests)
        .insert({
          'product_id': productId,
          'requested_by': userId,
          if (notes != null) 'notes': notes,
        })
        .select('*, profiles(name)')
        .single();

    return _restockFromJson(result);
  }

  Future<List<RestockRequest>> getOpenRestockRequests() async {
    final results = await _client
        .from(AppConstants.tableRestockRequests)
        .select('*, profiles(name)')
        .eq('fulfilled', false)
        .order('requested_at', ascending: false);

    return results.map<RestockRequest>(_restockFromJson).toList();
  }
}
