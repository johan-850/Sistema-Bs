/// Jerarquía de fallos tipados para propagación limpia de errores
sealed class Failure {
  final String message;
  const Failure(this.message);
}

/// Credenciales incorrectas / sesión expirada
class AuthFailure extends Failure {
  const AuthFailure(super.message);
}

/// Cuenta desactivada por el AdminMaster
class AccountDisabledFailure extends Failure {
  const AccountDisabledFailure()
      : super('Tu cuenta está desactivada. Contacta al administrador.');
}

/// Error de red o timeout
class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Sin conexión. Verifica tu red.']);
}

/// Error de servidor (Supabase PostgrestException)
class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

/// Error de permisos (RLS)
class PermissionFailure extends Failure {
  const PermissionFailure([super.message = 'No tienes permisos para esta acción.']);
}

/// Validación de formulario fallida
class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

/// Error inesperado
class UnexpectedFailure extends Failure {
  const UnexpectedFailure([super.message = 'Ocurrió un error inesperado.']);
}
