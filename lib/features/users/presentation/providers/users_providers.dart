import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/user_remote_datasource.dart';
import '../../data/repositories/user_repository_impl.dart';
import '../../domain/entities/cashier.dart';
import '../../domain/repositories/user_repository.dart';
import '../../domain/use_cases/user_use_cases.dart';
import '../../../../core/errors/failures.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

// ── DI ────────────────────────────────────────────────────────
final userDatasourceProvider = Provider(
  (ref) => UserRemoteDatasource(ref.read(supabaseClientProvider)),
);
final userRepositoryProvider = Provider<UserRepository>(
  (ref) => UserRepositoryImpl(ref.read(userDatasourceProvider)),
);

// ── Use cases ─────────────────────────────────────────────────
final createCashierUseCaseProvider = Provider((ref) => CreateCashierUseCase(ref.read(userRepositoryProvider)));
final toggleStatusUseCaseProvider = Provider((ref) => ToggleCashierStatusUseCase(ref.read(userRepositoryProvider)));
final resetPasswordUseCaseProvider = Provider((ref) => ResetCashierPasswordUseCase(ref.read(userRepositoryProvider)));
final getCashiersUseCaseProvider = Provider((ref) => GetCashiersUseCase(ref.read(userRepositoryProvider)));

// ── Estado del listado de cajeros (US-007) ────────────────────
class CashierListState {
  final List<Cashier> cashiers;
  final bool isLoading;
  final bool? filterActive;
  final int currentPage;
  final Failure? failure;
  final String? successMessage;

  const CashierListState({
    this.cashiers = const [],
    this.isLoading = false,
    this.filterActive,
    this.currentPage = 0,
    this.failure,
    this.successMessage,
  });

  CashierListState copyWith({
    List<Cashier>? cashiers,
    bool? isLoading,
    Object? filterActive = _sentinel,
    int? currentPage,
    Failure? failure,
    String? successMessage,
  }) =>
      CashierListState(
        cashiers: cashiers ?? this.cashiers,
        isLoading: isLoading ?? this.isLoading,
        filterActive: filterActive == _sentinel ? this.filterActive : filterActive as bool?,
        currentPage: currentPage ?? this.currentPage,
        failure: failure,
        successMessage: successMessage,
      );
}

const _sentinel = Object();

class CashierListNotifier extends StateNotifier<CashierListState> {
  final GetCashiersUseCase _getCashiers;
  final ToggleCashierStatusUseCase _toggleStatus;
  final ResetCashierPasswordUseCase _resetPassword;
  final UserRepository _repo;

  CashierListNotifier(this._getCashiers, this._toggleStatus, this._resetPassword, this._repo)
      : super(const CashierListState()) {
    load();
  }

  Future<void> load({bool? filterActive, int page = 0}) async {
    state = state.copyWith(isLoading: true, filterActive: filterActive, currentPage: page);
    final result = await _getCashiers(filterActive: filterActive, page: page);
    if (result.failure != null) {
      state = state.copyWith(isLoading: false, failure: result.failure);
    } else {
      state = state.copyWith(isLoading: false, cashiers: result.cashiers ?? []);
    }
  }

  Future<bool> toggleStatus(String cashierId, bool isActive) async {
    // Optimistic update: refleja el cambio en UI de inmediato
    final optimistic = state.cashiers
        .map((c) => c.id == cashierId ? c.copyWith(isActive: isActive) : c)
        .toList();
    state = state.copyWith(cashiers: optimistic);

    final result = await _toggleStatus(cashierId: cashierId, isActive: isActive);
    if (result.failure != null) {
      // Revertir si hubo error real en BD
      final reverted = state.cashiers
          .map((c) => c.id == cashierId ? c.copyWith(isActive: !isActive) : c)
          .toList();
      state = state.copyWith(cashiers: reverted, failure: result.failure);
      return false;
    }
    state = state.copyWith(
      successMessage: isActive ? 'Cajero activado correctamente' : 'Cajero desactivado correctamente',
    );
    return true;
  }

  Future<bool> resetPassword(String email) async {
    final result = await _resetPassword(email: email);
    if (result.failure != null) {
      state = state.copyWith(failure: result.failure);
      return false;
    }
    state = state.copyWith(successMessage: 'Correo de restablecimiento enviado a $email');
    return true;
  }

  Future<({String? csv, Failure? failure})> exportCSV() async {
    final result = await _repo.exportCashiersToCSV();
    return (csv: result.csvContent, failure: result.failure);
  }
}

final cashierListProvider =
    StateNotifierProvider<CashierListNotifier, CashierListState>((ref) {
  return CashierListNotifier(
    ref.read(getCashiersUseCaseProvider),
    ref.read(toggleStatusUseCaseProvider),
    ref.read(resetPasswordUseCaseProvider),
    ref.read(userRepositoryProvider),
  );
});

// ── Estado de creación de cajero (US-003) ─────────────────────
class CreateCashierState {
  final bool isLoading;
  final bool success;
  final Failure? failure;
  const CreateCashierState({this.isLoading = false, this.success = false, this.failure});
  CreateCashierState copyWith({bool? isLoading, bool? success, Failure? failure}) =>
      CreateCashierState(
        isLoading: isLoading ?? this.isLoading,
        success: success ?? this.success,
        failure: failure,
      );
}

class CreateCashierNotifier extends StateNotifier<CreateCashierState> {
  final CreateCashierUseCase _useCase;
  CreateCashierNotifier(this._useCase) : super(const CreateCashierState());

  Future<bool> create({required String name, required String email, required String password}) async {
    state = state.copyWith(isLoading: true);
    final result = await _useCase(name: name, email: email, password: password);
    if (result.failure != null) {
      state = state.copyWith(isLoading: false, failure: result.failure);
      return false;
    }
    state = state.copyWith(isLoading: false, success: true);
    return true;
  }
}

final createCashierProvider =
    StateNotifierProvider.autoDispose<CreateCashierNotifier, CreateCashierState>(
  (ref) => CreateCashierNotifier(ref.read(createCashierUseCaseProvider)),
);
