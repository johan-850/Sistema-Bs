import '../../domain/entities/cashier.dart';

/// Model de cajero mapeado desde la tabla profiles de Supabase
class CashierModel extends Cashier {
  const CashierModel({
    required super.id,
    required super.email,
    required super.name,
    required super.isActive,
    super.expensesEnabled,
    super.lastLogin,
    required super.createdAt,
    super.createdBy,
  });

  factory CashierModel.fromMap(Map<String, dynamic> map) => CashierModel(
        id: map['id'] as String,
        email: map['email'] as String,
        name: map['name'] as String? ?? '',
        isActive: map['is_active'] as bool? ?? true,
        expensesEnabled: map['expenses_enabled'] as bool? ?? true,
        lastLogin: map['last_login'] != null
            ? DateTime.parse(map['last_login'] as String).toLocal()
            : null,
        createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
        createdBy: map['created_by'] as String?,
      );
}
