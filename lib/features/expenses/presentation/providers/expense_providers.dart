// ============================================================
// lib/features/expenses/presentation/providers/expense_providers.dart
// Providers de Riverpod para la Épica 6 — Gastos de Caja
// ============================================================

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/datasources/expense_remote_datasource.dart';
import '../../data/repositories/expense_repository_impl.dart';
import '../../domain/entities/expense.dart';
import '../../domain/entities/expense_category.dart';
import '../../domain/repositories/expense_repository.dart';
import '../../domain/use_cases/expense_use_cases.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/failures.dart';

// ── DI ──────────────────────────────────────────────────────────

final expenseDatasourceProvider = Provider(
  (ref) => ExpenseRemoteDatasource(ref.read(supabaseClientProvider)),
);

final expenseRepositoryProvider = Provider<ExpenseRepository>(
  (ref) => ExpenseRepositoryImpl(ref.read(expenseDatasourceProvider)),
);

final getShiftExpensesUseCaseProvider = Provider(
  (ref) => GetShiftExpensesUseCase(ref.read(expenseRepositoryProvider)),
);
final createExpenseUseCaseProvider = Provider(
  (ref) => CreateExpenseUseCase(ref.read(expenseRepositoryProvider)),
);
final updateExpenseUseCaseProvider = Provider(
  (ref) => UpdateExpenseUseCase(ref.read(expenseRepositoryProvider)),
);
final getExpensesReportUseCaseProvider = Provider(
  (ref) => GetExpensesReportUseCase(ref.read(expenseRepositoryProvider)),
);
final getExpenseCategoriesUseCaseProvider = Provider(
  (ref) => GetExpenseCategoriesUseCase(ref.read(expenseRepositoryProvider)),
);
final createExpenseCategoryUseCaseProvider = Provider(
  (ref) => CreateExpenseCategoryUseCase(ref.read(expenseRepositoryProvider)),
);
final updateExpenseCategoryUseCaseProvider = Provider(
  (ref) => UpdateExpenseCategoryUseCase(ref.read(expenseRepositoryProvider)),
);
final setExpenseCategoryActiveUseCaseProvider = Provider(
  (ref) => SetExpenseCategoryActiveUseCase(ref.read(expenseRepositoryProvider)),
);
final setCashierExpensesEnabledUseCaseProvider = Provider(
  (ref) => SetCashierExpensesEnabledUseCase(ref.read(expenseRepositoryProvider)),
);
final getSalesTotalForPeriodUseCaseProvider = Provider(
  (ref) => GetSalesTotalForPeriodUseCase(ref.read(expenseRepositoryProvider)),
);

// ── US-036: categorías de gasto ──────────────────────────────────
// Sin realtime a propósito: cambian poco y cada pantalla que las usa
// ya llama refresh() después de crear/editar/(des)activar.

class ExpenseCategoriesState {
  final List<ExpenseCategory> categories;
  final bool isLoading;
  final Failure? failure;

  const ExpenseCategoriesState({this.categories = const [], this.isLoading = false, this.failure});

  List<ExpenseCategory> get active => categories.where((c) => c.isActive).toList();

  ExpenseCategoriesState copyWith({
    List<ExpenseCategory>? categories,
    bool? isLoading,
    Failure? failure,
    bool clearFailure = false,
  }) =>
      ExpenseCategoriesState(
        categories: categories ?? this.categories,
        isLoading: isLoading ?? this.isLoading,
        failure: clearFailure ? null : (failure ?? this.failure),
      );
}

class ExpenseCategoriesNotifier extends StateNotifier<ExpenseCategoriesState> {
  final GetExpenseCategoriesUseCase _getCategories;
  ExpenseCategoriesNotifier(this._getCategories) : super(const ExpenseCategoriesState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearFailure: true);
    final result = await _getCategories();
    state = result.failure != null
        ? state.copyWith(isLoading: false, failure: result.failure)
        : state.copyWith(isLoading: false, categories: result.categories);
  }

  Future<void> refresh() => load();
}

final expenseCategoriesProvider =
    StateNotifierProvider<ExpenseCategoriesNotifier, ExpenseCategoriesState>(
  (ref) => ExpenseCategoriesNotifier(ref.read(getExpenseCategoriesUseCaseProvider)),
);

