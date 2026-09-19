// ============================================================
// lib/features/cash_register/data/datasources/cash_register_remote_datasource.dart
// Fuente de datos remota — Supabase
// ============================================================

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/cash_register.dart';
import '../../domain/repositories/cash_register_repository.dart' show ClosingPreview;
import '../../../../core/constants/app_constants.dart';

class CashRegisterRemoteDatasource {
  final SupabaseClient _client;
  const CashRegisterRemoteDatasource(this._client);

  // ── Mapeo de JSON → Entidad ────────────────────────────────

  CashRegister _fromJson(Map<String, dynamic> json) {
    // El desglose llega como Map<String, dynamic>; lo convertimos a Map<String, int>
    final rawBreakdown = (json['opening_breakdown'] as Map<String, dynamic>?) ?? {};
    final openingBreakdown = rawBreakdown.map(
      (k, v) => MapEntry(k, (v as num).toInt()),
    );

    final rawClosingBreakdown =
        (json['closing_breakdown'] as Map<String, dynamic>?);
    final closingBreakdown = rawClosingBreakdown?.map(
      (k, v) => MapEntry(k, (v as num).toInt()),
    );

    // El join con profiles viene como nested map en 'profiles'
    final profile = json['profiles'] as Map<String, dynamic>?;
    final cashierName = profile?['name'] as String?;

    final rawSummary = json['closing_summary'] as Map<String, dynamic>?;

    return CashRegister(
      id: json['id'] as String,
      cashierId: json['cashier_id'] as String,
      cashierName: cashierName,
      openingAmount: (json['opening_amount'] as num).toDouble(),
      openingBreakdown: openingBreakdown,
      notes: json['notes'] as String?,
      closingAmount: json['closing_amount'] != null
          ? (json['closing_amount'] as num).toDouble()
          : null,
      closingBreakdown: closingBreakdown,
      closingNotes: json['closing_notes'] as String?,
      closingSummary: rawSummary != null ? ClosingSummary.fromJson(rawSummary) : null,
      openingTime: DateTime.parse(json['opening_time'] as String),
      closingTime: json['closing_time'] != null
          ? DateTime.parse(json['closing_time'] as String)
          : null,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  // ── US-008: Obtener caja activa del cajero ─────────────────

  /// Busca la caja sin cerrar del cajero actual. Retorna null si no hay.
  ///
  /// La pregunta correcta es "¿este cajero tiene una caja sin cerrar?",
  /// no "¿abrió una hoy?". Antes había un filtro `opening_time >= hoy`
  /// calculado con `DateTime.utc(...)`, y ahí estaba el bug del turno
  /// activo: Colombia es UTC−5, así que la medianoche UTC son las 7 de
  /// la tarde locales. Una caja abierta a las 10 a.m. dejaba de cumplir
  /// el filtro a las 7 p.m., en pleno turno. El cajero veía "no tienes
  /// turno abierto", abría otra, y quedaban dos cajas abiertas: al
  /// cerrar una, la pantalla seguía mostrando la otra como turno activo.
  ///
  /// Se incluye 'closing' además de 'open' para que un cierre abandonado
  /// a mitad de camino se pueda retomar en vez de quedar huérfano, y se
  /// ordena de forma explícita para que el resultado sea determinista
  /// mientras existan duplicados de antes del arreglo.
  Future<CashRegister?> getActiveRegister(String cashierId) async {
    final result = await _client
        .from(AppConstants.tableCashRegisters)
        .select('*, profiles(name)')
        .eq('cashier_id', cashierId)
        .inFilter('status', ['open', 'closing'])
        .order('opening_time', ascending: false)
        .limit(1)
        .maybeSingle();

    if (result == null) return null;
    return _fromJson(result);
  }

  // ── US-009 + US-010: Abrir caja con desglose y notas ───────

  /// Inserta una nueva apertura de caja en Supabase.
  /// El timestamp (US-012) se genera automáticamente con DEFAULT NOW() en BD.
  Future<CashRegister> openRegister({
    required String cashierId,
    required Map<String, int> openingBreakdown,
    required double openingAmount,
    String? notes,
  }) async {
    final payload = {
      'cashier_id': cashierId,
      'opening_amount': openingAmount,
      'opening_breakdown': openingBreakdown,
      'status': 'open',
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    };

    final result = await _client
        .from(AppConstants.tableCashRegisters)
        .insert(payload)
        .select('*, profiles(name)')
        .single();

    return _fromJson(result);
  }

  // ── US-011: Historial para AdminMaster ────────────────────

  /// Obtiene el historial de aperturas filtrado y paginado.
  Future<List<CashRegister>> getRegisterHistory({
    String? cashierId,
    DateTime? from,
    DateTime? to,
    int page = 0,
    int pageSize = 20,
  }) async {
    // Construir filtros antes de aplicar order/range
    var query = _client
        .from(AppConstants.tableCashRegisters)
        .select('*, profiles(name)');

    // Los filtros deben ir ANTES de order() y range()
    if (cashierId != null) {
      query = query.eq('cashier_id', cashierId);
    }
    if (from != null) {
      query = query.gte('opening_time', from.toIso8601String());
    }
    if (to != null) {
      final endOfDay = DateTime(to.year, to.month, to.day, 23, 59, 59).toUtc();
      query = query.lte('opening_time', endOfDay.toIso8601String());
    }

    final results = await query
        .order('opening_time', ascending: false)
        .range(page * pageSize, (page + 1) * pageSize - 1);

    return results.map<CashRegister>(_fromJson).toList();
  }

  // ── US-039: Iniciar cierre ─────────────────────────────────

  Future<CashRegister> startClosing(String registerId) async {
    final result = await _client.rpc('start_register_closing', params: {
      'p_register_id': registerId,
    });
    return _fromJson(result as Map<String, dynamic>);
  }

  // ── US-040/041/042: Confirmar cierre ───────────────────────

  Future<CashRegister> closeRegister({
    required String registerId,
    required Map<String, int> closingBreakdown,
    required double closingAmount,
    String? closingNotes,
  }) async {
    final result = await _client.rpc('close_register', params: {
      'p_register_id': registerId,
      'p_closing_breakdown': closingBreakdown,
      'p_closing_amount': closingAmount,
      'p_closing_notes': closingNotes,
    });
    return _fromJson(result as Map<String, dynamic>);
  }

  // ── US-039: Resumen previo (solo lectura, no vinculante) ───

  /// Mismo cálculo que hace close_register() en el servidor, pero de
  /// solo lectura — se usa para el resumen previo antes de iniciar el
  /// cierre. El cálculo definitivo y vinculante siempre lo hace la
  /// función RPC, nunca este método.
  Future<ClosingPreview> getClosingPreview({
    required String registerId,
    required double openingAmount,
  }) async {
    final salesRows = await _client
        .from('sales')
        .select('total, payment_method, cash_amount')
        .eq('cash_register_id', registerId) as List;

    double salesTotal = 0;
    double cashIn = 0;
    for (final row in salesRows) {
      final r = row as Map<String, dynamic>;
      final total = (r['total'] as num).toDouble();
      salesTotal += total;
      final method = r['payment_method'] as String;
      if (method == 'efectivo') {
        cashIn += total;
      } else if (method == 'mixto') {
        cashIn += (r['cash_amount'] as num?)?.toDouble() ?? 0;
      }
    }

    final expenseRows = await _client
        .from(AppConstants.tableExpenses)
        .select('amount')
        .eq('cash_register_id', registerId) as List;
    final expensesTotal = expenseRows.fold<double>(
        0, (sum, row) => sum + ((row as Map<String, dynamic>)['amount'] as num).toDouble());

    return (
      salesTotal: salesTotal,
      expensesTotal: expensesTotal,
      expectedCash: openingAmount + cashIn - expensesTotal,
      transactionCount: salesRows.length,
    );
  }
}
