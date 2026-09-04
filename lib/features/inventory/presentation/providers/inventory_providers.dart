// ============================================================
// lib/features/inventory/presentation/providers/inventory_providers.dart
// Providers de Riverpod para la Épica 4 — Inventario y Stock
// ============================================================

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/datasources/inventory_remote_datasource.dart';
import '../../data/repositories/inventory_repository_impl.dart';
import '../../domain/entities/stock_movement.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../../domain/use_cases/inventory_use_cases.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../products/domain/entities/product.dart';
import '../../../products/domain/use_cases/product_use_cases.dart';
import '../../../products/presentation/providers/product_providers.dart'
    show getProductsUseCaseProvider, StockAlertFilter;
import '../../../../core/errors/failures.dart';

// ── DI ──────────────────────────────────────────────────────────

final inventoryDatasourceProvider = Provider(
  (ref) => InventoryRemoteDatasource(ref.read(supabaseClientProvider)),
);

final inventoryRepositoryProvider = Provider<InventoryRepository>(
  (ref) => InventoryRepositoryImpl(ref.read(inventoryDatasourceProvider)),
);

final adjustStockUseCaseProvider = Provider(
  (ref) => AdjustStockUseCase(ref.read(inventoryRepositoryProvider)),
);

final getStockMovementsUseCaseProvider = Provider(
  (ref) => GetStockMovementsUseCase(ref.read(inventoryRepositoryProvider)),
);

final requestRestockUseCaseProvider = Provider(
  (ref) => RequestRestockUseCase(ref.read(inventoryRepositoryProvider)),
);

final getOpenRestockRequestsUseCaseProvider = Provider(
  (ref) => GetOpenRestockRequestsUseCase(ref.read(inventoryRepositoryProvider)),
);

// ── US-020: Dashboard de inventario (lista + semáforo + realtime) ─

class InventoryListState {
  final List<Product> products;
  final bool isLoading;
  final Failure? failure;
  final String? searchQuery;
  final StockAlertFilter filterStockAlert;

  const InventoryListState({
    this.products = const [],
    this.isLoading = false,
    this.failure,
    this.searchQuery,
    this.filterStockAlert = StockAlertFilter.all,
  });

  bool get hasActiveFilters =>
      (searchQuery != null && searchQuery!.isNotEmpty) ||
      filterStockAlert != StockAlertFilter.all;

  InventoryListState copyWith({
    List<Product>? products,
    bool? isLoading,
    Failure? failure,
    String? searchQuery,
    StockAlertFilter? filterStockAlert,
    bool clearFailure = false,
  }) =>
      InventoryListState(
        products: products ?? this.products,
        isLoading: isLoading ?? this.isLoading,
        failure: clearFailure ? null : (failure ?? this.failure),
        searchQuery: searchQuery ?? this.searchQuery,
        filterStockAlert: filterStockAlert ?? this.filterStockAlert,
      );
}

class InventoryListNotifier extends StateNotifier<InventoryListState> {
  final GetProductsUseCase _getProducts;
  StreamSubscription<List<Map<String, dynamic>>>? _realtimeSub;

  InventoryListNotifier(this._getProducts, SupabaseClient client)
      : super(const InventoryListState()) {
    load();
    // US-020: refresco en tiempo real cuando cambia la tabla products
    // (ej. otro ajuste de stock desde otra sesión).
    _realtimeSub = client.from('products').stream(primaryKey: ['id']).listen((_) {
      load();
    });
  }

  /// Trae todo el catálogo activo (sin paginación de UI: el dashboard
  /// necesita verlo completo para el semáforo, no navegarlo página a
  /// página) y aplica el filtro de alerta client-side.
  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearFailure: true);

    final result = await _getProducts(
      query: state.searchQuery,
      activeOnly: true,
      pageSize: 200,
    );

    if (result.failure != null) {
      state = state.copyWith(isLoading: false, failure: result.failure);
      return;
    }

    final filtered = switch (state.filterStockAlert) {
      StockAlertFilter.all => result.products,
      StockAlertFilter.low =>
        result.products.where((p) => p.isLowStock && !p.isOutOfStock).toList(),
      StockAlertFilter.outOfStock => result.products.where((p) => p.isOutOfStock).toList(),
    };
    state = state.copyWith(isLoading: false, products: filtered);
  }

  Future<void> search(String query) async {
    state = state.copyWith(searchQuery: query.isEmpty ? null : query);
    await load();
  }

  Future<void> filterByStockAlert(StockAlertFilter filter) async {
    state = state.copyWith(filterStockAlert: filter);
    await load();
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    super.dispose();
  }
}

final inventoryListProvider = StateNotifierProvider<InventoryListNotifier, InventoryListState>(
  (ref) => InventoryListNotifier(
    ref.read(getProductsUseCaseProvider),
    ref.read(supabaseClientProvider),
  ),
);

// ── US-021: Formulario de ajuste manual de stock ──────────────

class StockAdjustmentState {
  final bool isLoading;
  final bool success;
  final Failure? failure;

  const StockAdjustmentState({this.isLoading = false, this.success = false, this.failure});

  StockAdjustmentState copyWith({
    bool? isLoading,
    bool? success,
    Failure? failure,
    bool clearFailure = false,
  }) =>
      StockAdjustmentState(
        isLoading: isLoading ?? this.isLoading,
        success: success ?? this.success,
        failure: clearFailure ? null : (failure ?? this.failure),
      );
}