// ── US-034/US-035: gastos del turno activo ───────────────────────
// Realtime sobre la tabla completa (mismo patrón que InventoryListNotifier),
// pero el resultado ya viene filtrado por cash_register_id desde la query.

class ShiftExpensesState {
  final List<Expense> expenses;
  final bool isLoading;
  final Failure? failure;

  const ShiftExpensesState({this.expenses = const [], this.isLoading = false, this.failure});

  double get total => expenses.fold(0.0, (sum, e) => sum + e.amount);

  ShiftExpensesState copyWith({
    List<Expense>? expenses,
    bool? isLoading,
    Failure? failure,
    bool clearFailure = false,
  }) =>
      ShiftExpensesState(
        expenses: expenses ?? this.expenses,
        isLoading: isLoading ?? this.isLoading,
        failure: clearFailure ? null : (failure ?? this.failure),
      );
}

class ShiftExpensesNotifier extends StateNotifier<ShiftExpensesState> {
  final GetShiftExpensesUseCase _getShiftExpenses;
  final String cashRegisterId;
  StreamSubscription<List<Map<String, dynamic>>>? _realtimeSub;

  ShiftExpensesNotifier(this._getShiftExpenses, this.cashRegisterId, SupabaseClient client)
      : super(const ShiftExpensesState()) {
    load();
    _realtimeSub = client.from(AppConstants.tableExpenses).stream(primaryKey: ['id']).listen((_) {
      load();
    });
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearFailure: true);
    final result = await _getShiftExpenses(cashRegisterId);
    state = result.failure != null
        ? state.copyWith(isLoading: false, failure: result.failure)
        : state.copyWith(isLoading: false, expenses: result.expenses);
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    super.dispose();
  }
}

final shiftExpensesProvider = StateNotifierProvider.autoDispose
    .family<ShiftExpensesNotifier, ShiftExpensesState, String>(
  (ref, cashRegisterId) => ShiftExpensesNotifier(
    ref.read(getShiftExpensesUseCaseProvider),
    cashRegisterId,
    ref.read(supabaseClientProvider),
  ),
);

// ── US-037: reporte consolidado (AdminMaster) ────────────────────

class ExpensesReportState {
  final List<Expense> expenses;
  final bool isLoading;
  final Failure? failure;
  final String? filterCashierId;
  final DateTime? filterDateFrom;
  final DateTime? filterDateTo;
  final String? filterCategoryId;
  final double salesTotal;

  const ExpensesReportState({
    this.expenses = const [],
    this.isLoading = false,
    this.failure,
    this.filterCashierId,
    this.filterDateFrom,
    this.filterDateTo,
    this.filterCategoryId,
    this.salesTotal = 0,
  });

  double get expensesTotal => expenses.fold(0.0, (sum, e) => sum + e.amount);

  /// Porcentaje de gastos sobre ventas del período filtrado (0 si no
  /// hay ventas, para no dividir por cero).
  double get expensesPercentOfSales => salesTotal > 0 ? (expensesTotal / salesTotal) * 100 : 0;

  Map<String, double> get totalsByCategory {
    final map = <String, double>{};
    for (final e in expenses) {
      map[e.categoryName] = (map[e.categoryName] ?? 0) + e.amount;
    }
    return map;
  }

  ExpensesReportState copyWith({
    List<Expense>? expenses,
    bool? isLoading,
    Failure? failure,
    bool clearFailure = false,
    String? filterCashierId,
    bool clearFilterCashier = false,
    DateTime? filterDateFrom,
    bool clearFilterDateFrom = false,
    DateTime? filterDateTo,
    bool clearFilterDateTo = false,
    String? filterCategoryId,
    bool clearFilterCategory = false,
    double? salesTotal,
  }) =>
      ExpensesReportState(
        expenses: expenses ?? this.expenses,
        isLoading: isLoading ?? this.isLoading,
        failure: clearFailure ? null : (failure ?? this.failure),
        filterCashierId: clearFilterCashier ? null : (filterCashierId ?? this.filterCashierId),
        filterDateFrom: clearFilterDateFrom ? null : (filterDateFrom ?? this.filterDateFrom),
        filterDateTo: clearFilterDateTo ? null : (filterDateTo ?? this.filterDateTo),
        filterCategoryId: clearFilterCategory ? null : (filterCategoryId ?? this.filterCategoryId),
        salesTotal: salesTotal ?? this.salesTotal,
      );
}

