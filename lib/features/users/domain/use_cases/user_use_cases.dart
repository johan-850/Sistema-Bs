import '../entities/cashier.dart';
import '../repositories/user_repository.dart';
import '../../../../core/errors/failures.dart';

/// US-003: Crea una cuenta de cajero via Edge Function
class CreateCashierUseCase {
  final UserRepository _repo;
  const CreateCashierUseCase(this._repo);
  Future<({bool success, Failure? failure})> call({
    required String name,
    required String email,
    required String password,
  }) {
    if (name.trim().isEmpty) {
      return Future.value((success: false, failure: const ValidationFailure('El nombre es requerido')));
    }
    return _repo.createCashier(name: name.trim(), email: email.trim(), password: password);
  }
}

/// US-004: Activa/desactiva cajero y fuerza cierre de sesión
class ToggleCashierStatusUseCase {
  final UserRepository _repo;
  const ToggleCashierStatusUseCase(this._repo);
  Future<({bool success, Failure? failure})> call({
    required String cashierId,
    required bool isActive,
  }) =>
      _repo.toggleCashierStatus(cashierId: cashierId, isActive: isActive);
}

/// US-006: Reset de contraseña vía Supabase Auth
class ResetCashierPasswordUseCase {
  final UserRepository _repo;
  const ResetCashierPasswordUseCase(this._repo);
  Future<({bool success, Failure? failure})> call({required String email}) =>
      _repo.resetCashierPassword(email: email);
}

/// US-007: Lista paginada de cajeros
class GetCashiersUseCase {
  final UserRepository _repo;
  const GetCashiersUseCase(this._repo);
  Future<({List<Cashier>? cashiers, int? totalCount, Failure? failure})> call({
    bool? filterActive,
    int page = 0,
    int pageSize = 20,
  }) =>
      _repo.getCashiers(filterActive: filterActive, page: page, pageSize: pageSize);
}
