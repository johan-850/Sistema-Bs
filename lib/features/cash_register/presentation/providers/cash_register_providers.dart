// ============================================================
// lib/features/cash_register/presentation/providers/cash_register_providers.dart
// Providers de Riverpod para la Épica 2 — Apertura de Caja
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/cash_register_remote_datasource.dart';
import '../../data/repositories/cash_register_repository_impl.dart';
import '../../domain/entities/cash_register.dart';
import '../../domain/repositories/cash_register_repository.dart';
import '../../domain/use_cases/cash_register_use_cases.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/failures.dart';

// ── DI (Inyección de dependencias) ────────────────────────────

final cashRegisterDatasourceProvider = Provider(
  (ref) => CashRegisterRemoteDatasource(ref.read(supabaseClientProvider)),
);

final cashRegisterRepositoryProvider = Provider<CashRegisterRepository>(
  (ref) => CashRegisterRepositoryImpl(ref.read(cashRegisterDatasourceProvider)),
);

// ── Use cases ─────────────────────────────────────────────────

final checkActiveRegisterUseCaseProvider = Provider(
  (ref) => CheckActiveRegisterUseCase(ref.read(cashRegisterRepositoryProvider)),
);

final openCashRegisterUseCaseProvider = Provider(
  (ref) => OpenCashRegisterUseCase(ref.read(cashRegisterRepositoryProvider)),
);

final getRegisterHistoryUseCaseProvider = Provider(
  (ref) => GetRegisterHistoryUseCase(ref.read(cashRegisterRepositoryProvider)),
);

final startRegisterClosingUseCaseProvider = Provider(
  (ref) => StartRegisterClosingUseCase(ref.read(cashRegisterRepositoryProvider)),
);

final closeRegisterUseCaseProvider = Provider(
  (ref) => CloseRegisterUseCase(ref.read(cashRegisterRepositoryProvider)),
);

final getClosingPreviewUseCaseProvider = Provider(
  (ref) => GetClosingPreviewUseCase(ref.read(cashRegisterRepositoryProvider)),
);

// ── US-008: Caja activa del cajero actual (FutureProvider) ────

/// Carga la caja activa del cajero autenticado.
/// Se invalida tras una apertura exitosa.
final activeRegisterProvider = FutureProvider<CashRegister?>((ref) async {
  final user = ref.watch(authStateStreamProvider).valueOrNull;
  if (user == null) return null;

  final result = await ref
      .read(checkActiveRegisterUseCaseProvider)
      .call(user.id);

  if (result.failure != null) return null;
  return result.register;
});

// ── US-009 + US-010: Estado del formulario de apertura ────────

/// Representa el estado interno del formulario de apertura de caja.
class OpenRegisterState {
  /// Cantidades ingresadas por denominación {'coin_50': 3, 'bill_1000': 5, ...}
  final Map<String, int> breakdown;

  /// Notas opcionales del cajero (US-010)
  final String notes;

  /// Paso actual del wizard: 0=desglose, 1=notas, 2=confirmación
  final int currentStep;

  final bool isLoading;
  final bool success;
  final Failure? failure;
  final CashRegister? openedRegister;

  const OpenRegisterState({
    this.breakdown = const {},
    this.notes = '',
    this.currentStep = 0,
    this.isLoading = false,
    this.success = false,
    this.failure,
    this.openedRegister,
  });

  /// Calcula el total en pesos sumando cantidad × valor de cada denominación
  double get total {
    double sum = 0;
    for (final entry in breakdown.entries) {
      final value = AppConstants.coinDenominations[entry.key] ??
          AppConstants.billDenominations[entry.key] ??
          0;
      sum += value * entry.value;
    }
    return sum;
  }

  /// Desglose de solo las denominaciones con cantidad > 0
  Map<String, int> get nonZeroBreakdown =>
      Map.fromEntries(breakdown.entries.where((e) => e.value > 0));

