// ============================================================
// lib/features/cash_register/data/repositories/cash_register_repository_impl.dart
// Implementación del repositorio — convierte excepciones a Failures
// ============================================================

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/cash_register.dart';  // necesario para CashRegisterListResult
import '../../domain/repositories/cash_register_repository.dart';
import '../datasources/cash_register_remote_datasource.dart';
import '../../../../core/errors/failures.dart';

class CashRegisterRepositoryImpl implements CashRegisterRepository {
  final CashRegisterRemoteDatasource _datasource;
  const CashRegisterRepositoryImpl(this._datasource);

  /// Mapea excepciones de Supabase/red a Failures tipados.
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
  Future<CashRegisterResult> getActiveRegister(String cashierId) async {
    try {
      final register = await _datasource.getActiveRegister(cashierId);
      return (register: register, failure: null);
    } catch (e) {
      return (register: null, failure: _mapException(e));
    }
  }

  @override
  Future<CashRegisterResult> openRegister({
    required String cashierId,
    required Map<String, int> openingBreakdown,
    required double openingAmount,
    String? notes,
  }) async {
    try {
      final register = await _datasource.openRegister(
        cashierId: cashierId,
        openingBreakdown: openingBreakdown,
        openingAmount: openingAmount,
        notes: notes,
      );
      return (register: register, failure: null);
    } catch (e) {
      return (register: null, failure: _mapException(e));
    }
  }

  @override
  Future<CashRegisterListResult> getRegisterHistory({
    String? cashierId,
    DateTime? from,
    DateTime? to,
    int page = 0,
    int pageSize = 20,
  }) async {
    try {
      final registers = await _datasource.getRegisterHistory(
        cashierId: cashierId,
        from: from,
        to: to,
        page: page,
        pageSize: pageSize,
      );
      return (registers: registers, failure: null);
    } catch (e) {
      return (registers: <CashRegister>[], failure: _mapException(e));
    }
  }

  @override
  Future<CashRegisterResult> startClosing(String registerId) async {
    try {
      final register = await _datasource.startClosing(registerId);
      return (register: register, failure: null);
    } catch (e) {
      return (register: null, failure: _mapException(e));
    }
  }

  @override
  Future<CashRegisterResult> closeRegister({
    required String registerId,
    required Map<String, int> closingBreakdown,
    required double closingAmount,
    String? closingNotes,
  }) async {
    try {
      final register = await _datasource.closeRegister(
        registerId: registerId,
        closingBreakdown: closingBreakdown,
        closingAmount: closingAmount,
        closingNotes: closingNotes,
      );
      return (register: register, failure: null);
    } catch (e) {
      return (register: null, failure: _mapException(e));
    }
  }

  @override
  Future<ClosingPreviewResult> getClosingPreview({
    required String registerId,
    required double openingAmount,
  }) async {
    try {
      final preview = await _datasource.getClosingPreview(
        registerId: registerId,
        openingAmount: openingAmount,
      );
      return (preview: preview, failure: null);
    } catch (e) {
      return (preview: null, failure: _mapException(e));
    }
  }
}
