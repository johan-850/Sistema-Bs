import '../entities/app_user.dart';
import '../../../../core/errors/failures.dart';

/// Contrato del repositorio de autenticación
abstract class AuthRepository {
  /// Inicia sesión con email y contraseña.
  /// Retorna [AppUser] si el login es exitoso, o un [Failure] tipado.
  Future<({AppUser? user, Failure? failure})> login({
    required String email,
    required String password,
  });

  /// Cierra la sesión activa eliminando el token local.
  Future<({bool success, Failure? failure})> logout();

  /// Obtiene el usuario actual desde la sesión activa (null si no hay sesión).
  Future<AppUser?> getCurrentUser();

  /// Stream del usuario autenticado (null = sin sesión).
  Stream<AppUser?> get authStateChanges;
}
