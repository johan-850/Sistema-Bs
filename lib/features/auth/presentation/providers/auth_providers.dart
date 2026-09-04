import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/use_cases/login_use_case.dart';
import '../../domain/use_cases/logout_use_case.dart';
import '../../../../core/errors/failures.dart';

// ── Infraestructura ──────────────────────────────────────────
final supabaseClientProvider = Provider<SupabaseClient>(
  (_) => Supabase.instance.client,
);

final authDatasourceProvider = Provider<AuthRemoteDatasource>(
  (ref) => AuthRemoteDatasource(ref.read(supabaseClientProvider)),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(ref.read(authDatasourceProvider)),
);

// ── Casos de uso ─────────────────────────────────────────────
final loginUseCaseProvider = Provider(
  (ref) => LoginUseCase(ref.read(authRepositoryProvider)),
);
final logoutUseCaseProvider = Provider(
  (ref) => LogoutUseCase(ref.read(authRepositoryProvider)),
);

// ── Estado de sesión (stream) ─────────────────────────────────
final authStateStreamProvider = StreamProvider<AppUser?>(
  (ref) => ref.read(authRepositoryProvider).authStateChanges,
);

// ── Usuario actual sincrónico ─────────────────────────────────
final currentUserProvider = FutureProvider<AppUser?>(
  (ref) => ref.read(authRepositoryProvider).getCurrentUser(),
);

// ── Rol del usuario (helper) ──────────────────────────────────
final currentUserRoleProvider = Provider<String?>((ref) {
  return ref
      .watch(authStateStreamProvider)
      .valueOrNull
      ?.role;
});

// ── Stream para GoRouter refresh ──────────────────────────────
final authStateChangesProvider = StreamProvider<AuthState>(
  (ref) => ref.read(supabaseClientProvider).auth.onAuthStateChange,
);

// ── Estado del formulario de login ────────────────────────────
class LoginState {
  final bool isLoading;
  final Failure? failure;
  const LoginState({this.isLoading = false, this.failure});
  LoginState copyWith({bool? isLoading, Failure? failure}) =>
      LoginState(isLoading: isLoading ?? this.isLoading, failure: failure);
}

class LoginNotifier extends StateNotifier<LoginState> {
  final LoginUseCase _loginUseCase;
  LoginNotifier(this._loginUseCase) : super(const LoginState());

  Future<AppUser?> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, failure: null);
    final result = await _loginUseCase(email: email, password: password);
    if (result.failure != null) {
      state = state.copyWith(isLoading: false, failure: result.failure);
      return null;
    }
    state = state.copyWith(isLoading: false);
    return result.user;
  }

  void clearError() => state = state.copyWith(failure: null);
}

final loginProvider = StateNotifierProvider<LoginNotifier, LoginState>(
  (ref) => LoginNotifier(ref.read(loginUseCaseProvider)),
);