  OpenRegisterState copyWith({
    Map<String, int>? breakdown,
    String? notes,
    int? currentStep,
    bool? isLoading,
    bool? success,
    Failure? failure,
    CashRegister? openedRegister,
    bool clearFailure = false,
    bool clearSuccess = false,
  }) =>
      OpenRegisterState(
        breakdown: breakdown ?? this.breakdown,
        notes: notes ?? this.notes,
        currentStep: currentStep ?? this.currentStep,
        isLoading: isLoading ?? this.isLoading,
        success: clearSuccess ? false : (success ?? this.success),
        failure: clearFailure ? null : (failure ?? this.failure),
        openedRegister: openedRegister ?? this.openedRegister,
      );
}

class OpenRegisterNotifier extends StateNotifier<OpenRegisterState> {
  final OpenCashRegisterUseCase _openUseCase;
  final String _cashierId;

  OpenRegisterNotifier(this._openUseCase, this._cashierId)
      : super(const OpenRegisterState()) {
    // Inicializar breakdown con todas las denominaciones en 0
    _initBreakdown();
  }

  void _initBreakdown() {
    final initial = <String, int>{};
    for (final key in AppConstants.coinDenominations.keys) {
      initial[key] = 0;
    }
    for (final key in AppConstants.billDenominations.keys) {
      initial[key] = 0;
    }
    state = state.copyWith(breakdown: initial);
  }

  // ── Controles de denominaciones ───────────────────────────

  /// Incrementa la cantidad de una denominación
  void increment(String key) {
    final updated = Map<String, int>.from(state.breakdown);
    updated[key] = (updated[key] ?? 0) + 1;
    state = state.copyWith(breakdown: updated);
  }

  /// Decrementa la cantidad (mínimo 0)
  void decrement(String key) {
    final updated = Map<String, int>.from(state.breakdown);
    final current = updated[key] ?? 0;
    if (current > 0) updated[key] = current - 1;
    state = state.copyWith(breakdown: updated);
  }

  /// Establece la cantidad directamente (por teclado)
  void setQuantity(String key, int qty) {
    final updated = Map<String, int>.from(state.breakdown);
    updated[key] = qty.clamp(0, 9999);
    state = state.copyWith(breakdown: updated);
  }

  // ── Navegación del wizard ─────────────────────────────────

  void updateNotes(String notes) => state = state.copyWith(notes: notes);

  void goToStep(int step) => state = state.copyWith(currentStep: step);

  void nextStep() => goToStep((state.currentStep + 1).clamp(0, 2));

  void previousStep() => goToStep((state.currentStep - 1).clamp(0, 2));

  // ── Confirmar apertura ────────────────────────────────────

  Future<bool> confirmOpen() async {
    state = state.copyWith(isLoading: true, clearFailure: true);

    final result = await _openUseCase(
      cashierId: _cashierId,
      openingBreakdown: state.nonZeroBreakdown,
      openingAmount: state.total,
      notes: state.notes.isNotEmpty ? state.notes : null,
    );

    if (result.failure != null) {
      state = state.copyWith(isLoading: false, failure: result.failure);
      return false;
    }

    state = state.copyWith(
      isLoading: false,
      success: true,
      openedRegister: result.register,
    );
    return true;
  }
}

final openRegisterProvider =
    StateNotifierProvider.autoDispose<OpenRegisterNotifier, OpenRegisterState>(
  (ref) {
    final user = ref.read(authStateStreamProvider).valueOrNull;
    return OpenRegisterNotifier(
      ref.read(openCashRegisterUseCaseProvider),
      user?.id ?? '',
    );
  },
);

// ── US-011: Historial de aperturas (AdminMaster) ──────────────

class RegisterHistoryState {
  final List<CashRegister> registers;
  final bool isLoading;
  final int currentPage;
  final Failure? failure;
  // Filtros activos
  final String? filterCashierId;
  final DateTime? filterFrom;
  final DateTime? filterTo;

  const RegisterHistoryState({
    this.registers = const [],
    this.isLoading = false,
    this.currentPage = 0,
    this.failure,
    this.filterCashierId,
    this.filterFrom,
    this.filterTo,
  });

