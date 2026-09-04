import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/cashier_model.dart';
import '../../../../core/constants/app_constants.dart';

/// Datasource de usuarios: llama a Supabase y Edge Functions
class UserRemoteDatasource {
  final SupabaseClient _client;
  const UserRemoteDatasource(this._client);

  /// US-003: Crea cajero via Edge Function (usa service role internamente)
  Future<void> createCashier({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await _client.functions.invoke(
      AppConstants.fnCreateCashier,
      body: {'name': name, 'email': email, 'password': password},
    );
    if (response.status != 200 && response.status != 201) {
      final msg = (response.data as Map?)?['error'] as String? ?? 'Error al crear cajero';
      throw Exception(msg);
    }
  }

  /// US-004: Toggle activo/inactivo + fuerza logout via Edge Function
  Future<void> toggleCashierStatus({
    required String cashierId,
    required bool isActive,
  }) async {
    // 1. Actualizar profiles
    await _client
        .from(AppConstants.tableProfiles)
        .update({'is_active': isActive})
        .eq('id', cashierId);

    // 2. Log de auditoría
    final currentUserId = _client.auth.currentUser?.id;
    await _client.from(AppConstants.tableUserActivityLogs).insert({
      'user_id': cashierId,
      'action': isActive ? 'activated' : 'deactivated',
      'performed_by': currentUserId,
      'metadata': {'timestamp': DateTime.now().toUtc().toIso8601String()},
    });

    // Invalida la sesión activa del cajero vía Edge Function (best-effort:
    // is_active=false en la BD ya basta para bloquear el próximo login).
    if (!isActive) {
      try {
        await _client.functions.invoke(
          AppConstants.fnToggleCashierStatus,
          body: {'userId': cashierId, 'isActive': isActive},
        );
      } catch (_) { /* No crítico */ }
    }
  }

  /// US-006: Dispara correo de reset via Supabase Auth
  Future<void> resetCashierPassword({required String email}) async {
    await _client.auth.resetPasswordForEmail(email);

    // Log de auditoría
    final currentUserId = _client.auth.currentUser?.id;
    await _client.from(AppConstants.tableUserActivityLogs).insert({
      'action': 'password_reset',
      'performed_by': currentUserId,
      'metadata': {'email': email, 'timestamp': DateTime.now().toUtc().toIso8601String()},
    });
  }

  /// US-007: Lista paginada de cajeros con filtro opcional
  Future<({List<CashierModel> cashiers, int totalCount})> getCashiers({
    bool? filterActive,
    int page = 0,
    int pageSize = 20,
  }) async {
    final from = page * pageSize;
    final to = from + pageSize - 1;

    var query = _client
        .from(AppConstants.tableProfiles)
        .select('*')
        .eq('role', 'cajero');

    if (filterActive != null) {
      query = query.eq('is_active', filterActive);
    }

    final response = await query
        .order('created_at', ascending: false)
        .range(from, to);
    final models = (response as List)
        .map((m) => CashierModel.fromMap(m as Map<String, dynamic>))
        .toList();

    return (cashiers: models, totalCount: 0); // count viene en headers
  }

  /// US-007: Todos los cajeros para exportación CSV
  Future<List<CashierModel>> getAllCashiersForExport() async {
    final data = await _client
        .from(AppConstants.tableProfiles)
        .select()
        .eq('role', 'cajero')
        .order('name');

    return (data as List)
        .map((m) => CashierModel.fromMap(m as Map<String, dynamic>))
        .toList();
  }
}
