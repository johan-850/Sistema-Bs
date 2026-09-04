// ============================================================
// lib/features/pos/domain/repositories/sale_repository.dart
// Contrato del repositorio de ventas — Clean Architecture
// ============================================================

import 'dart:typed_data';

import '../entities/sale.dart';
import '../entities/sale_item.dart';
import '../entities/cart_item.dart';
import '../../../../core/errors/failures.dart';

typedef SaleResult = ({Sale? sale, Failure? failure});

// ── EP-08: historial y reportes (AdminMaster) ──────────────────

typedef SalesHistoryResult = ({List<Sale> sales, Failure? failure});
typedef SaleDetailResult = ({Sale? sale, List<SaleItem> items, Failure? failure});

/// US-048: resumen ejecutivo para las tarjetas KPI del dashboard.
typedef SalesKpis = ({
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
});
typedef SalesKpisResult = ({SalesKpis? kpis, Failure? failure});

// ── EP-09 (S-10): estadísticas y tendencias (AdminMaster) ───────

/// US-050: ranking de productos por unidades/monto vendido en un período.
typedef TopProduct = ({
  String productId,
  String productName,
  int unitsSold,
  double amountTotal,
});
typedef TopProductsResult = ({List<TopProduct> products, Failure? failure});

/// US-051: total vendido por día, para graficar la tendencia.
typedef DailySales = ({DateTime day, double total, int count});
typedef SalesTrendResult = ({List<DailySales> days, Failure? failure});

/// US-052: unidades/monto/margen estimado por categoría de producto.
/// El margen usa el costPrice ACTUAL de cada producto — sale_items no
/// guarda un snapshot de costo histórico (ver Product.costPrice).
typedef CategoryStat = ({
  String category,
  int unitsSold,
  double amountTotal,
  double estimatedMargin,
});
typedef CategoryBreakdownResult = ({List<CategoryStat> categories, Failure? failure});

// ── EP-09 (S-11): desempeño por cajero (AdminMaster) ─────────────

/// US-053: comparativa de ventas por cajero. No incluye "tiempo
/// promedio de venta" — `sales` no guarda un timestamp de inicio de
/// carrito, solo `created_at` (confirmación), así que esa métrica no
/// es calculable con los datos que existen hoy.
typedef CashierPerformance = ({
  String cashierId,
  String cashierName,
  double totalSales,
  int transactionCount,
  double avgTicket,
});
typedef CashierPerformanceResult = ({List<CashierPerformance> cashiers, Failure? failure});

abstract class SaleRepository {
  /// US-030/US-031/US-032: confirma el cobro de una venta de forma
  /// atómica (vía función RPC en Supabase) — crea la venta, sus
  /// ítems y descuenta el stock correspondiente.
  Future<SaleResult> confirmSale({
    required String cashRegisterId,
    required String paymentMethod,
    double? cashAmount,
    double? transferAmount,
    required List<CartItem> items,
    String? receiptPhotoUrl,
  });

  /// Sube la foto del comprobante de transferencia y devuelve su URL
  /// pública. Se sube antes de confirmar el cobro para incluir la URL
  /// en el mismo INSERT atómico de la venta.
  Future<({String? url, Failure? failure})> uploadReceiptPhoto(
    Uint8List bytes,
    String fileExt,
  );

  /// Borra una foto de comprobante previamente subida (best-effort,
  /// ej. cuando el cajero retoma la foto antes de confirmar el cobro).
  Future<void> deleteReceiptPhoto(String photoUrl);

  /// US-032: deja constancia de que el cajero canceló/vació el
  /// carrito antes de confirmar el cobro (fines de auditoría —
  /// no hay stock que revertir, nada se había descontado todavía).
  Future<Failure?> logCancelledSale({
    required String cashRegisterId,
    required int itemsCount,
    required double totalAmount,
  });

  /// US-059: deja constancia de que se mostró la alerta de stock
  /// bajo al agregar [productId] al carrito.
  Future<Failure?> logLowStockAlert({
    required String productId,
    required String productName,
    required int stock,
  });

  /// US-044: historial paginado con filtros — [searchId] es una
  /// búsqueda exacta por ID de venta (UUID completo), no parcial.
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
  });

  /// US-047: la venta + sus ítems, con [SaleItem.isProductArchived]
  /// ya resuelto contra el estado actual de cada producto.
  Future<SaleDetailResult> getSaleDetail(String saleId);

  /// US-048: KPIs para el dashboard del AdminMaster.
  Future<SalesKpisResult> getSalesKpis();

  /// US-050: top productos por unidades vendidas en el rango [from, to].
  /// [category] filtra el ranking a una sola categoría (drill-down de
  /// US-052) — mismo cálculo, sin duplicar lógica.
  Future<TopProductsResult> getTopProducts({
    required DateTime from,
    required DateTime to,
    String? category,
    int limit = 10,
  });

  /// US-051: total vendido por día dentro de [from, to], con ceros en
  /// los días sin ventas (para una línea continua en el gráfico).
  Future<SalesTrendResult> getSalesTrend({
    required DateTime from,
    required DateTime to,
  });

  /// US-052: unidades/monto/margen estimado agrupado por categoría.
  Future<CategoryBreakdownResult> getCategoryBreakdown({
    required DateTime from,
    required DateTime to,
  });

  /// US-053: total vendido/# transacciones/ticket promedio por cajero.
  Future<CashierPerformanceResult> getCashierPerformance({
    required DateTime from,
    required DateTime to,
  });
}