class ExpensesReportNotifier extends StateNotifier<ExpensesReportState> {
  final GetExpensesReportUseCase _getReport;
  final GetSalesTotalForPeriodUseCase _getSalesTotal;

  ExpensesReportNotifier(this._getReport, this._getSalesTotal) : super(const ExpensesReportState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearFailure: true);

    final result = await _getReport(
      cashierId: state.filterCashierId,
      dateFrom: state.filterDateFrom,
      dateTo: state.filterDateTo,
      categoryId: state.filterCategoryId,
    );
    if (result.failure != null) {
      state = state.copyWith(isLoading: false, failure: result.failure);
      return;
    }

    final salesResult = await _getSalesTotal(dateFrom: state.filterDateFrom, dateTo: state.filterDateTo);
    state = state.copyWith(isLoading: false, expenses: result.expenses, salesTotal: salesResult.total);
  }

  Future<void> filterByCashier(String? cashierId) async {
    state = state.copyWith(filterCashierId: cashierId, clearFilterCashier: cashierId == null);
    await load();
  }

  Future<void> filterByCategory(String? categoryId) async {
    state = state.copyWith(filterCategoryId: categoryId, clearFilterCategory: categoryId == null);
    await load();
  }

  Future<void> filterByDateRange(DateTime? from, DateTime? to) async {
    state = state.copyWith(
      filterDateFrom: from,
      clearFilterDateFrom: from == null,
      filterDateTo: to,
      clearFilterDateTo: to == null,
    );
    await load();
  }

  Future<void> clearFilters() async {
    state = const ExpensesReportState();
    await load();
  }
}

final expensesReportProvider =
    StateNotifierProvider.autoDispose<ExpensesReportNotifier, ExpensesReportState>(
  (ref) => ExpensesReportNotifier(
    ref.read(getExpensesReportUseCaseProvider),
    ref.read(getSalesTotalForPeriodUseCaseProvider),
  ),
);

// ── US-034/US-035: formulario de registro/edición de un gasto ────

class RegisterExpenseState {
  final bool isLoading;
  final bool success;
  final Failure? failure;

  const RegisterExpenseState({this.isLoading = false, this.success = false, this.failure});

  RegisterExpenseState copyWith({bool? isLoading, bool? success, Failure? failure, bool clearFailure = false}) =>
      RegisterExpenseState(
        isLoading: isLoading ?? this.isLoading,
        success: success ?? this.success,
        failure: clearFailure ? null : (failure ?? this.failure),
      );
}

class RegisterExpenseNotifier extends StateNotifier<RegisterExpenseState> {
  final CreateExpenseUseCase _create;
  final UpdateExpenseUseCase _update;
  RegisterExpenseNotifier(this._create, this._update) : super(const RegisterExpenseState());

  Future<void> create({
    required String cashRegisterId,
    required String categoryId,
    required String categoryName,
    required double amount,
    required String description,
  }) async {
    state = state.copyWith(isLoading: true, clearFailure: true);
    final result = await _create(
      cashRegisterId: cashRegisterId,
      categoryId: categoryId,
      categoryName: categoryName,
      amount: amount,
      description: description,
    );
    state = result.failure != null
        ? state.copyWith(isLoading: false, failure: result.failure)
        : state.copyWith(isLoading: false, success: true);
  }

  Future<void> update({
    required String expenseId,
    required String categoryId,
    required String categoryName,
    required double amount,
    required String description,
  }) async {
    state = state.copyWith(isLoading: true, clearFailure: true);
    final result = await _update(
      expenseId: expenseId,
      categoryId: categoryId,
      categoryName: categoryName,
      amount: amount,
      description: description,
    );
    state = result.failure != null
        ? state.copyWith(isLoading: false, failure: result.failure)
        : state.copyWith(isLoading: false, success: true);
  }
}

final registerExpenseProvider =
    StateNotifierProvider.autoDispose<RegisterExpenseNotifier, RegisterExpenseState>(
  (ref) => RegisterExpenseNotifier(
    ref.read(createExpenseUseCaseProvider),
    ref.read(updateExpenseUseCaseProvider),
  ),
);
