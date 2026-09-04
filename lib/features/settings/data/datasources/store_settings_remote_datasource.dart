// ============================================================
// lib/features/settings/data/datasources/store_settings_remote_datasource.dart
// Datasource remoto — fila singleton store_settings + bucket store-assets
// ============================================================

import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/store_settings.dart';
import '../../../../core/constants/app_constants.dart';

class StoreSettingsRemoteDatasource {
  final SupabaseClient _client;
  const StoreSettingsRemoteDatasource(this._client);

  StoreSettings _fromJson(Map<String, dynamic> json) => StoreSettings(
        qrImageUrl: json['qr_image_url'] as String?,
        maxExpenseAmount: (json['max_expense_amount'] as num?)?.toDouble(),
        expenseEditWindowMinutes: (json['expense_edit_window_minutes'] as num?)?.toInt() ?? 10,
        cashDiffCommentThreshold:
            (json['cash_diff_comment_threshold'] as num?)?.toDouble() ?? 5000,
        weeklyReportEnabled: json['weekly_report_enabled'] as bool? ?? false,
        weeklyReportEmail: json['weekly_report_email'] as String?,
      );

  Future<StoreSettings> getSettings() async {
    final result = await _client
        .from(AppConstants.tableStoreSettings)
        .select()
        .eq('id', 1)
        .single();
    return _fromJson(result);
  }

  Future<StoreSettings> updateQrImageUrl(String? url) async {
    final result = await _client
        .from(AppConstants.tableStoreSettings)
        .update({'qr_image_url': url, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', 1)
        .select()
        .single();
    return _fromJson(result);
  }

  /// EP-06: configuración del módulo de gastos (US-034/US-035).
  Future<StoreSettings> updateExpenseSettings({
    double? maxExpenseAmount,
    required int expenseEditWindowMinutes,
  }) async {
    final result = await _client
        .from(AppConstants.tableStoreSettings)
        .update({
          'max_expense_amount': maxExpenseAmount,
          'expense_edit_window_minutes': expenseEditWindowMinutes,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', 1)
        .select()
        .single();
    return _fromJson(result);
  }

  /// EP-07: umbral de diferencia de caja que exige comentario (US-041).
  Future<StoreSettings> updateCashDiffCommentThreshold(double threshold) async {
    final result = await _client
        .from(AppConstants.tableStoreSettings)
        .update({
          'cash_diff_comment_threshold': threshold,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', 1)
        .select()
        .single();
    return _fromJson(result);
  }

  /// Mismo patrón que uploadProductImage (EP-03), en el bucket store-assets.
  Future<String> uploadQrImage(Uint8List bytes, String fileExt) async {
    final path = 'qr/${const Uuid().v4()}.$fileExt';
    await _client.storage
        .from(AppConstants.storageBucketStoreAssets)
        .uploadBinary(path, bytes, fileOptions: const FileOptions(upsert: true));

    return _client.storage
        .from(AppConstants.storageBucketStoreAssets)
        .getPublicUrl(path);
  }

  /// Best-effort: no propaga errores.
  Future<void> deleteQrImage(String imageUrl) async {
    try {
      final marker = '/object/public/${AppConstants.storageBucketStoreAssets}/';
      final idx = imageUrl.indexOf(marker);
      if (idx == -1) return;
      final path = imageUrl.substring(idx + marker.length);
      await _client.storage.from(AppConstants.storageBucketStoreAssets).remove([path]);
    } catch (_) {
      /* No crítico */
    }
  }

  /// EP-09 (US-054): activar/desactivar el reporte semanal y su correo destino.
  Future<StoreSettings> updateWeeklyReportSettings({
    required bool enabled,
    String? email,
  }) async {
    final result = await _client
        .from(AppConstants.tableStoreSettings)
        .update({
          'weekly_report_enabled': enabled,
          'weekly_report_email': email,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', 1)
        .select()
        .single();
    return _fromJson(result);
  }

  /// Invoca la Edge Function con `manual: true` — ignora el toggle
  /// `weekly_report_enabled` y envía igual al correo configurado.
  Future<void> sendWeeklyReportNow() async {
    final response = await _client.functions.invoke(
      AppConstants.fnSendWeeklyReport,
      body: {'manual': true},
    );
    if (response.status != 200) {
      final msg = (response.data as Map?)?['error'] as String? ?? 'Error al enviar el reporte';
      throw Exception(msg);
    }
  }
}
