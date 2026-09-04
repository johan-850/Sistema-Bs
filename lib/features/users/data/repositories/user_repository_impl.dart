import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/cashier.dart';
import '../../domain/repositories/user_repository.dart';
import '../datasources/user_remote_datasource.dart';
import '../../../../core/errors/failures.dart';

/// Implementación concreta de UserRepository
class UserRepositoryImpl implements UserRepository {
  final UserRemoteDatasource _datasource;
  const UserRepositoryImpl(this._datasource);

  @override
  Future<({bool success, Failure? failure})> createCashier({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      await _datasource.createCashier(name: name, email: email, password: password);
      return (success: true, failure: null);
    } on FunctionException catch (e) {
      return (success: false, failure: ServerFailure(e.details?.toString() ?? 'Error en Edge Function'));
    } on Exception catch (e) {
      return (success: false, failure: ServerFailure(e.toString()));
    }
  }

  @override
  Future<({bool success, Failure? failure})> toggleCashierStatus({
    required String cashierId,
    required bool isActive,
  }) async {
    try {
      await _datasource.toggleCashierStatus(cashierId: cashierId, isActive: isActive);
      return (success: true, failure: null);
    } on PostgrestException catch (e) {
      return (success: false, failure: ServerFailure(e.message));
    } on Exception {
      return (success: false, failure: const NetworkFailure());
    }
  }

  @override
  Future<({bool success, Failure? failure})> resetCashierPassword({
    required String email,
  }) async {
    try {
      await _datasource.resetCashierPassword(email: email);
      return (success: true, failure: null);
    } on AuthException catch (e) {
      return (success: false, failure: AuthFailure(e.message));
    } on Exception {
      return (success: false, failure: const NetworkFailure());
    }
  }

  @override
  Future<({List<Cashier>? cashiers, int? totalCount, Failure? failure})> getCashiers({
    bool? filterActive,
    int page = 0,
    int pageSize = 20,
  }) async {
    try {
      final result = await _datasource.getCashiers(
        filterActive: filterActive,
        page: page,
        pageSize: pageSize,
      );
      return (cashiers: result.cashiers, totalCount: result.totalCount, failure: null);
    } on PostgrestException catch (e) {
      return (cashiers: null, totalCount: null, failure: ServerFailure(e.message));
    } on Exception {
      return (cashiers: null, totalCount: null, failure: const NetworkFailure());
    }
  }

  @override
  Future<({String? csvContent, Failure? failure})> exportCashiersToCSV() async {
    try {
      final cashiers = await _datasource.getAllCashiersForExport();
      final fmt = DateFormat('dd/MM/yyyy HH:mm');

      final rows = [
        ['Nombre', 'Correo', 'Estado', 'Último acceso', 'Creado'],
        ...cashiers.map((c) => [
              c.name,
              c.email,
              c.isActive ? 'Activo' : 'Inactivo',
              c.lastLogin != null ? fmt.format(c.lastLogin!) : 'Nunca',
              fmt.format(c.createdAt),
            ]),
      ];

      final csv = const ListToCsvConverter().convert(rows);
      return (csvContent: csv, failure: null);
    } on Exception catch (e) {
      return (csvContent: null, failure: ServerFailure(e.toString()));
    }
  }
}
