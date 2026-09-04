// ============================================================
// lib/features/expenses/domain/use_cases/expense_use_cases.dart
// Casos de uso de gastos de caja — US-034 a US-038
// ============================================================

import '../repositories/expense_repository.dart';
import '../../../../core/errors/failures.dart';

class GetShiftExpensesUseCase {
  final ExpenseRepository _repository;
  const GetShiftExpensesUseCase(this._repository);

  Future<ExpenseListResult> call(String cashRegisterId) => _repository.getShiftExpenses(cashRegisterId);
}

class CreateExpenseUseCase {
  final ExpenseRepository _repository;
  const CreateExpenseUseCase(this._repository);

  Future<ExpenseResult> call({
    required String cashRegisterId,
    required String categoryId,
    required String categoryName,
    required double amount,
    required String description,
  }) =>
      _repository.createExpense(
        cashRegisterId: cashRegisterId,
        categoryId: categoryId,
        categoryName: categoryName,
        amount: amount,
        description: description,
      );
}

class UpdateExpenseUseCase {
  final ExpenseRepository _repository;
  const UpdateExpenseUseCase(this._repository);

  Future<ExpenseResult> call({
    required String expenseId,
    required String categoryId,
    required String categoryName,
    required double amount,
    required String description,
  }) =>
      _repository.updateExpense(
        expenseId: expenseId,
        categoryId: categoryId,
        categoryName: categoryName,
        amount: amount,
        description: description,
      );
}

class GetExpensesReportUseCase {
  final ExpenseRepository _repository;
  const GetExpensesReportUseCase(this._repository);

  Future<ExpenseListResult> call({
    String? cashierId,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? categoryId,
  }) =>
      _repository.getExpensesReport(
        cashierId: cashierId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        categoryId: categoryId,
      );
}

class GetExpenseCategoriesUseCase {
  final ExpenseRepository _repository;
  const GetExpenseCategoriesUseCase(this._repository);

  Future<ExpenseCategoryListResult> call({bool activeOnly = false}) =>
      _repository.getCategories(activeOnly: activeOnly);
}

class CreateExpenseCategoryUseCase {
  final ExpenseRepository _repository;
  const CreateExpenseCategoryUseCase(this._repository);

  Future<ExpenseCategoryResult> call({required String name, required String icon}) =>
      _repository.createCategory(name: name, icon: icon);
}

class UpdateExpenseCategoryUseCase {
  final ExpenseRepository _repository;
  const UpdateExpenseCategoryUseCase(this._repository);

  Future<ExpenseCategoryResult> call({
    required String categoryId,
    required String name,
    required String icon,
  }) =>
      _repository.updateCategory(categoryId: categoryId, name: name, icon: icon);
}

class SetExpenseCategoryActiveUseCase {
  final ExpenseRepository _repository;
  const SetExpenseCategoryActiveUseCase(this._repository);

  Future<ExpenseCategoryResult> call({required String categoryId, required bool isActive}) =>
      _repository.setCategoryActive(categoryId: categoryId, isActive: isActive);
}

class SetCashierExpensesEnabledUseCase {
  final ExpenseRepository _repository;
  const SetCashierExpensesEnabledUseCase(this._repository);

  Future<Failure?> call({required String cashierId, required bool enabled}) =>
      _repository.setCashierExpensesEnabled(cashierId: cashierId, enabled: enabled);
}

class GetSalesTotalForPeriodUseCase {
  final ExpenseRepository _repository;
  const GetSalesTotalForPeriodUseCase(this._repository);

  Future<({double total, Failure? failure})> call({DateTime? dateFrom, DateTime? dateTo}) =>
      _repository.getSalesTotalForPeriod(dateFrom: dateFrom, dateTo: dateTo);
}
