import '../repositories/auth_repository.dart';
import '../../../../core/errors/failures.dart';

/// US-005: Cierra sesión de forma segura para AM y Cajero.
class LogoutUseCase {
  final AuthRepository _repository;
  const LogoutUseCase(this._repository);

  Future<({bool success, Failure? failure})> call() => _repository.logout();
}
