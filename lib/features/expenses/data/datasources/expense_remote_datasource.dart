// ============================================================
// lib/features/expenses/data/datasources/expense_remote_datasource.dart
// Datasource remoto — tablas expenses / expense_categories
// ============================================================

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/expense.dart';
import '../../domain/entities/expense_category.dart';
import '../../../../core/constants/app_constants.dart';

class ExpenseRemoteDatasource {
  final SupabaseClient _client;
  const ExpenseRemoteDatasource(this._client);

  // ── Deserialización ─────────────────────────────────────────

  Expense _fromJson(Map<String, dynamic> json) => Expense(
        id: json['id'] as String,
        cashierId: json['cashier_id'] as String,
        cashRegisterId: json['cash_register_id'] as String,
        categoryId: json['category_id'] as String,
        categoryName: json['category_name'] as String,
        amount: (json['amount'] as num).toDouble(),
        description: json['description'] as String? ?? '',
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  ExpenseCategory _categoryFromJson(Map<String, dynamic> json) => ExpenseCategory(
        id: json['id'] as String,
        name: json['name'] as String,
        icon: json['icon'] as String,
        isActive: json['is_active'] as bool? ?? true,
      );

  // ── Gastos (US-034/US-035) ───────────────────────────────

  Future<List<Expense>> getShiftExpenses(String cashRegisterId) async {
    final result = await _client
        .from(AppConstants.tableExpenses)
        .select()
        .eq('cash_register_id', cashRegisterId)
        .order('created_at', ascending: false);
    return (result as List).map((e) => _fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Expense> createExpense({
    required String cashRegisterId,
    required String categoryId,
    required String categoryName,
    required double amount,
    required String description,
  }) async {
    final result = await _client
        .from(AppConstants.tableExpenses)
        .insert({
          'cash_register_id': cashRegisterId,
          'category_id': categoryId,
          'category_name': categoryName,
          'amount': amount,
          'description': description,
        })
        .select()
        .single();
    return _fromJson(result);
  }

  Future<Expense> updateExpense({
    required String expenseId,
    required String categoryId,
    required String categoryName,
    required double amount,
    required String description,
  }) async {
    final result = await _client
        .from(AppConstants.tableExpenses)
        .update({
          'category_id': categoryId,
          'category_name': categoryName,
          'amount': amount,
          'description': description,
        })
        .eq('id', expenseId)
        .select()
        .single();
    return _fromJson(result);
  }

  /// US-037: reporte consolidado — filtros opcionales.
  Future<List<Expense>> getExpensesReport({
    String? cashierId,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? categoryId,
  }) async {
    var q = _client.from(AppConstants.tableExpenses).select();

    if (cashierId != null) q = q.eq('cashier_id', cashierId);
    if (categoryId != null) q = q.eq('category_id', categoryId);
    if (dateFrom != null) q = q.gte('created_at', dateFrom.toUtc().toIso8601String());
    if (dateTo != null) q = q.lte('created_at', dateTo.toUtc().toIso8601String());

    final result = await q.order('created_at', ascending: false);
    return (result as List).map((e) => _fromJson(e as Map<String, dynamic>)).toList();
  }

  // ── Categorías (US-036) ───────────────────────────────────

  Future<List<ExpenseCategory>> getCategories({bool activeOnly = false}) async {
    var q = _client.from(AppConstants.tableExpenseCategories).select();
    if (activeOnly) q = q.eq('is_active', true);
    final result = await q.order('name');
    return (result as List).map((e) => _categoryFromJson(e as Map<String, dynamic>)).toList();
  }

  Future<int> countActiveCategories() async {
    final result = await _client
        .from(AppConstants.tableExpenseCategories)
        .select('id')
        .eq('is_active', true);
    return (result as List).length;
  }

  Future<ExpenseCategory> createCategory({required String name, required String icon}) async {
    final result = await _client
        .from(AppConstants.tableExpenseCategories)
        .insert({'name': name, 'icon': icon})
        .select()
        .single();
    return _categoryFromJson(result);
  }

  Future<ExpenseCategory> updateCategory({
    required String categoryId,
    required String name,
    required String icon,
  }) async {
    final result = await _client
        .from(AppConstants.tableExpenseCategories)
        .update({'name': name, 'icon': icon})
        .eq('id', categoryId)
        .select()
        .single();
    return _categoryFromJson(result);
  }

  Future<ExpenseCategory> setCategoryActive({
    required String categoryId,
    required bool isActive,
  }) async {
    final result = await _client
        .from(AppConstants.tableExpenseCategories)
        .update({'is_active': isActive})
        .eq('id', categoryId)
        .select()
        .single();
    return _categoryFromJson(result);
  }

  /// US-037: suma `sales.total` en el rango — no hay RPC de agregación,
  /// así que se suma en Dart (volumen esperado de una tienda pequeña).
  Future<double> getSalesTotalForPeriod({DateTime? dateFrom, DateTime? dateTo}) async {
    var q = _client.from(AppConstants.tableSales).select('total');
    if (dateFrom != null) q = q.gte('created_at', dateFrom.toUtc().toIso8601String());
    if (dateTo != null) q = q.lte('created_at', dateTo.toUtc().toIso8601String());

    final result = await q;
    return (result as List)
        .fold<double>(0, (sum, row) => sum + ((row as Map<String, dynamic>)['total'] as num).toDouble());
  }

  // ── Permiso por cajero (US-038) ───────────────────────────

  /// Mismo patrón que toggleCashierStatus (EP-01): actualiza el perfil
  /// y deja un log de auditoría en la tabla ya existente.
  Future<void> setCashierExpensesEnabled({
    required String cashierId,
    required bool enabled,
  }) async {
    await _client
        .from(AppConstants.tableProfiles)
        .update({'expenses_enabled': enabled})
        .eq('id', cashierId);

    final currentUserId = _client.auth.currentUser?.id;
    await _client.from(AppConstants.tableUserActivityLogs).insert({
      'user_id': cashierId,
      'action': enabled ? 'expenses_enabled' : 'expenses_disabled',
      'performed_by': currentUserId,
      'metadata': {'timestamp': DateTime.now().toUtc().toIso8601String()},
    });
  }
}
