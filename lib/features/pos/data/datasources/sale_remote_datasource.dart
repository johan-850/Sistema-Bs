// ============================================================
// lib/features/pos/data/datasources/sale_remote_datasource.dart
// Datasource remoto — llama a la función RPC confirm_sale
// ============================================================

import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/sale.dart';
import '../../domain/entities/sale_item.dart';
import '../../domain/entities/cart_item.dart';
import '../../domain/repositories/sale_repository.dart'
    show TopProduct, DailySales, CategoryStat, CashierPerformance;
import '../../../../core/constants/app_constants.dart';

class SaleRemoteDatasource {
  final SupabaseClient _client;
  const SaleRemoteDatasource(this._client);

  Sale _fromJson(Map<String, dynamic> json) {
    // El join con profiles (cuando la query lo pide) viene como mapa
    // anidado en 'profiles' — el RPC confirm_sale no lo trae porque
    // devuelve la fila plana de `sales`, no hace falta ahí.
    final profile = json['profiles'] as Map<String, dynamic>?;

    // US-044: sale_items embebidos (solo cuando la query los pide con
    // `sale_items(product_name, quantity)`) — resumen para la fila del
    // historial sin tener que abrir el detalle de cada venta.
    final rawItems = json['sale_items'] as List<dynamic>?;
    final itemsPreview = rawItems == null
        ? const <String>[]
        : rawItems
            .map((e) => e as Map<String, dynamic>)
            .map((e) => '${e['product_name']} x${(e['quantity'] as num).toInt()}')
            .toList();

    return Sale(
      id: json['id'] as String,
      total: (json['total'] as num).toDouble(),
      paymentMethod: json['payment_method'] as String,
      cashAmount: (json['cash_amount'] as num?)?.toDouble(),
      transferAmount: (json['transfer_amount'] as num?)?.toDouble(),
      changeAmount: (json['change_amount'] as num?)?.toDouble(),
      receiptPhotoUrl: json['receipt_photo_url'] as String?,
      cashierId: json['cashier_id'] as String?,
      cashierName: profile?['name'] as String?,
      cashRegisterId: json['cash_register_id'] as String?,
      status: json['status'] as String? ?? 'completed',
      itemsPreview: itemsPreview,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  SaleItem _itemFromJson(Map<String, dynamic> json, {bool isArchived = false}) => SaleItem(
        id: json['id'] as String,
        saleId: json['sale_id'] as String,
        productId: json['product_id'] as String,
        productName: json['product_name'] as String,
        quantity: (json['quantity'] as num).toInt(),
        unitPrice: (json['unit_price'] as num).toDouble(),
        subtotal: (json['subtotal'] as num).toDouble(),
        isProductArchived: isArchived,
      );

  Future<Sale> confirmSale({
    required String cashRegisterId,
    required String paymentMethod,
    double? cashAmount,
    double? transferAmount,
    required List<CartItem> items,
    String? receiptPhotoUrl,
  }) async {
    final response = await _client.rpc(AppConstants.rpcConfirmSale, params: {
      'p_cash_register_id': cashRegisterId,
      'p_payment_method': paymentMethod,
      'p_cash_amount': cashAmount,
      'p_transfer_amount': transferAmount,
      'p_items': items
          .map((i) => {
                'product_id': i.productId,
                'quantity': i.quantity,
                'unit_price': i.unitPrice,
                'product_name': i.name,
              })
          .toList(),
      'p_receipt_photo_url': receiptPhotoUrl,
    });

    return _fromJson(response as Map<String, dynamic>);
  }

  /// Sube la foto del comprobante de transferencia a Storage y devuelve
  /// su URL pública. Mismo patrón que uploadProductImage (EP-03).
  Future<String> uploadReceiptPhoto(Uint8List bytes, String fileExt) async {
    final path = 'receipts/${const Uuid().v4()}.$fileExt';
    await _client.storage
        .from(AppConstants.storageBucketReceiptPhotos)
        .uploadBinary(path, bytes, fileOptions: const FileOptions(upsert: true));

    return _client.storage
        .from(AppConstants.storageBucketReceiptPhotos)
        .getPublicUrl(path);
  }

  /// Borra una foto de comprobante a partir de su URL pública.
  /// Best-effort: no propaga errores (ej. el cajero retomó la foto).
  Future<void> deleteReceiptPhoto(String photoUrl) async {
    try {
      final marker = '/object/public/${AppConstants.storageBucketReceiptPhotos}/';
      final idx = photoUrl.indexOf(marker);
      if (idx == -1) return;
      final path = photoUrl.substring(idx + marker.length);
      await _client.storage.from(AppConstants.storageBucketReceiptPhotos).remove([path]);
    } catch (_) {
      /* No crítico */
    }
  }

  /// US-032: cashier_id se completa server-side (DEFAULT auth.uid())
  /// — no hace falta ni conviene mandarlo desde el cliente.
  Future<void> logCancelledSale({
    required String cashRegisterId,
    required int itemsCount,
    required double totalAmount,
  }) async {
    await _client.from(AppConstants.tableSaleCancellations).insert({
      'cash_register_id': cashRegisterId,
      'items_count': itemsCount,
      'total_amount': totalAmount,
    });
  }

  /// US-059: idem, cashier_id server-side.
  Future<void> logLowStockAlert({
    required String productId,
    required String productName,
    required int stock,
  }) async {
    await _client.from(AppConstants.tableLowStockAlerts).insert({
      'product_id': productId,
      'product_name': productName,
      'stock_at_alert': stock,
    });
  }

  // ── EP-08: historial y reportes (AdminMaster) ──────────────

  Future<List<Sale>> getSalesHistory({
    DateTime? dateFrom,
    DateTime? dateTo,
    String? cashierId,
    String? paymentMethod,
    double? minAmount,
    double? maxAmount,
    String? searchId,
    int page = 0,
    int pageSize = 20,
  }) async {
    // US-044: sale_items(product_name, quantity) embebido — evita una
    // consulta N+1 por fila para mostrar qué se vendió en el historial.
    var q = _client.from(AppConstants.tableSales).select('*, profiles(name), sale_items(product_name, quantity)');

    if (searchId != null && searchId.trim().isNotEmpty) {
      q = q.eq('id', searchId.trim());
    } else {
      if (dateFrom != null) q = q.gte('created_at', dateFrom.toUtc().toIso8601String());
      if (dateTo != null) q = q.lte('created_at', dateTo.toUtc().toIso8601String());
      if (cashierId != null) q = q.eq('cashier_id', cashierId);
      if (paymentMethod != null) q = q.eq('payment_method', paymentMethod);
      if (minAmount != null) q = q.gte('total', minAmount);
      if (maxAmount != null) q = q.lte('total', maxAmount);
    }

    final result = await q
        .order('created_at', ascending: false)
        .range(page * pageSize, (page + 1) * pageSize - 1);
    return (result as List).map((e) => _fromJson(e as Map<String, dynamic>)).toList();
  }

  /// US-047/US-049: la venta, sus ítems, y si cada producto sigue
  /// activo hoy (para la etiqueta "Archivado" del detalle).
  Future<({Sale sale, List<SaleItem> items})> getSaleDetail(String saleId) async {
    final saleJson = await _client
        .from(AppConstants.tableSales)
        .select('*, profiles(name)')
        .eq('id', saleId)
        .single();

    final itemsResult = await _client
        .from(AppConstants.tableSaleItems)
        .select()
        .eq('sale_id', saleId) as List;

    final productIds = itemsResult.map((e) => (e as Map<String, dynamic>)['product_id'] as String).toSet();
    var archivedIds = <String>{};
    if (productIds.isNotEmpty) {
      final productsResult = await _client
          .from(AppConstants.tableProducts)
          .select('id, is_active')
          .inFilter('id', productIds.toList()) as List;
      archivedIds = productsResult
          .where((p) => (p as Map<String, dynamic>)['is_active'] == false)
          .map((p) => (p as Map<String, dynamic>)['id'] as String)
          .toSet();
    }

    final items = itemsResult
        .map((e) => _itemFromJson(
              e as Map<String, dynamic>,
              isArchived: archivedIds.contains(e['product_id']),
            ))
        .toList();

    return (sale: _fromJson(saleJson), items: items);
  }

  /// US-048: varias sumas del lado del cliente — mismo criterio ya
  /// usado en getSalesTotalForPeriod (EP-06) y getClosingPreview (EP-07),
  /// no hay una función de agregación remota para esto.
  Future<({double total, int count})> _sumSales({DateTime? from, DateTime? to}) async {
    var q = _client.from(AppConstants.tableSales).select('total');
    if (from != null) q = q.gte('created_at', from.toUtc().toIso8601String());
    if (to != null) q = q.lt('created_at', to.toUtc().toIso8601String());
    final rows = await q as List;
    final total = rows.fold<double>(0, (sum, r) => sum + ((r as Map<String, dynamic>)['total'] as num).toDouble());
    return (total: total, count: rows.length);
  }

  Future<({
    double todayTotal,
    int todayCount,
    double weekTotal,
    int weekCount,
    double weekPrevTotal,
    double monthTotal,
    int monthCount,
    double monthPrevTotal,
    double avgTicket,
    Map<String, int> paymentMethodCounts,
  })> getSalesKpis() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
    final weekPrevStart = weekStart.subtract(const Duration(days: 7));
    final monthStart = DateTime(now.year, now.month);
    final monthPrevStart = DateTime(now.year, now.month - 1);

    final today = await _sumSales(from: todayStart, to: now);
    final week = await _sumSales(from: weekStart, to: now);
    final weekPrev = await _sumSales(from: weekPrevStart, to: weekStart);
    final month = await _sumSales(from: monthStart, to: now);
    final monthPrev = await _sumSales(from: monthPrevStart, to: monthStart);

    final methodRows = await _client
        .from(AppConstants.tableSales)
        .select('payment_method')
        .gte('created_at', monthStart.toUtc().toIso8601String()) as List;
    final methodCounts = <String, int>{};
    for (final row in methodRows) {
      final method = (row as Map<String, dynamic>)['payment_method'] as String;
      methodCounts[method] = (methodCounts[method] ?? 0) + 1;
    }

    return (
      todayTotal: today.total,
      todayCount: today.count,
      weekTotal: week.total,
      weekCount: week.count,
      weekPrevTotal: weekPrev.total,
      monthTotal: month.total,
      monthCount: month.count,
      monthPrevTotal: monthPrev.total,
      avgTicket: month.count > 0 ? month.total / month.count : 0.0,
      paymentMethodCounts: methodCounts,
    );
  }

  // ── EP-09 (S-10): estadísticas y tendencias ─────────────────

  /// Ids de `sales` en el rango — primer paso del patrón en dos
  /// consultas ya usado en `getSaleDetail` (evita depender de un
  /// filtro embebido `sale_items.sales!inner(created_at)` no probado
  /// en este proyecto). Límite superior exclusivo (`lt`), igual que
  /// `_sumSales` en `getSalesKpis` — evita contar dos veces una venta
  /// justo en el límite entre el período actual y el anterior.
  Future<List<String>> _saleIdsInRange({required DateTime from, required DateTime to}) async {
    final rows = await _client
        .from(AppConstants.tableSales)
        .select('id')
        .gte('created_at', from.toUtc().toIso8601String())
        .lt('created_at', to.toUtc().toIso8601String()) as List;
    return rows.map((r) => (r as Map<String, dynamic>)['id'] as String).toList();
  }

  Future<List<TopProduct>> getTopProducts({
    required DateTime from,
    required DateTime to,
    String? category,
    int limit = 10,
  }) async {
    final saleIds = await _saleIdsInRange(from: from, to: to);
    if (saleIds.isEmpty) return const [];

    final rows = await _client
        .from(AppConstants.tableSaleItems)
        .select('product_id, product_name, quantity, subtotal, products(category)')
        .inFilter('sale_id', saleIds) as List;

    final byProduct = <String, ({String name, int units, double amount})>{};
    for (final r in rows) {
      final row = r as Map<String, dynamic>;
      if (category != null) {
        final rowCategory = (row['products'] as Map<String, dynamic>?)?['category'] as String?;
        if (rowCategory != category) continue;
      }
      final productId = row['product_id'] as String;
      final quantity = (row['quantity'] as num).toInt();
      final subtotal = (row['subtotal'] as num).toDouble();
      final prev = byProduct[productId];
      byProduct[productId] = (
        name: row['product_name'] as String,
        units: (prev?.units ?? 0) + quantity,
        amount: (prev?.amount ?? 0) + subtotal,
      );
    }

    final list = byProduct.entries
        .map((e) => (
              productId: e.key,
              productName: e.value.name,
              unitsSold: e.value.units,
              amountTotal: e.value.amount,
            ))
        .toList()
      ..sort((a, b) => b.unitsSold.compareTo(a.unitsSold));

    return list.take(limit).toList();
  }

  Future<List<DailySales>> getSalesTrend({required DateTime from, required DateTime to}) async {
    final rows = await _client
        .from(AppConstants.tableSales)
        .select('created_at, total')
        .gte('created_at', from.toUtc().toIso8601String())
        .lt('created_at', to.toUtc().toIso8601String()) as List;

    final byDay = <DateTime, ({double total, int count})>{};
    for (final r in rows) {
      final row = r as Map<String, dynamic>;
      final createdAt = DateTime.parse(row['created_at'] as String).toLocal();
      final day = DateTime(createdAt.year, createdAt.month, createdAt.day);
      final total = (row['total'] as num).toDouble();
      final prev = byDay[day];
      byDay[day] = (total: (prev?.total ?? 0) + total, count: (prev?.count ?? 0) + 1);
    }

    // Rellena con ceros los días sin ventas para una línea continua.
    final fromDay = DateTime(from.year, from.month, from.day);
    final toDay = DateTime(to.year, to.month, to.day);
    final days = <DailySales>[];
    for (var d = fromDay; !d.isAfter(toDay); d = d.add(const Duration(days: 1))) {
      final entry = byDay[d];
      days.add((day: d, total: entry?.total ?? 0.0, count: entry?.count ?? 0));
    }
    return days;
  }

  Future<List<CategoryStat>> getCategoryBreakdown({required DateTime from, required DateTime to}) async {
    final saleIds = await _saleIdsInRange(from: from, to: to);
    if (saleIds.isEmpty) return const [];

    final rows = await _client
        .from(AppConstants.tableSaleItems)
        .select('quantity, subtotal, unit_price, products(category, cost_price)')
        .inFilter('sale_id', saleIds) as List;

    final byCategory = <String, ({int units, double amount, double margin})>{};
    for (final r in rows) {
      final row = r as Map<String, dynamic>;
      final product = row['products'] as Map<String, dynamic>?;
      final category = product?['category'] as String? ?? 'Otros';
      final costPrice = (product?['cost_price'] as num?)?.toDouble() ?? 0.0;
      final quantity = (row['quantity'] as num).toInt();
      final subtotal = (row['subtotal'] as num).toDouble();
      final unitPrice = (row['unit_price'] as num).toDouble();
      final margin = (unitPrice - costPrice) * quantity;

      final prev = byCategory[category];
      byCategory[category] = (
        units: (prev?.units ?? 0) + quantity,
        amount: (prev?.amount ?? 0) + subtotal,
        margin: (prev?.margin ?? 0) + margin,
      );
    }

    final list = byCategory.entries
        .map((e) => (
              category: e.key,
              unitsSold: e.value.units,
              amountTotal: e.value.amount,
              estimatedMargin: e.value.margin,
            ))
        .toList()
      ..sort((a, b) => b.estimatedMargin.compareTo(a.estimatedMargin));

    return list;
  }

  Future<List<CashierPerformance>> getCashierPerformance({
    required DateTime from,
    required DateTime to,
  }) async {
    final rows = await _client
        .from(AppConstants.tableSales)
        .select('cashier_id, total, profiles(name)')
        .gte('created_at', from.toUtc().toIso8601String())
        .lt('created_at', to.toUtc().toIso8601String()) as List;

    final byCashier = <String, ({String name, double total, int count})>{};
    for (final r in rows) {
      final row = r as Map<String, dynamic>;
      final cashierId = row['cashier_id'] as String?;
      if (cashierId == null) continue;
      final name = (row['profiles'] as Map<String, dynamic>?)?['name'] as String? ?? 'Cajero';
      final total = (row['total'] as num).toDouble();

      final prev = byCashier[cashierId];
      byCashier[cashierId] = (
        name: name,
        total: (prev?.total ?? 0) + total,
        count: (prev?.count ?? 0) + 1,
      );
    }

    final list = byCashier.entries
        .map((e) => (
              cashierId: e.key,
              cashierName: e.value.name,
              totalSales: e.value.total,
              transactionCount: e.value.count,
              avgTicket: e.value.count > 0 ? e.value.total / e.value.count : 0.0,
            ))
        .toList()
      ..sort((a, b) => b.totalSales.compareTo(a.totalSales));

    return list;
  }
}