  RegisterHistoryState copyWith({
    List<CashRegister>? registers,
    bool? isLoading,
    int? currentPage,
    Failure? failure,
    String? filterCashierId,
    DateTime? filterFrom,
    DateTime? filterTo,
    bool clearFilters = false,
  }) =>
      RegisterHistoryState(
        registers: registers ?? this.registers,
        isLoading: isLoading ?? this.isLoading,
        currentPage: currentPage ?? this.currentPage,
        failure: failure,
        filterCashierId:
            clearFilters ? null : (filterCashierId ?? this.filterCashierId),
        filterFrom: clearFilters ? null : (filterFrom ?? this.filterFrom),
        filterTo: clearFilters ? null : (filterTo ?? this.filterTo),
      );
}

class RegisterHistoryNotifier extends StateNotifier<RegisterHistoryState> {
  final GetRegisterHistoryUseCase _useCase;

  RegisterHistoryNotifier(this._useCase) : super(const RegisterHistoryState()) {
    load();
  }

  Future<void> load({
    String? cashierId,
    DateTime? from,
    DateTime? to,
    int page = 0,
  }) async {
    state = state.copyWith(
      isLoading: true,
      currentPage: page,
      filterCashierId: cashierId,
      filterFrom: from,
      filterTo: to,
    );

    final result = await _useCase(
      cashierId: cashierId ?? state.filterCashierId,
      from: from ?? state.filterFrom,
      to: to ?? state.filterTo,
      page: page,
    );

    if (result.failure != null) {
      state = state.copyWith(isLoading: false, failure: result.failure);
    } else {
      state = state.copyWith(
        isLoading: false,
        registers: result.registers,
      );
    }
  }

  Future<void> applyFilters({
    String? cashierId,
    DateTime? from,
    DateTime? to,
  }) =>
      load(cashierId: cashierId, from: from, to: to, page: 0);

  Future<void> clearFilters() async {
    state = state.copyWith(clearFilters: true);
    await load();
  }
}

final registerHistoryProvider =
    StateNotifierProvider<RegisterHistoryNotifier, RegisterHistoryState>(
  (ref) => RegisterHistoryNotifier(ref.read(getRegisterHistoryUseCaseProvider)),
);

// ── US-039/040/041/042: Wizard de cierre de caja ──────────────

/// Argumentos para instanciar el wizard de cierre de una caja puntual.
typedef ClosingArgs = ({String registerId, double openingAmount});

class RegisterClosingState {
  /// Cantidades ingresadas por denominación al contar el efectivo final.
  final Map<String, int> breakdown;

  /// Comentario del cajero (US-041)
  final String notes;

  /// Paso actual del wizard: 0=resumen previo, 1=conteo, 2=comentario/confirmar
  final int currentStep;

  final bool isLoading;

  /// true una vez que start_register_closing() ya se ejecutó — la caja
  /// pasó a 'closing' y dejó de aceptar ventas/gastos nuevos.
  final bool started;

  final bool success;
  final Failure? failure;
  final ClosingPreview? preview;
  final CashRegister? closedRegister;

  const RegisterClosingState({
    this.breakdown = const {},
    this.notes = '',
    this.currentStep = 0,
    this.isLoading = false,
    this.started = false,
    this.success = false,
    this.failure,
    this.preview,
    this.closedRegister,
  });

  double get total {
    double sum = 0;
    for (final entry in breakdown.entries) {
      final value = AppConstants.coinDenominations[entry.key] ??
          AppConstants.billDenominations[entry.key] ??
          0;
      sum += value * entry.value;
    }
    return sum;
  }

  Map<String, int> get nonZeroBreakdown =>
      Map.fromEntries(breakdown.entries.where((e) => e.value > 0));

  /// Diferencia contra el efectivo esperado — null hasta que cargue el
  /// resumen previo.
  double? get difference => preview != null ? total - preview!.expectedCash : null;

