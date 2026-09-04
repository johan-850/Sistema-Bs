// ============================================================
// lib/features/settings/data/repositories/store_settings_repository_impl.dart
// Implementación del repositorio — convierte excepciones a Failures
// ============================================================

import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/repositories/store_settings_repository.dart';
import '../datasources/store_settings_remote_datasource.dart';
import '../../../../core/errors/failures.dart';

class StoreSettingsRepositoryImpl implements StoreSettingsRepository {
  final StoreSettingsRemoteDatasource _datasource;
  const StoreSettingsRepositoryImpl(this._datasource);

  Failure _mapException(Object e) {
    if (e is PostgrestException) {
      if (e.code == '42501' || e.message.contains('policy')) {
        return const PermissionFailure();
      }
      return ServerFailure(e.message);
    }
    return UnexpectedFailure(e.toString());
  }

  @override
  Future<StoreSettingsResult> getSettings() async {
    try {
      final settings = await _datasource.getSettings();
      return (settings: settings, failure: null);
    } catch (e) {
      return (settings: null, failure: _mapException(e));
    }
  }

  @override
  Future<StoreSettingsResult> updateQrImage(Uint8List bytes, String fileExt) async {
    try {
      final url = await _datasource.uploadQrImage(bytes, fileExt);
      final settings = await _datasource.updateQrImageUrl(url);
      return (settings: settings, failure: null);
    } catch (e) {
      return (settings: null, failure: _mapException(e));
    }
  }

  @override
  Future<StoreSettingsResult> removeQrImage(String currentUrl) async {
    try {
      await _datasource.deleteQrImage(currentUrl);
      final settings = await _datasource.updateQrImageUrl(null);
      return (settings: settings, failure: null);
    } catch (e) {
      return (settings: null, failure: _mapException(e));
    }
  }

  @override
  Future<StoreSettingsResult> updateExpenseSettings({
    double? maxExpenseAmount,
    required int expenseEditWindowMinutes,
  }) async {
    try {
      final settings = await _datasource.updateExpenseSettings(
        maxExpenseAmount: maxExpenseAmount,
        expenseEditWindowMinutes: expenseEditWindowMinutes,
      );
      return (settings: settings, failure: null);
    } catch (e) {
      return (settings: null, failure: _mapException(e));
    }
  }

  @override
  Future<StoreSettingsResult> updateCashDiffCommentThreshold(double threshold) async {
    try {
      final settings = await _datasource.updateCashDiffCommentThreshold(threshold);
      return (settings: settings, failure: null);
    } catch (e) {
      return (settings: null, failure: _mapException(e));
    }
  }

  @override
  Future<StoreSettingsResult> updateWeeklyReportSettings({
    required bool enabled,
    String? email,
  }) async {
    try {
      final settings = await _datasource.updateWeeklyReportSettings(enabled: enabled, email: email);
      return (settings: settings, failure: null);
    } catch (e) {
      return (settings: null, failure: _mapException(e));
    }
  }

  @override
  Future<Failure?> sendWeeklyReportNow() async {
    try {
      await _datasource.sendWeeklyReportNow();
      return null;
    } catch (e) {
      return _mapException(e);
    }
  }
}
