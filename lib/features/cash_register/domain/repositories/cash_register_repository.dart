// ============================================================
// lib/features/cash_register/domain/repositories/cash_register_repository.dart
// Contrato del repositorio — capa de dominio
// ============================================================

import '../entities/cash_register.dart';
import '../../../../core/errors/failures.dart';

// ── Result types ─────────────────────────────────────────────

typedef CashRegisterResult = ({CashRegister? register, Failure? failure});
typedef CashRegisterListResult = ({List<CashRegister> registers, Failure? failure});
typedef BoolResult = ({bool value, Failure? failure});

/// US-039: resumen previo de solo lectura antes de iniciar el cierre.
typedef ClosingPreview = ({
  double salesTotal,
  double expensesTotal,
  double expectedCash,
  int transactionCount,
});
typedef ClosingPreviewResult = ({ClosingPreview? preview, Failure? failure});

// ── Interfaz ─────────────────────────────────────────────────

abstract interface class CashRegisterRepository {
  /// Verifica si el cajero tiene una caja abierta HOY.
  /// Retorna la caja activa o null si no hay ninguna.
  Future<CashRegisterResult> getActiveRegister(String cashierId);

  /// Abre una nueva caja de caja registrando el desglose y las notas.
  /// [openingBreakdown] sigue el esquema de [AppConstants.coinDenominations]
  /// y [AppConstants.billDenominations].
  Future<CashRegisterResult> openRegister({
    required String cashierId,
    required Map<String, int> openingBreakdown,
    required double openingAmount,
    String? notes,
  });

  /// Obtiene el historial paginado de aperturas (solo AdminMaster).
  /// Permite filtrar por [cashierId] y/o rango de fechas.
  Future<CashRegisterListResult> getRegisterHistory({
    String? cashierId,
    DateTime? from,
    DateTime? to,
    int page = 0,
    int pageSize = 20,
  });

  /// US-039: inicia el cierre — la caja pasa a 'closing' y deja de
  /// aceptar nuevas ventas/gastos.
  Future<CashRegisterResult> startClosing(String registerId);

  /// US-040/041/042: confirma el cierre de forma atómica. El cálculo
  /// de efectivo esperado/diferencia lo hace el servidor, nunca el
  /// cliente.
  Future<CashRegisterResult> closeRegister({
    required String registerId,
    required Map<String, int> closingBreakdown,
    required double closingAmount,
    String? closingNotes,
  });

  /// US-039: resumen previo de solo lectura (ventas, gastos, efectivo
  /// esperado) para mostrar antes de que el cajero confirme iniciar
  /// el cierre.
  Future<ClosingPreviewResult> getClosingPreview({
    required String registerId,
    required double openingAmount,
  });
}
