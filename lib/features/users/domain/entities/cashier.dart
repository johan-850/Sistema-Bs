import 'package:equatable/equatable.dart';

/// Entidad de cajero para gestión por parte del AdminMaster
class Cashier extends Equatable {
  final String id;
  final String email;
  final String name;
  final bool isActive;

  /// EP-06 (US-038): si el AdminMaster le habilitó el módulo de gastos.
  final bool expensesEnabled;
  final DateTime? lastLogin;
  final DateTime createdAt;
  final String? createdBy; // ID del AM que lo creó

  const Cashier({
    required this.id,
    required this.email,
    required this.name,
    required this.isActive,
    this.expensesEnabled = true,
    this.lastLogin,
    required this.createdAt,
    this.createdBy,
  });

  Cashier copyWith({bool? isActive, bool? expensesEnabled}) => Cashier(
        id: id,
        email: email,
        name: name,
        isActive: isActive ?? this.isActive,
        expensesEnabled: expensesEnabled ?? this.expensesEnabled,
        lastLogin: lastLogin,
        createdAt: createdAt,
        createdBy: createdBy,
      );

  @override
  List<Object?> get props => [id, email, isActive];
}
