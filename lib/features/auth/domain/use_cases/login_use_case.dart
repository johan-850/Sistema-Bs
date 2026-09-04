import '../entities/app_user.dart';
import '../repositories/auth_repository.dart';
import '../../../../core/errors/failures.dart';

/// US-001 / US-002: Login para AdminMaster y Cajero.
/// Valida credenciales, detecta rol y retorna el usuario autenticado.
class LoginUseCase {
  final AuthRepository _repository;
  const LoginUseCase(this._repository);

  Future<({AppUser? user, Failure? failure})> call({
    required String email,
    required String password,
  }) async {
    if (email.trim().isEmpty || password.isEmpty) {
      return (user: null, failure: const ValidationFailure('Correo y contraseña requeridos'));
    }
    return _repository.login(email: email.trim(), password: password);
  }
}
