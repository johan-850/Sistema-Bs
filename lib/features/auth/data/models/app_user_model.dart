import '../../domain/entities/app_user.dart';

/// Model de datos: convierte el Map de Supabase (tabla profiles) a AppUser
class AppUserModel extends AppUser {
  const AppUserModel({
    required super.id,
    required super.email,
    required super.name,
    required super.role,
    required super.isActive,
    super.expensesEnabled,
    super.lastLogin,
    required super.createdAt,
  });

  factory AppUserModel.fromMap(Map<String, dynamic> map) {
    return AppUserModel(
      id: map['id'] as String,
      email: map['email'] as String,
      name: map['name'] as String? ?? '',
      role: map['role'] as String? ?? 'cajero',
      isActive: map['is_active'] as bool? ?? true,
      expensesEnabled: map['expenses_enabled'] as bool? ?? true,
      lastLogin: map['last_login'] != null
          ? DateTime.parse(map['last_login'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'email': email,
        'name': name,
        'role': role,
        'is_active': isActive,
        'expenses_enabled': expensesEnabled,
        'last_login': lastLogin?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };
}
