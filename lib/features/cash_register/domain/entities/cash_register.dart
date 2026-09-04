// ============================================================
// lib/features/cash_register/domain/entities/cash_register.dart
// Entidad de negocio para el registro de caja (apertura/cierre de turno)
// Cubre: US-008, US-009, US-010, US-012
// ============================================================

import 'package:equatable/equatable.dart';
import '../../../../core/constants/app_constants.dart';

/// Representa una apertura (y eventual cierre) de caja de un turno.
///
/// El [openingBreakdown] almacena las cantidades de cada denominación:
///   { 'coin_50': 10, 'bill_5000': 3, ... }
/// con las claves definidas en [AppConstants.coinDenominations] y
/// [AppConstants.billDenominations].
class CashRegister extends Equatable {
  final String id;
  final String cashierId;
  final String? cashierName;         // Desnormalizado para listados

  /// Monto total de apertura (suma calculada del desglose)
  final double openingAmount;

  /// Desglose de denominaciones al abrir {'coin_50': qty, 'bill_1000': qty, ...}
  final Map<String, int> openingBreakdown;

  /// Notas opcionales del cajero al iniciar el turno (máx. 300 chars)
  final String? notes;

  final double? closingAmount;
  final Map<String, int>? closingBreakdown;

  /// Comentario del cajero al cerrar (US-041) — distinto de [notes],
  /// que es de la apertura.
  final String? closingNotes;

  /// Documento de cuadre congelado al cerrar (US-042): ventas por
  /// método de pago, gastos, efectivo esperado/contado y diferencia.
  final ClosingSummary? closingSummary;

  /// Timestamp UTC de apertura — no editable (US-012)
  final DateTime openingTime;
  final DateTime? closingTime;

  /// 'open' | 'closing' | 'closed'
  final String status;

  final DateTime createdAt;
  final DateTime updatedAt;

  const CashRegister({
    required this.id,
    required this.cashierId,
    this.cashierName,
    required this.openingAmount,
    required this.openingBreakdown,
    this.notes,
    this.closingAmount,
    this.closingBreakdown,
    this.closingNotes,
    this.closingSummary,
    required this.openingTime,
    this.closingTime,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Devuelve true si la caja está actualmente abierta (acepta ventas)
  bool get isOpen => status == 'open';

  /// US-039: cierre en curso — ya no acepta ventas ni gastos nuevos,
  /// pero todavía no se confirmó el cuadre final.
  bool get isClosing => status == 'closing';

  bool get isClosed => status == 'closed';

  /// Calcula el total de apertura a partir del desglose
  static double calculateTotal(Map<String, int> breakdown) {
    double total = 0;
    for (final entry in breakdown.entries) {
      final denomValue = AppConstants.coinDenominations[entry.key] ??
          AppConstants.billDenominations[entry.key] ??
          0;
      total += denomValue * entry.value;
    }
    return total;
  }

  CashRegister copyWith({
    double? closingAmount,
    Map<String, int>? closingBreakdown,
    String? closingNotes,
    ClosingSummary? closingSummary,
    DateTime? closingTime,
    String? status,
    DateTime? updatedAt,
  }) =>
      CashRegister(
        id: id,
        cashierId: cashierId,
        cashierName: cashierName,
        openingAmount: openingAmount,
        openingBreakdown: openingBreakdown,
        notes: notes,
        closingAmount: closingAmount ?? this.closingAmount,
        closingBreakdown: closingBreakdown ?? this.closingBreakdown,
        closingNotes: closingNotes ?? this.closingNotes,
        closingSummary: closingSummary ?? this.closingSummary,
        openingTime: openingTime,
        closingTime: closingTime ?? this.closingTime,
        status: status ?? this.status,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  List<Object?> get props => [id, cashierId, status, openingTime];
}

/// US-042: "documento de cuadre" — snapshot congelado al momento del
/// cierre. Se construye server-side en la función close_register() y
/// se guarda tal cual en cash_registers.closing_summary; el cliente
/// solo lo lee, nunca lo recalcula.
class ClosingSummary extends Equatable {
  final double openingAmount;
  final double salesEfectivo;
  final double salesMixtoEfectivo;
  final double salesTransferencia;
  final double salesTotal;
  final int transactionCount;
  final double totalExpenses;
  final double expectedCash;
  final double countedCash;
  final double difference;

  const ClosingSummary({
    required this.openingAmount,
    required this.salesEfectivo,
    required this.salesMixtoEfectivo,
    required this.salesTransferencia,
    required this.salesTotal,
    required this.transactionCount,
    required this.totalExpenses,
    required this.expectedCash,
    required this.countedCash,
    required this.difference,
  });

  factory ClosingSummary.fromJson(Map<String, dynamic> json) => ClosingSummary(
        openingAmount: (json['opening_amount'] as num).toDouble(),
        salesEfectivo: (json['sales_efectivo'] as num).toDouble(),
        salesMixtoEfectivo: (json['sales_mixto_efectivo'] as num).toDouble(),
        salesTransferencia: (json['sales_transferencia'] as num).toDouble(),
        salesTotal: (json['sales_total'] as num).toDouble(),
        transactionCount: (json['transaction_count'] as num).toInt(),
        totalExpenses: (json['total_expenses'] as num).toDouble(),
        expectedCash: (json['expected_cash'] as num).toDouble(),
        countedCash: (json['counted_cash'] as num).toDouble(),
        difference: (json['difference'] as num).toDouble(),
      );

  @override
  List<Object?> get props => [expectedCash, countedCash, difference];
}
