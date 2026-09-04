// ============================================================
// lib/features/pos/data/repositories/sale_repository_impl.dart
// Implementación del repositorio — convierte excepciones a Failures
// ============================================================

import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/cart_item.dart';
import '../../domain/entities/sale.dart';
import '../../domain/entities/sale_item.dart';
import '../../domain/repositories/sale_repository.dart';
import '../datasources/sale_remote_datasource.dart';
import '../../../../core/errors/failures.dart';

class SaleRepositoryImpl implements SaleRepository {
  final SaleRemoteDatasource _datasource;
  const SaleRepositoryImpl(this._datasource);

  /// Los errores de confirm_sale() (RAISE EXCEPTION) llegan como
  /// PostgrestException con un mensaje ya listo para el usuario
  /// (ej. "Stock insuficiente para...").
  Failure _mapException(Object e) {
    if (e is PostgrestException) {
      if (e.code == '42501' || e.message.contains('policy')) {
        return const PermissionFailure();
      }
      return ValidationFailure(e.message);
    }
    return UnexpectedFailure(e.toString());
  }

  @override
  Future<SaleResult> confirmSale({
    required String cashRegisterId,
    required String paymentMethod,
    double? cashAmount,
    double? transferAmount,
    required List<CartItem> items,
    String? receiptPhotoUrl,
  }) async {
    try {
      final sale = await _datasource.confirmSale(
        cashRegisterId: cashRegisterId,
        paymentMethod: paymentMethod,
        cashAmount: cashAmount,
        transferAmount: transferAmount,
        items: items,
        receiptPhotoUrl: receiptPhotoUrl,
      );
      return (sale: sale, failure: null);
    } catch (e) {
      return (sale: null, failure: _mapException(e));
    }
  }

  @override
  Future<({String? url, Failure? failure})> uploadReceiptPhoto(
    Uint8List bytes,
    String fileExt,
  ) async {
    try {
      final url = await _datasource.uploadReceiptPhoto(bytes, fileExt);
      return (url: url, failure: null);
    } catch (e) {
      return (url: null, failure: _mapException(e));
    }
  }

  @override
  Future<void> deleteReceiptPhoto(String photoUrl) => _datasource.deleteReceiptPhoto(photoUrl);

  @override
  Future<Failure?> logCancelledSale({
    required String cashRegisterId,
    required int itemsCount,
    required double totalAmount,
  }) async {
    try {
      await _datasource.logCancelledSale(
        cashRegisterId: cashRegisterId,
        itemsCount: itemsCount,
        totalAmount: totalAmount,
      );
      return null;
    } catch (e) {
      return _mapException(e);
    }
  }

  @override
  Future<Failure?> logLowStockAlert({
    required String productId,
    required String productName,
    required int stock,
  }) async {
    try {
      await _datasource.logLowStockAlert(
        productId: productId,
        productName: productName,
        stock: stock,
      );
      return null;
    } catch (e) {
      return _mapException(e);
    }
  }

  @override
  Future<SalesHistoryResult> getSalesHistory({
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
    try {
      final sales = await _datasource.getSalesHistory(
        dateFrom: dateFrom,
        dateTo: dateTo,
        cashierId: cashierId,
        paymentMethod: paymentMethod,
        minAmount: minAmount,
        maxAmount: maxAmount,
        searchId: searchId,
        page: page,
        pageSize: pageSize,
      );
      return (sales: sales, failure: null);
    } catch (e) {
      return (sales: <Sale>[], failure: _mapException(e));
    }
  }

  @override
  Future<SaleDetailResult> getSaleDetail(String saleId) async {
    try {
      final result = await _datasource.getSaleDetail(saleId);
      return (sale: result.sale, items: result.items, failure: null);
    } catch (e) {
      return (sale: null, items: <SaleItem>[], failure: _mapException(e));
    }
  }

  @override
  Future<SalesKpisResult> getSalesKpis() async {
    try {
      final k = await _datasource.getSalesKpis();
      return (
        kpis: (
          todayTotal: k.todayTotal,
          todayCount: k.todayCount,
          weekTotal: k.weekTotal,
          weekCount: k.weekCount,
          weekPrevTotal: k.weekPrevTotal,
          monthTotal: k.monthTotal,
          monthCount: k.monthCount,
          monthPrevTotal: k.monthPrevTotal,
          avgTicket: k.avgTicket,
          paymentMethodCounts: k.paymentMethodCounts,
        ),
        failure: null,
      );
    } catch (e) {
      return (kpis: null, failure: _mapException(e));
    }
  }

  @override
  Future<TopProductsResult> getTopProducts({
    required DateTime from,
    required DateTime to,
    String? category,
    int limit = 10,
  }) async {
    try {
      final products = await _datasource.getTopProducts(
        from: from,
        to: to,
        category: category,
        limit: limit,
      );
      return (products: products, failure: null);
    } catch (e) {
      return (products: <TopProduct>[], failure: _mapException(e));
    }
  }

  @override
  Future<SalesTrendResult> getSalesTrend({required DateTime from, required DateTime to}) async {
    try {
      final days = await _datasource.getSalesTrend(from: from, to: to);
      return (days: days, failure: null);
    } catch (e) {
      return (days: <DailySales>[], failure: _mapException(e));
    }
  }

  @override
  Future<CategoryBreakdownResult> getCategoryBreakdown({required DateTime from, required DateTime to}) async {
    try {
      final categories = await _datasource.getCategoryBreakdown(from: from, to: to);
      return (categories: categories, failure: null);
    } catch (e) {
      return (categories: <CategoryStat>[], failure: _mapException(e));
    }
  }

  @override
  Future<CashierPerformanceResult> getCashierPerformance({required DateTime from, required DateTime to}) async {
    try {
      final cashiers = await _datasource.getCashierPerformance(from: from, to: to);
      return (cashiers: cashiers, failure: null);
    } catch (e) {
      return (cashiers: <CashierPerformance>[], failure: _mapException(e));
    }
  }
}
