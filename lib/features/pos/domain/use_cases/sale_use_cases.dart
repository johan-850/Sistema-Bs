// ============================================================
// lib/features/pos/domain/use_cases/sale_use_cases.dart
// Caso de uso de cobro — US-030, US-031, US-032
// ============================================================

import 'dart:typed_data';

import '../entities/cart_item.dart';
import '../repositories/sale_repository.dart';
import '../../../../core/errors/failures.dart';

/// Confirma el cobro de la venta actual (entrada/salida de stock
/// atómica ya resuelta por la función RPC en el repositorio).
class ConfirmSaleUseCase {
  final SaleRepository _repository;
  const ConfirmSaleUseCase(this._repository);

  Future<SaleResult> call({
    required String cashRegisterId,
    required String paymentMethod,
    double? cashAmount,
    double? transferAmount,
    required List<CartItem> items,
    String? receiptPhotoUrl,
  }) =>
      _repository.confirmSale(
        cashRegisterId: cashRegisterId,
        paymentMethod: paymentMethod,
        cashAmount: cashAmount,
        transferAmount: transferAmount,
        items: items,
        receiptPhotoUrl: receiptPhotoUrl,
      );
}

/// Sube la foto del comprobante de transferencia (antes de confirmar el cobro).
class UploadReceiptPhotoUseCase {
  final SaleRepository _repository;
  const UploadReceiptPhotoUseCase(this._repository);

  Future<({String? url, Failure? failure})> call(Uint8List bytes, String fileExt) =>
      _repository.uploadReceiptPhoto(bytes, fileExt);
}

/// Borra una foto de comprobante ya subida (ej. el cajero la retoma).
class DeleteReceiptPhotoUseCase {
  final SaleRepository _repository;
  const DeleteReceiptPhotoUseCase(this._repository);

  Future<void> call(String photoUrl) => _repository.deleteReceiptPhoto(photoUrl);
}

/// US-032: registra la cancelación del carrito para auditoría.
class LogCancelledSaleUseCase {
  final SaleRepository _repository;
  const LogCancelledSaleUseCase(this._repository);

  Future<Failure?> call({
    required String cashRegisterId,
    required int itemsCount,
    required double totalAmount,
  }) =>
      _repository.logCancelledSale(
        cashRegisterId: cashRegisterId,
        itemsCount: itemsCount,
        totalAmount: totalAmount,
      );
}

/// US-059: registra la alerta de stock bajo mostrada en el POS.
class LogLowStockAlertUseCase {
  final SaleRepository _repository;
  const LogLowStockAlertUseCase(this._repository);

  Future<Failure?> call({
    required String productId,
    required String productName,
    required int stock,
  }) =>
      _repository.logLowStockAlert(
        productId: productId,
        productName: productName,
        stock: stock,
      );
}

/// US-044: historial de ventas con filtros (AdminMaster).
class GetSalesHistoryUseCase {
  final SaleRepository _repository;
  const GetSalesHistoryUseCase(this._repository);

  Future<SalesHistoryResult> call({
    DateTime? dateFrom,
    DateTime? dateTo,
    String? cashierId,
    String? paymentMethod,
    double? minAmount,
    double? maxAmount,
    String? searchId,
    int page = 0,
    int pageSize = 20,
  }) =>
      _repository.getSalesHistory(
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
}

/// US-047/US-049: detalle de una venta histórica.
class GetSaleDetailUseCase {
  final SaleRepository _repository;
  const GetSaleDetailUseCase(this._repository);

  Future<SaleDetailResult> call(String saleId) => _repository.getSaleDetail(saleId);
}

/// US-048: KPIs para el dashboard del AdminMaster.
class GetSalesKpisUseCase {
  final SaleRepository _repository;
  const GetSalesKpisUseCase(this._repository);

  Future<SalesKpisResult> call() => _repository.getSalesKpis();
}

/// US-050: ranking de productos más vendidos en un período.
class GetTopProductsUseCase {
  final SaleRepository _repository;
  const GetTopProductsUseCase(this._repository);

  Future<TopProductsResult> call({
    required DateTime from,
    required DateTime to,
    String? category,
    int limit = 10,
  }) =>
      _repository.getTopProducts(from: from, to: to, category: category, limit: limit);
}

/// US-051: tendencia de ventas diarias en un período.
class GetSalesTrendUseCase {
  final SaleRepository _repository;
  const GetSalesTrendUseCase(this._repository);

  Future<SalesTrendResult> call({required DateTime from, required DateTime to}) =>
      _repository.getSalesTrend(from: from, to: to);
}

/// US-052: rentabilidad estimada por categoría de producto.
class GetCategoryBreakdownUseCase {
  final SaleRepository _repository;
  const GetCategoryBreakdownUseCase(this._repository);

  Future<CategoryBreakdownResult> call({required DateTime from, required DateTime to}) =>
      _repository.getCategoryBreakdown(from: from, to: to);
}

/// US-053: comparativa de desempeño por cajero.
class GetCashierPerformanceUseCase {
  final SaleRepository _repository;
  const GetCashierPerformanceUseCase(this._repository);

  Future<CashierPerformanceResult> call({required DateTime from, required DateTime to}) =>
      _repository.getCashierPerformance(from: from, to: to);
}