  RegisterClosingState copyWith({
    Map<String, int>? breakdown,
    String? notes,
    int? currentStep,
    bool? isLoading,
    bool? started,
    bool? success,
    Failure? failure,
    ClosingPreview? preview,
    CashRegister? closedRegister,
    bool clearFailure = false,
  }) =>
      RegisterClosingState(
        breakdown: breakdown ?? this.breakdown,
        notes: notes ?? this.notes,
        currentStep: currentStep ?? this.currentStep,
        isLoading: isLoading ?? this.isLoading,
        started: started ?? this.started,
        success: success ?? this.success,
        failure: clearFailure ? null : (failure ?? this.failure),
        preview: preview ?? this.preview,
        closedRegister: closedRegister ?? this.closedRegister,
      );
}

class RegisterClosingNotifier extends StateNotifier<RegisterClosingState> {
  final GetClosingPreviewUseCase _getPreview;
  final StartRegisterClosingUseCase _startClosing;
  final CloseRegisterUseCase _closeRegister;
  final String _registerId;
  final double _openingAmount;

  RegisterClosingNotifier(
    this._getPreview,
    this._startClosing,
    this._closeRegister,
    this._registerId,
    this._openingAmount,
  ) : super(const RegisterClosingState()) {
    _initBreakdown();
    loadPreview();
  }

  void _initBreakdown() {
    final initial = <String, int>{};
    for (final key in AppConstants.coinDenominations.keys) {
      initial[key] = 0;
    }
    for (final key in AppConstants.billDenominations.keys) {
      initial[key] = 0;
    }
    state = state.copyWith(breakdown: initial);
  }

  /// US-039: resumen previo (solo lectura) antes de iniciar el cierre.
  Future<void> loadPreview() async {
    state = state.copyWith(isLoading: true, clearFailure: true);
    final result =
        await _getPreview(registerId: _registerId, openingAmount: _openingAmount);
    state = result.failure != null
        ? state.copyWith(isLoading: false, failure: result.failure)
        : state.copyWith(isLoading: false, preview: result.preview);
  }

  /// US-039: confirma iniciar el cierre — bloquea ventas/gastos nuevos.
  Future<bool> confirmStart() async {
    state = state.copyWith(isLoading: true, clearFailure: true);
    final result = await _startClosing(_registerId);
    if (result.failure != null) {
      state = state.copyWith(isLoading: false, failure: result.failure);
      return false;
    }
    state = state.copyWith(isLoading: false, started: true, currentStep: 1);
    return true;
  }

  void increment(String key) {
    final updated = Map<String, int>.from(state.breakdown);
    updated[key] = (updated[key] ?? 0) + 1;
    state = state.copyWith(breakdown: updated);
  }

  void decrement(String key) {
    final updated = Map<String, int>.from(state.breakdown);
    final current = updated[key] ?? 0;
    if (current > 0) updated[key] = current - 1;
    state = state.copyWith(breakdown: updated);
  }

  void setQuantity(String key, int qty) {
    final updated = Map<String, int>.from(state.breakdown);
    updated[key] = qty.clamp(0, 9999);
    state = state.copyWith(breakdown: updated);
  }

  void updateNotes(String notes) => state = state.copyWith(notes: notes);

  void goToStep(int step) => state = state.copyWith(currentStep: step);

  /// US-040/041/042: confirma el cuadre final.
  Future<bool> confirmClose() async {
    state = state.copyWith(isLoading: true, clearFailure: true);

    final result = await _closeRegister(
      registerId: _registerId,
      closingBreakdown: state.nonZeroBreakdown,
      closingAmount: state.total,
      closingNotes: state.notes.isNotEmpty ? state.notes : null,
    );

    if (result.failure != null) {
      state = state.copyWith(isLoading: false, failure: result.failure);
      return false;
    }

    state = state.copyWith(isLoading: false, success: true, closedRegister: result.register);
    return true;
  }
}

final registerClosingProvider = StateNotifierProvider.autoDispose
    .family<RegisterClosingNotifier, RegisterClosingState, ClosingArgs>(
  (ref, args) => RegisterClosingNotifier(
    ref.read(getClosingPreviewUseCaseProvider),
    ref.read(startRegisterClosingUseCaseProvider),
    ref.read(closeRegisterUseCaseProvider),
    args.registerId,
    args.openingAmount,
  ),
);
