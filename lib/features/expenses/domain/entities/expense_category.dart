// ============================================================
// lib/features/expenses/domain/entities/expense_category.dart
// Categoría de gasto configurable por el AdminMaster — US-036
// ============================================================

import 'package:equatable/equatable.dart';

class ExpenseCategory extends Equatable {
  final String id;
  final String name;
  final String icon;
  final bool isActive;

  const ExpenseCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.isActive,
  });

  @override
  List<Object?> get props => [id, name, icon, isActive];
}