class StockAdjustmentNotifier extends StateNotifier<StockAdjustmentState> {
  final AdjustStockUseCase _adjustStock;
  StockAdjustmentNotifier(this._adjustStock) : super(const StockAdjustmentState());

  Future<bool> adjust({
    required String productId,
    required String movementType,
    required String reason,
    required int quantity,
    String? notes,
  }) async {
    state = state.copyWith(isLoading: true, clearFailure: true);

    final result = await _adjustStock(
      productId: productId,
      movementType: movementType,
      reason: reason,
      quantity: quantity,
      notes: notes,
    );

    if (result.failure != null) {
      state = state.copyWith(isLoading: false, failure: result.failure);
      return false;
    }
    state = state.copyWith(isLoading: false, success: true);
    return true;
  }
}

final stockAdjustmentProvider =
    StateNotifierProvider.autoDispose<StockAdjustmentNotifier, StockAdjustmentState>(
  (ref) => StockAdjustmentNotifier(ref.read(adjustStockUseCaseProvider)),
);

// ── US-023: Historial de movimientos por producto ─────────────

class StockMovementHistoryState {
  final List<StockMovement> movements;
  final bool isLoading;
  final Failure? failure;
  final DateTime? from;
  final DateTime? to;

  const StockMovementHistoryState({
    this.movements = const [],
    this.isLoading = false,
    this.failure,
    this.from,
    this.to,
  });

  bool get hasDateFilter => from != null || to != null;

  StockMovementHistoryState copyWith({
    List<StockMovement>? movements,
    bool? isLoading,
    Failure? failure,
    DateTime? from,
    DateTime? to,
    bool clearFailure = false,
    bool clearDates = false,
  }) =>
      StockMovementHistoryState(
        movements: movements ?? this.movements,
        isLoading: isLoading ?? this.isLoading,
        failure: clearFailure ? null : (failure ?? this.failure),
        from: clearDates ? null : (from ?? this.from),
        to: clearDates ? null : (to ?? this.to),
      );
}

class StockMovementHistoryNotifier extends StateNotifier<StockMovementHistoryState> {
  final GetStockMovementsUseCase _getMovements;
  final String productId;

  StockMovementHistoryNotifier(this._getMovements, this.productId)
      : super(const StockMovementHistoryState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearFailure: true);

    final result = await _getMovements(productId: productId, from: state.from, to: state.to);

    if (result.failure != null) {
      state = state.copyWith(isLoading: false, failure: result.failure);
    } else {
      state = state.copyWith(isLoading: false, movements: result.movements);
    }
  }

  Future<void> filterByDateRange({DateTime? from, DateTime? to}) async {
    if (from == null && to == null) {
      state = state.copyWith(clearDates: true);
    } else {
      state = state.copyWith(from: from, to: to);
    }
    await load();
  }
}

final stockMovementHistoryProvider = StateNotifierProvider.autoDispose
    .family<StockMovementHistoryNotifier, StockMovementHistoryState, String>(
  (ref, productId) =>
      StockMovementHistoryNotifier(ref.read(getStockMovementsUseCaseProvider), productId),
);

// ── US-024: Lista de restock ───────────────────────────────────

class RestockListState {
  final List<Product> lowStockProducts;
  final Set<String> requestedProductIds;
  final bool isLoading;
  final Failure? failure;

  const RestockListState({
    this.lowStockProducts = const [],
    this.requestedProductIds = const {},
    this.isLoading = false,
    this.failure,
  });

  RestockListState copyWith({
    List<Product>? lowStockProducts,
    Set<String>? requestedProductIds,
    bool? isLoading,
    Failure? failure,
    bool clearFailure = false,
  }) =>
      RestockListState(
        lowStockProducts: lowStockProducts ?? this.lowStockProducts,
        requestedProductIds: requestedProductIds ?? this.requestedProductIds,
        isLoading: isLoading ?? this.isLoading,
        failure: clearFailure ? null : (failure ?? this.failure),
      );
}

class RestockListNotifier extends StateNotifier<RestockListState> {
  final GetProductsUseCase _getProducts;
  final GetOpenRestockRequestsUseCase _getOpenRequests;
  final RequestRestockUseCase _requestRestock;

  RestockListNotifier(this._getProducts, this._getOpenRequests, this._requestRestock)
      : super(const RestockListState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearFailure: true);

    final productsResult = await _getProducts(activeOnly: true, pageSize: 200);
    if (productsResult.failure != null) {
      state = state.copyWith(isLoading: false, failure: productsResult.failure);
      return;
    }

    final requestsResult = await _getOpenRequests();

    state = state.copyWith(
      isLoading: false,
      lowStockProducts: productsResult.products.where((p) => p.isLowStock).toList(),
      requestedProductIds: requestsResult.requests.map((r) => r.productId).toSet(),
      failure: requestsResult.failure,
    );
  }

  /// US-024: Marca un producto como "pedido realizado".
  Future<bool> markRequested(String productId) async {
    final result = await _requestRestock(productId: productId);
    if (result.failure != null) {
      state = state.copyWith(failure: result.failure);
      return false;
    }
    state = state.copyWith(
      requestedProductIds: {...state.requestedProductIds, productId},
    );
    return true;
  }
}

final restockListProvider = StateNotifierProvider<RestockListNotifier, RestockListState>(
  (ref) => RestockListNotifier(
    ref.read(getProductsUseCaseProvider),
    ref.read(getOpenRestockRequestsUseCaseProvider),
    ref.read(requestRestockUseCaseProvider),
  ),
);
