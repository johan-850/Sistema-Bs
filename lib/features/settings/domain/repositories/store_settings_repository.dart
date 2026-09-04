// ============================================================
// lib/features/settings/domain/repositories/store_settings_repository.dart
// Contrato del repositorio de configuración del negocio
// ============================================================

import 'dart:typed_data';

import '../entities/store_settings.dart';
import '../../../../core/errors/failures.dart';

typedef StoreSettingsResult = ({StoreSettings? settings, Failure? failure});

abstract class StoreSettingsRepository {
  /// Lee la fila singleton de configuración del negocio.
  Future<StoreSettingsResult> getSettings();

  /// Sube la imagen del QR de pago y guarda su URL en la configuración.
  /// Devuelve la configuración ya actualizada.
  Future<StoreSettingsResult> updateQrImage(Uint8List bytes, String fileExt);

  /// Quita el QR configurado (borra el archivo y limpia la URL guardada).
  Future<StoreSettingsResult> removeQrImage(String currentUrl);

  /// EP-06: guarda el monto máximo de gasto sugerido y la ventana de
  /// edición de gastos recién registrados.
  Future<StoreSettingsResult> updateExpenseSettings({
    double? maxExpenseAmount,
    required int expenseEditWindowMinutes,
  });

  /// EP-07 (US-041): umbral de diferencia de caja que exige comentario.
  Future<StoreSettingsResult> updateCashDiffCommentThreshold(double threshold);

  /// EP-09 (US-054): activar/desactivar el reporte semanal y su correo destino.
  Future<StoreSettingsResult> updateWeeklyReportSettings({
    required bool enabled,
    String? email,
  });

  /// EP-09 (US-054): envío de prueba inmediato, ignora el toggle activo/inactivo.
  Future<Failure?> sendWeeklyReportNow();
}
