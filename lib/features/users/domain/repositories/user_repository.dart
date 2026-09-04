import '../entities/cashier.dart';
import '../../../../core/errors/failures.dart';

/// Contrato del repositorio de gestión de cajeros
abstract class UserRepository {
  /// US-003: Crea una cuenta de cajero (vía Edge Function)
  Future<({bool success, Failure? failure})> createCashier({
    required String name,
    required String email,
    required String password,
  });

  /// US-004: Activa o desactiva la cuenta de un cajero
  Future<({bool success, Failure? failure})> toggleCashierStatus({
    required String cashierId,
    required bool isActive,
  });

  /// US-006: Dispara el correo de reset de contraseña
  Future<({bool success, Failure? failure})> resetCashierPassword({
    required String email,
  });

  /// US-007: Lista paginada de cajeros con filtros
  Future<({List<Cashier>? cashiers, int? totalCount, Failure? failure})> getCashiers({
    bool? filterActive,
    int page = 0,
    int pageSize = 20,
  });

  /// US-007: Exporta cajeros a CSV
  Future<({String? csvContent, Failure? failure})> exportCashiersToCSV();
}
