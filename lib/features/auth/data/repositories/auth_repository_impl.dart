import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';
import '../../../../core/errors/failures.dart';

/// Implementación concreta del AuthRepository usando Supabase
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDatasource _datasource;
  const AuthRepositoryImpl(this._datasource);

  @override
  Future<({AppUser? user, Failure? failure})> login({
    required String email,
    required String password,
  }) async {
    try {
      final user = await _datasource.signIn(email: email, password: password);
      return (user: user, failure: null);
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('desactivada') || msg.contains('disabled')) {
        return (user: null, failure: const AccountDisabledFailure());
      }
      if (msg.contains('invalid') || msg.contains('invalid_credentials')) {
        return (user: null, failure: const AuthFailure('Correo o contraseña incorrectos.'));
      }
      return (user: null, failure: AuthFailure(e.message));
    } on Exception {
      return (user: null, failure: const NetworkFailure());
    }
  }

  @override
  Future<({bool success, Failure? failure})> logout() async {
    try {
      await _datasource.signOut();
      return (success: true, failure: null);
    } on Exception {
      return (success: false, failure: const UnexpectedFailure());
    }
  }

  @override
  Future<AppUser?> getCurrentUser() => _datasource.getCurrentUserProfile();

  @override
  Stream<AppUser?> get authStateChanges => _datasource.authStateStream;
}
