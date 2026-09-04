// ============================================================
// lib/features/expenses/domain/entities/expense.dart
// Gasto de caja registrado por el cajero — US-034/US-035
// ============================================================

import 'package:equatable/equatable.dart';

class Expense extends Equatable {
  final String id;
  final String cashierId;
  final String cashRegisterId;
  final String categoryId;

  /// Snapshot del nombre de la categoría al momento del gasto — no
  /// cambia si la categoría se renombra después (mismo criterio que
  /// sale_items.product_name).
  final String categoryName;
  final double amount;
  final String description;
  final DateTime createdAt;

  const Expense({
    required this.id,
    required this.cashierId,
    required this.cashRegisterId,
    required this.categoryId,
    required this.categoryName,
    required this.amount,
    required this.description,
    required this.createdAt,
  });

  /// US-035: editable solo dentro de la ventana configurada por el
  /// AdminMaster (store_settings.expense_edit_window_minutes).
  bool isEditableWithin(Duration window) =>
      DateTime.now().toUtc().difference(createdAt.toUtc()) < window;

  @override
  List<Object?> get props => [id];
}
