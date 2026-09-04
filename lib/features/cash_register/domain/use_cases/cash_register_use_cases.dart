// ============================================================
// lib/features/cash_register/domain/use_cases/cash_register_use_cases.dart
// Casos de uso de la Épica 2 — Apertura de Caja
// US-008: Verificar si hay caja abierta
// US-009: Registrar desglose de denominaciones
// US-010: Añadir notas en apertura
// US-011: Obtener historial (AdminMaster)
// US-012: Timestamp automático (manejado por Supabase)
// ============================================================

import '../repositories/cash_register_repository.dart';
import '../../../../core/errors/failures.dart';

// ── US-008: ¿Hay caja abierta? ───────────────────────────────

/// Comprueba si el cajero ya tiene una caja abierta hoy.
/// Si existe, retorna la caja activa para continuar el turno.
class CheckActiveRegisterUseCase {
  final CashRegisterRepository _repo;
  const CheckActiveRegisterUseCase(this._repo);

  Future<CashRegisterResult> call(String cashierId) =>
      _repo.getActiveRegister(cashierId);
}

// ── US-009 + US-010: Abrir caja con desglose y notas ──────────

/// Abre una nueva caja de caja registrando el desglose por denominaciones
/// y las notas opcionales del cajero.
class OpenCashRegisterUseCase {
  final CashRegisterRepository _repo;
  const OpenCashRegisterUseCase(this._repo);

  Future<CashRegisterResult> call({
    required String cashierId,
    required Map<String, int> openingBreakdown,
    required double openingAmount,
    String? notes,
  }) {
    // Validar que el monto sea positivo
    if (openingAmount < 0) {
      return Future.value((
        register: null,
        failure: const ValidationFailure('El monto de apertura no puede ser negativo.'),
      ));
    }
    return _repo.openRegister(
      cashierId: cashierId,
      openingBreakdown: openingBreakdown,
      openingAmount: openingAmount,
      notes: notes,
    );
  }
}

// ── US-011: Historial de aperturas (AdminMaster) ─────────────

/// Obtiene el historial paginado de aperturas con filtros opcionales.
class GetRegisterHistoryUseCase {
  final CashRegisterRepository _repo;
  const GetRegisterHistoryUseCase(this._repo);

  Future<CashRegisterListResult> call({
    String? cashierId,
    DateTime? from,
    DateTime? to,
    int page = 0,
    int pageSize = 20,
  }) =>
      _repo.getRegisterHistory(
        cashierId: cashierId,
        from: from,
        to: to,
        page: page,
        pageSize: pageSize,
      );
}

// ── US-039: Iniciar cierre de caja ────────────────────────────

class StartRegisterClosingUseCase {
  final CashRegisterRepository _repo;
  const StartRegisterClosingUseCase(this._repo);

  Future<CashRegisterResult> call(String registerId) => _repo.startClosing(registerId);
}

// ── US-040/041/042: Confirmar cierre de caja ──────────────────

class CloseRegisterUseCase {
  final CashRegisterRepository _repo;
  const CloseRegisterUseCase(this._repo);

  Future<CashRegisterResult> call({
    required String registerId,
    required Map<String, int> closingBreakdown,
    required double closingAmount,
    String? closingNotes,
  }) =>
      _repo.closeRegister(
        registerId: registerId,
        closingBreakdown: closingBreakdown,
        closingAmount: closingAmount,
        closingNotes: closingNotes,
      );
}

// ── US-039: Resumen previo antes de iniciar el cierre ─────────

class GetClosingPreviewUseCase {
  final CashRegisterRepository _repo;
  const GetClosingPreviewUseCase(this._repo);

  Future<ClosingPreviewResult> call({required String registerId, required double openingAmount}) =>
      _repo.getClosingPreview(registerId: registerId, openingAmount: openingAmount);
}
