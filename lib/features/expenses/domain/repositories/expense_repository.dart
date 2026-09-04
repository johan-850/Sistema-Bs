// ============================================================
// lib/features/expenses/domain/repositories/expense_repository.dart
// Contrato del repositorio de gastos — Clean Architecture
// ============================================================

import '../entities/expense.dart';
import '../entities/expense_category.dart';
import '../../../../core/errors/failures.dart';

typedef ExpenseResult = ({Expense? expense, Failure? failure});
typedef ExpenseListResult = ({List<Expense> expenses, Failure? failure});
typedef ExpenseCategoryResult = ({ExpenseCategory? category, Failure? failure});
typedef ExpenseCategoryListResult = ({List<ExpenseCategory> categories, Failure? failure});

abstract class ExpenseRepository {
  // ── Gastos (US-034/US-035) ───────────────────────────────
  Future<ExpenseListResult> getShiftExpenses(String cashRegisterId);

  Future<ExpenseResult> createExpense({
    required String cashRegisterId,
    required String categoryId,
    required String categoryName,
    required double amount,
    required String description,
  });

  Future<ExpenseResult> updateExpense({
    required String expenseId,
    required String categoryId,
    required String categoryName,
    required double amount,
    required String description,
  });

  /// US-037: reporte consolidado para el AdminMaster.
  Future<ExpenseListResult> getExpensesReport({
    String? cashierId,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? categoryId,
  });

  // ── Categorías (US-036) ───────────────────────────────────
  Future<ExpenseCategoryListResult> getCategories({bool activeOnly = false});

  Future<ExpenseCategoryResult> createCategory({required String name, required String icon});

  Future<ExpenseCategoryResult> updateCategory({
    required String categoryId,
    required String name,
    required String icon,
  });

  /// Activa/desactiva una categoría. Si [isActive] es false, el
  /// repositorio valida antes que quede al menos una categoría activa
  /// (US-036) y devuelve [ValidationFailure] si esta sería la última.
  Future<ExpenseCategoryResult> setCategoryActive({
    required String categoryId,
    required bool isActive,
  });

  // ── Permiso por cajero (US-038) ───────────────────────────
  Future<Failure?> setCashierExpensesEnabled({
    required String cashierId,
    required bool enabled,
  });

  /// US-037: total de ventas del período, para la alerta de "gastos
  /// > X% del total de ventas" en el reporte consolidado. Vive acá (y
  /// no en SaleRepository) porque es una lectura auxiliar exclusiva de
  /// esa alerta, no una operación de ventas en sí.
  Future<({double total, Failure? failure})> getSalesTotalForPeriod({
    DateTime? dateFrom,
    DateTime? dateTo,
  });
}
