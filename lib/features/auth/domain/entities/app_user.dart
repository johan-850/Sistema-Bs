import 'package:equatable/equatable.dart';

/// Entidad de usuario autenticado en la app
class AppUser extends Equatable {
  final String id;
  final String email;
  final String name;
  final String role; // 'adminmaster' | 'cajero'
  final bool isActive;

  /// EP-06 (US-038): si es cajero, si el AdminMaster le habilitó el
  /// módulo de gastos. Sin efecto para AdminMaster.
  final bool expensesEnabled;
  final DateTime? lastLogin;
  final DateTime createdAt;

  const AppUser({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.isActive,
    this.expensesEnabled = true,
    this.lastLogin,
    required this.createdAt,
  });

  bool get isAdmin => role == 'adminmaster';
  bool get isCajero => role == 'cajero';

  AppUser copyWith({
    String? name,
    bool? isActive,
    bool? expensesEnabled,
    DateTime? lastLogin,
  }) =>
      AppUser(
        id: id,
        email: email,
        name: name ?? this.name,
        role: role,
        isActive: isActive ?? this.isActive,
        expensesEnabled: expensesEnabled ?? this.expensesEnabled,
        lastLogin: lastLogin ?? this.lastLogin,
        createdAt: createdAt,
      );

  @override
  List<Object?> get props => [id, email, role, isActive];
}
