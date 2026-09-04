// ============================================================
// lib/features/settings/domain/entities/store_settings.dart
// Configuración general del negocio (singleton) — QR de pago
// ============================================================

import 'package:equatable/equatable.dart';

class StoreSettings extends Equatable {
  final String? qrImageUrl;

  /// EP-06: monto a partir del cual un gasto se considera "elevado"
  /// (US-034) — null significa que el AdminMaster no configuró un límite.
  final double? maxExpenseAmount;

  /// EP-06: minutos durante los cuales un gasto recién registrado
  /// puede editarse (US-035).
  final int expenseEditWindowMinutes;

  /// EP-07 (US-041): diferencia de caja (en pesos) a partir de la cual
  /// el cajero debe justificar el cierre con un comentario obligatorio.
  final double cashDiffCommentThreshold;

  /// EP-09 (US-054): si está activo, el cron semanal envía el reporte
  /// a [weeklyReportEmail] — el envío manual de prueba ignora este flag.
  final bool weeklyReportEnabled;
  final String? weeklyReportEmail;

  const StoreSettings({
    this.qrImageUrl,
    this.maxExpenseAmount,
    this.expenseEditWindowMinutes = 10,
    this.cashDiffCommentThreshold = 5000,
    this.weeklyReportEnabled = false,
    this.weeklyReportEmail,
  });

  bool get hasQrImage => qrImageUrl != null && qrImageUrl!.isNotEmpty;

  @override
  List<Object?> get props => [
        qrImageUrl,
        maxExpenseAmount,
        expenseEditWindowMinutes,
        cashDiffCommentThreshold,
        weeklyReportEnabled,
        weeklyReportEmail,
      ];
}
