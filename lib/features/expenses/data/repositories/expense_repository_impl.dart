// ============================================================
// lib/features/expenses/data/repositories/expense_repository_impl.dart
// Implementación del repositorio — convierte excepciones a Failures
// ============================================================

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/expense.dart';
import '../../domain/entities/expense_category.dart';
import '../../domain/repositories/expense_repository.dart';
import '../datasources/expense_remote_datasource.dart';
import '../../../../core/errors/failures.dart';

class ExpenseRepositoryImpl implements ExpenseRepository {
  final ExpenseRemoteDatasource _datasource;
  const ExpenseRepositoryImpl(this._datasource);

  Failure _mapException(Object e) {
    if (e is PostgrestException) {
      if (e.code == '23505') {
        return const ValidationFailure('Ya existe una categoría con ese nombre.');
      }
      if (e.code == '42501' || e.message.contains('policy')) {
        return const PermissionFailure();
      }
      return ValidationFailure(e.message);
    }
    return UnexpectedFailure(e.toString());
  }

  @override
  Future<ExpenseListResult> getShiftExpenses(String cashRegisterId) async {
    try {
      final expenses = await _datasource.getShiftExpenses(cashRegisterId);
      return (expenses: expenses, failure: null);
    } catch (e) {
      return (expenses: <Expense>[], failure: _mapException(e));
    }
  }

  @override
  Future<ExpenseResult> createExpense({
    required String cashRegisterId,
    required String categoryId,
    required String categoryName,
    required double amount,
    required String description,
  }) async {
    try {
      final expense = await _datasource.createExpense(
        cashRegisterId: cashRegisterId,
        categoryId: categoryId,
        categoryName: categoryName,
        amount: amount,
        description: description,
      );
      return (expense: expense, failure: null);
    } catch (e) {
      return (expense: null, failure: _mapException(e));
    }
  }

  @override
  Future<ExpenseResult> updateExpense({
    required String expenseId,
    required String categoryId,
    required String categoryName,
    required double amount,
    required String description,
  }) async {
    try {
      final expense = await _datasource.updateExpense(
        expenseId: expenseId,
        categoryId: categoryId,
        categoryName: categoryName,
        amount: amount,
        description: description,
      );
      return (expense: expense, failure: null);
    } catch (e) {
      return (expense: null, failure: _mapException(e));
    }
  }

  @override
  Future<ExpenseListResult> getExpensesReport({
    String? cashierId,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? categoryId,
  }) async {
    try {
      final expenses = await _datasource.getExpensesReport(
        cashierId: cashierId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        categoryId: categoryId,
      );
      return (expenses: expenses, failure: null);
    } catch (e) {
      return (expenses: <Expense>[], failure: _mapException(e));
    }
  }

  @override
  Future<ExpenseCategoryListResult> getCategories({bool activeOnly = false}) async {
    try {
      final categories = await _datasource.getCategories(activeOnly: activeOnly);
      return (categories: categories, failure: null);
    } catch (e) {
      return (categories: <ExpenseCategory>[], failure: _mapException(e));
    }
  }

  @override
  Future<ExpenseCategoryResult> createCategory({required String name, required String icon}) async {
    try {
      final category = await _datasource.createCategory(name: name, icon: icon);
      return (category: category, failure: null);
    } catch (e) {
      return (category: null, failure: _mapException(e));
    }
  }

  @override
  Future<ExpenseCategoryResult> updateCategory({
    required String categoryId,
    required String name,
    required String icon,
  }) async {
    try {
      final category = await _datasource.updateCategory(categoryId: categoryId, name: name, icon: icon);
      return (category: category, failure: null);
    } catch (e) {
      return (category: null, failure: _mapException(e));
    }
  }

  @override
  Future<ExpenseCategoryResult> setCategoryActive({
    required String categoryId,
    required bool isActive,
  }) async {
    try {
      // US-036: no dejar que quede ninguna categoría activa.
      if (!isActive) {
        final activeCount = await _datasource.countActiveCategories();
        if (activeCount <= 1) {
          return (
            category: null,
            failure: const ValidationFailure(
              'Debe quedar al menos una categoría activa. Activa otra antes de desactivar esta.',
            ),
          );
        }
      }
      final category = await _datasource.setCategoryActive(categoryId: categoryId, isActive: isActive);
      return (category: category, failure: null);
    } catch (e) {
      return (category: null, failure: _mapException(e));
    }
  }

  @override
  Future<Failure?> setCashierExpensesEnabled({
    required String cashierId,
    required bool enabled,
  }) async {
    try {
      await _datasource.setCashierExpensesEnabled(cashierId: cashierId, enabled: enabled);
      return null;
    } catch (e) {
      return _mapException(e);
    }
  }

  @override
  Future<({double total, Failure? failure})> getSalesTotalForPeriod({
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    try {
      final total = await _datasource.getSalesTotalForPeriod(dateFrom: dateFrom, dateTo: dateTo);
      return (total: total, failure: null);
    } catch (e) {
      return (total: 0.0, failure: _mapException(e));
    }
  }
}
