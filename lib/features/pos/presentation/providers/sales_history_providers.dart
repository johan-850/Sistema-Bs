// ============================================================
// lib/features/pos/presentation/providers/sales_history_providers.dart
// Historial y reportes de ventas — EP-08 (AdminMaster)
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/sale.dart';
import '../../domain/repositories/sale_repository.dart';
import '../../domain/use_cases/sale_use_cases.dart';
import '../../../../core/errors/failures.dart';
import 'checkout_provider.dart' show saleRepositoryProvider;

// ── DI ──────────────────────────────────────────────────────────

final getSalesHistoryUseCaseProvider = Provider(
  (ref) => GetSalesHistoryUseCase(ref.read(saleRepositoryProvider)),
);

final getSaleDetailUseCaseProvider = Provider(
  (ref) => GetSaleDetailUseCase(ref.read(saleRepositoryProvider)),
);

final getSalesKpisUseCaseProvider = Provider(
  (ref) => GetSalesKpisUseCase(ref.read(saleRepositoryProvider)),
);

// ── US-044: historial con filtros ─────────────────────────────

class SalesHistoryState {
  final List<Sale> sales;
  final bool isLoading;
  final int currentPage;
  final Failure? failure;

  final DateTime? filterDateFrom;
  final DateTime? filterDateTo;
  final String? filterCashierId;
  final String? filterPaymentMethod;
  final double? filterMinAmount;
  final double? filterMaxAmount;
  final String? filterSearchId;

  const SalesHistoryState({
    this.sales = const [],
    this.isLoading = false,
    this.currentPage = 0,
    this.failure,
    this.filterDateFrom,
    this.filterDateTo,
    this.filterCashierId,
    this.filterPaymentMethod,
    this.filterMinAmount,
    this.filterMaxAmount,
    this.filterSearchId,
  });

  bool get hasActiveFilters =>
      filterDateFrom != null ||
      filterDateTo != null ||
      filterCashierId != null ||
      filterPaymentMethod != null ||
      filterMinAmount != null ||
      filterMaxAmount != null ||
      (filterSearchId != null && filterSearchId!.isNotEmpty);

  SalesHistoryState copyWith({
    List<Sale>? sales,
    bool? isLoading,
    int? currentPage,
    Failure? failure,
    bool clearFailure = false,
    DateTime? filterDateFrom,
    DateTime? filterDateTo,
    String? filterCashierId,
    String? filterPaymentMethod,
    double? filterMinAmount,
    double? filterMaxAmount,
    String? filterSearchId,
    bool clearFilters = false,
  }) =>
      SalesHistoryState(
        sales: sales ?? this.sales,
        isLoading: isLoading ?? this.isLoading,
        currentPage: currentPage ?? this.currentPage,
        failure: clearFailure ? null : (failure ?? this.failure),
        filterDateFrom: clearFilters ? null : (filterDateFrom ?? this.filterDateFrom),
        filterDateTo: clearFilters ? null : (filterDateTo ?? this.filterDateTo),
        filterCashierId: clearFilters ? null : (filterCashierId ?? this.filterCashierId),
        filterPaymentMethod: clearFilters ? null : (filterPaymentMethod ?? this.filterPaymentMethod),
        filterMinAmount: clearFilters ? null : (filterMinAmount ?? this.filterMinAmount),
        filterMaxAmount: clearFilters ? null : (filterMaxAmount ?? this.filterMaxAmount),
        filterSearchId: clearFilters ? null : (filterSearchId ?? this.filterSearchId),
      );
}

class SalesHistoryNotifier extends StateNotifier<SalesHistoryState> {
  final GetSalesHistoryUseCase _getHistory;
  SalesHistoryNotifier(this._getHistory) : super(const SalesHistoryState()) {
    load();
  }

  Future<void> load({int page = 0}) async {
    state = state.copyWith(isLoading: true, currentPage: page, clearFailure: true);

    final result = await _getHistory(
      dateFrom: state.filterDateFrom,
      dateTo: state.filterDateTo,
      cashierId: state.filterCashierId,
      paymentMethod: state.filterPaymentMethod,
      minAmount: state.filterMinAmount,
      maxAmount: state.filterMaxAmount,
      searchId: state.filterSearchId,
      page: page,
    );

    state = result.failure != null
        ? state.copyWith(isLoading: false, failure: result.failure)
        : state.copyWith(isLoading: false, sales: result.sales);
  }

  Future<void> searchById(String? id) async {
    state = state.copyWith(filterSearchId: id, clearFilters: id == null || id.isEmpty);
    await load();
  }

  Future<void> applyFilters({
    DateTime? dateFrom,
    DateTime? dateTo,
    String? cashierId,
    String? paymentMethod,
    double? minAmount,
    double? maxAmount,
  }) async {
    state = SalesHistoryState(
      filterDateFrom: dateFrom,
      filterDateTo: dateTo,
      filterCashierId: cashierId,
      filterPaymentMethod: paymentMethod,
      filterMinAmount: minAmount,
      filterMaxAmount: maxAmount,
    );
    await load();
  }

  Future<void> clearFilters() async {
    state = const SalesHistoryState();
    await load();
  }
}

final salesHistoryProvider =
    StateNotifierProvider.autoDispose<SalesHistoryNotifier, SalesHistoryState>(
  (ref) => SalesHistoryNotifier(ref.read(getSalesHistoryUseCaseProvider)),
);

// ── US-047/US-049: detalle de una venta ───────────────────────

final saleDetailProvider = FutureProvider.autoDispose.family<SaleDetailResult, String>((ref, saleId) {
  return ref.read(getSaleDetailUseCaseProvider)(saleId);
});

// ── US-048: KPIs del dashboard ────────────────────────────────

final salesKpisProvider = FutureProvider<SalesKpis?>((ref) async {
  final result = await ref.read(getSalesKpisUseCaseProvider)();
  return result.kpis;
});
