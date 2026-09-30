// ============================================================
// tool/preview/fake_repositories.dart
// Repositorios en memoria para la vista previa (ver main.dart).
// Solo implementan las lecturas; cualquier escritura cae en
// noSuchMethod y falla, que es lo esperado en una demo.
// ============================================================

import 'dart:async';

import 'package:sistema_bs/core/errors/failures.dart';
import 'package:sistema_bs/features/auth/domain/entities/app_user.dart';
import 'package:sistema_bs/features/auth/domain/repositories/auth_repository.dart';
import 'package:sistema_bs/features/cash_register/domain/entities/cash_register.dart';
import 'package:sistema_bs/features/cash_register/domain/repositories/cash_register_repository.dart';
import 'package:sistema_bs/features/expenses/domain/entities/expense.dart';
import 'package:sistema_bs/features/expenses/domain/entities/expense_category.dart';
import 'package:sistema_bs/features/expenses/domain/repositories/expense_repository.dart';
import 'package:sistema_bs/features/inventory/domain/entities/restock_request.dart';
import 'package:sistema_bs/features/inventory/domain/entities/stock_movement.dart';
import 'package:sistema_bs/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:sistema_bs/features/pos/domain/entities/sale.dart';
import 'package:sistema_bs/features/pos/domain/entities/sale_item.dart';
import 'package:sistema_bs/features/pos/domain/repositories/sale_repository.dart';
import 'package:sistema_bs/features/products/domain/entities/product.dart';
import 'package:sistema_bs/features/products/domain/repositories/product_repository.dart';
import 'package:sistema_bs/features/settings/domain/entities/store_settings.dart';
import 'package:sistema_bs/features/settings/domain/repositories/store_settings_repository.dart';
import 'package:sistema_bs/features/users/domain/entities/cashier.dart';
import 'package:sistema_bs/features/users/domain/repositories/user_repository.dart';

final _now = DateTime.now();
DateTime _ago({int days = 0, int hours = 0, int minutes = 0}) =>
    _now.subtract(Duration(days: days, hours: hours, minutes: minutes));

// ── Usuarios ──────────────────────────────────────────────────

final previewAdmin = AppUser(
  id: 'u-admin',
  email: 'admin@demo.local',
  name: 'Laura Gómez',
  role: 'adminmaster',
  isActive: true,
  createdAt: _ago(days: 120),
);

final previewCashier = AppUser(
  id: 'u-caj-1',
  email: 'caja1@demo.local',
  name: 'Andrés Pérez',
  role: 'cajero',
  isActive: true,
  createdAt: _ago(days: 60),
);

final _cashiers = [
  Cashier(id: 'u-caj-1', email: 'caja1@demo.local', name: 'Andrés Pérez', isActive: true, lastLogin: _ago(hours: 2), createdAt: _ago(days: 60)),
  Cashier(id: 'u-caj-2', email: 'caja2@demo.local', name: 'Marcela Ruiz', isActive: true, lastLogin: _ago(days: 1), createdAt: _ago(days: 45)),
  Cashier(id: 'u-caj-3', email: 'caja3@demo.local', name: 'Julián Torres', isActive: false, expensesEnabled: false, lastLogin: _ago(days: 20), createdAt: _ago(days: 90)),
];

// ── Productos ─────────────────────────────────────────────────

Product _p(int i, String name, String category, double price, int stock,
        {int minStock = 5, String unit = 'unidad'}) =>
    Product(
      id: 'p-$i',
      barcode: '77012345${i.toString().padLeft(5, '0')}',
      name: name,
      category: category,
      price: price,
      costPrice: (price * 0.72).roundToDouble(),
      stock: stock,
      minStock: minStock,
      unit: unit,
      isActive: i != 27,
      supplier: i.isEven ? 'Distribuidora El Sol' : 'Mayorista Central',
      createdAt: _ago(days: 30 + i),
      updatedAt: _ago(days: i % 7),
    );

final previewProducts = <Product>[
  _p(1, 'Arroz Diana 500 g', 'Abarrotes', 2900, 48),
  _p(2, 'Aceite Premier 1 L', 'Abarrotes', 11500, 12),
  _p(3, 'Azúcar Manuelita 1 kg', 'Abarrotes', 4600, 3),
  _p(4, 'Café Sello Rojo 250 g', 'Abarrotes', 9800, 22),
  _p(5, 'Frijol bola roja 500 g', 'Abarrotes', 6200, 0),
  _p(6, 'Pasta Doria spaghetti 250 g', 'Abarrotes', 2400, 35),
  _p(7, 'Coca-Cola 1.5 L', 'Bebidas', 6500, 30),
  _p(8, 'Agua Cristal 600 ml', 'Bebidas', 1800, 64),
  _p(9, 'Jugo Hit mora 500 ml', 'Bebidas', 2800, 4),
  _p(10, 'Pony Malta 330 ml', 'Bebidas', 2200, 40),
  _p(11, 'Leche Alquería 1 L', 'Lácteos', 4300, 18),
  _p(12, 'Queso campesino 250 g', 'Lácteos', 7900, 6, minStock: 6),
  _p(13, 'Yogur Alpina fresa 200 g', 'Lácteos', 3100, 2),
  _p(14, 'Mantequilla Colanta 125 g', 'Lácteos', 5200, 9),
  _p(15, 'Salchichón cervecero 450 g', 'Carnes y Embutidos', 9900, 7),
  _p(16, 'Huevos AA x 12', 'Carnes y Embutidos', 12900, 15),
  _p(17, 'Pan tajado Bimbo', 'Panadería', 6900, 10),
  _p(18, 'Mogolla integral x 6', 'Panadería', 4500, 1),
  _p(19, 'Tomate chonto', 'Frutas y Verduras', 4200, 11, unit: 'kg'),
  _p(20, 'Banano criollo', 'Frutas y Verduras', 2600, 25, unit: 'kg'),
  _p(21, 'Papas Margarita pollo 40 g', 'Snacks y Dulces', 2300, 55),
  _p(22, 'Chocolatina Jet 12 g', 'Snacks y Dulces', 900, 120),
  _p(23, 'Galletas Festival 6 un', 'Snacks y Dulces', 3400, 28),
  _p(24, 'Detergente Ariel 1 kg', 'Limpieza', 14900, 8),
  _p(25, 'Jabón Rey x 3', 'Limpieza', 5600, 14),
  _p(26, 'Papel higiénico Familia x 4', 'Cuidado Personal', 8900, 20),
  _p(27, 'Crema dental Colgate 75 ml', 'Cuidado Personal', 6300, 13),
  _p(28, 'Cerveza Águila lata 330 ml', 'Licores', 3200, 96),
  _p(29, 'Aguardiente Antioqueño 375 ml', 'Licores', 29900, 5),
  _p(30, 'Dog Chow adulto 1 kg', 'Mascotas', 15900, 4),
  // Variantes para que el listado tenga más de una página.
  for (var i = 0; i < 48; i++)
    _p(
      31 + i,
      '${_variantBases[i % _variantBases.length].$1} ${_variantSizes[i ~/ _variantBases.length]}',
      _variantBases[i % _variantBases.length].$2,
      1500.0 + (i * 1370) % 24000,
      (i * 7) % 60,
    ),
];

const _variantBases = [
  ('Galletas Saltín', 'Snacks y Dulces'),
  ('Lenteja', 'Abarrotes'),
  ('Gaseosa Postobón', 'Bebidas'),
  ('Avena Alpina', 'Lácteos'),
  ('Atún Van Camps', 'Abarrotes'),
  ('Suavizante Suavitel', 'Limpieza'),
  ('Champú Sedal', 'Cuidado Personal'),
  ('Salchicha Zenú', 'Carnes y Embutidos'),
  ('Arepa de maíz', 'Panadería'),
  ('Papa criolla', 'Frutas y Verduras'),
  ('Ron Medellín', 'Licores'),
  ('Whiskas', 'Mascotas'),
];
const _variantSizes = ['pequeño', 'mediano', 'grande', 'familiar'];

List<T> _page<T>(List<T> list, int page, int pageSize) {
  final start = page * pageSize;
  if (start >= list.length) return <T>[];
  return list.sublist(start, (start + pageSize).clamp(0, list.length));
}

class PreviewProductRepository implements ProductRepository {
  @override
  Future<ProductListResult> getProducts({
    String? query,
    String? category,
    bool activeOnly = true,
    int page = 0,
    int pageSize = 20,
    ProductSort sortBy = ProductSort.name,
    bool ascending = true,
  }) async {
    final q = query?.toLowerCase();
    final list = previewProducts.where((p) {
      if (activeOnly && !p.isActive) return false;
      if (category != null && p.category != category) return false;
      if (q != null &&
          !p.name.toLowerCase().contains(q) &&
          !(p.barcode ?? '').contains(q)) {
        return false;
      }
      return true;
    }).toList();
    Comparable key(Product p) => switch (sortBy) {
          ProductSort.name => p.name,
          ProductSort.category => p.category,
          ProductSort.price => p.price,
          ProductSort.costPrice => p.costPrice,
          ProductSort.stock => p.stock,
        };
    list.sort((a, b) {
      final c = key(a).compareTo(key(b));
      return c != 0 ? (ascending ? c : -c) : a.name.compareTo(b.name);
    });
    return (products: _page(list, page, pageSize), failure: null);
  }

  @override
  Future<ProductResult> getProductById(String productId) async => (
        product: previewProducts.where((p) => p.id == productId).firstOrNull,
        failure: null,
      );

  @override
  Future<ProductResult> getProductByBarcode(String barcode) async => (
        product: previewProducts.where((p) => p.barcode == barcode).firstOrNull,
        failure: null,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ── Caja ──────────────────────────────────────────────────────

final previewOpenRegister = CashRegister(
  id: 'r-open',
  cashierId: 'u-caj-1',
  cashierName: 'Andrés Pérez',
  openingAmount: 150000,
  openingBreakdown: const {'bill_50000': 2, 'bill_10000': 4, 'bill_5000': 2},
  openingTime: _ago(hours: 5, minutes: 20),
  status: 'open',
  createdAt: _ago(hours: 5, minutes: 20),
  updatedAt: _ago(hours: 5, minutes: 20),
);

List<CashRegister> _registerHistory() {
  final list = <CashRegister>[previewOpenRegister];
  for (var d = 1; d <= 8; d++) {
    final cashier = _cashiers[d % 2];
    final sales = 380000.0 + d * 41500;
    final expenses = d.isEven ? 25000.0 : 0.0;
    final expected = 150000 + sales * 0.7 - expenses;
    final diff = d == 3 ? -8000.0 : (d == 6 ? 2000.0 : 0.0);
    list.add(CashRegister(
      id: 'r-$d',
      cashierId: cashier.id,
      cashierName: cashier.name,
      openingAmount: 150000,
      openingBreakdown: const {'bill_50000': 3},
      closingAmount: expected + diff,
      closingBreakdown: const {},
      closingSummary: ClosingSummary(
        openingAmount: 150000,
        salesEfectivo: sales * 0.6,
        salesMixtoEfectivo: sales * 0.1,
        salesTransferencia: sales * 0.3,
        salesTotal: sales,
        transactionCount: 40 + d * 3,
        totalExpenses: expenses,
        expectedCash: expected,
        countedCash: expected + diff,
        difference: diff,
      ),
      openingTime: _ago(days: d, hours: 10),
      closingTime: _ago(days: d, hours: 1),
      status: 'closed',
      createdAt: _ago(days: d, hours: 10),
      updatedAt: _ago(days: d, hours: 1),
    ));
  }
  return list;
}

class PreviewCashRegisterRepository implements CashRegisterRepository {
  PreviewCashRegisterRepository({required this.hasOpenRegister});
  final bool hasOpenRegister;

  @override
  Future<CashRegisterResult> getActiveRegister(String cashierId) async =>
      (register: hasOpenRegister ? previewOpenRegister : null, failure: null);

  @override
  Future<CashRegisterListResult> getRegisterHistory({
    String? cashierId,
    DateTime? from,
    DateTime? to,
    int page = 0,
    int pageSize = 20,
  }) async {
    final list = _registerHistory()
        .where((r) => cashierId == null || r.cashierId == cashierId)
        .toList();
    return (registers: _page(list, page, pageSize), failure: null);
  }

  @override
  Future<ClosingPreviewResult> getClosingPreview({
    required String registerId,
    required double openingAmount,
  }) async =>
      (
        preview: (
          salesTotal: 486300.0,
          expensesTotal: 32000.0,
          expectedCash: 412400.0,
          transactionCount: 37,
        ),
        failure: null,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ── Ventas y estadísticas ────────────────────────────────────

const _methods = ['efectivo', 'efectivo', 'transferencia', 'mixto', 'efectivo'];

final previewSales = List<Sale>.generate(70, (i) {
  final method = _methods[i % _methods.length];
  final total = 4800.0 + (i * 7300) % 68000;
  final cashier = _cashiers[i % 2];
  return Sale(
    id: 'a1f3c9e2-${1000 + i}-4b7d-9e11-${(i * 7919).toString().padLeft(12, '0')}',
    total: total,
    paymentMethod: method,
    cashAmount: method == 'transferencia' ? null : (method == 'mixto' ? total / 2 : 100000),
    transferAmount: method == 'efectivo' ? null : (method == 'mixto' ? total / 2 : total),
    changeAmount: method == 'efectivo' ? 100000 - total : null,
    cashierId: cashier.id,
    cashierName: cashier.name,
    cashRegisterId: 'r-open',
    status: i == 5 ? 'cancelled' : 'completed',
    itemsPreview: [
      previewProducts[i % 30].name,
      previewProducts[(i * 3 + 1) % 30].name,
      if (i.isOdd) previewProducts[(i * 5 + 2) % 30].name,
    ],
    createdAt: _ago(hours: i * 3, minutes: i * 7),
  );
});

class PreviewSaleRepository implements SaleRepository {
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
    SaleSort sortBy = SaleSort.date,
    bool ascending = false,
  }) async {
    final list = previewSales.where((s) {
      if (cashierId != null && s.cashierId != cashierId) return false;
      if (paymentMethod != null && s.paymentMethod != paymentMethod) return false;
      if (searchId != null && s.id != searchId) return false;
      if (minAmount != null && s.total < minAmount) return false;
      if (maxAmount != null && s.total > maxAmount) return false;
      return true;
    }).toList();
    Comparable key(Sale s) => switch (sortBy) {
          SaleSort.date => s.createdAt,
          SaleSort.total => s.total,
          SaleSort.paymentMethod => s.paymentMethod,
        };
    list.sort((a, b) {
      final c = key(a).compareTo(key(b));
      return c != 0 ? (ascending ? c : -c) : b.createdAt.compareTo(a.createdAt);
    });
    return (sales: _page(list, page, pageSize), failure: null);
  }

  @override
  Future<SaleDetailResult> getSaleDetail(String saleId) async {
    final sale = previewSales.where((s) => s.id == saleId).firstOrNull;
    final items = [
      for (var i = 0; i < 3; i++)
        SaleItem(
          id: 'si-$i',
          saleId: saleId,
          productId: previewProducts[i * 4].id,
          productName: previewProducts[i * 4].name,
          quantity: i + 1,
          unitPrice: previewProducts[i * 4].price,
          subtotal: previewProducts[i * 4].price * (i + 1),
          isProductArchived: i == 2,
        ),
    ];
    return (sale: sale, items: items, failure: null);
  }

  @override
  Future<SalesKpisResult> getSalesKpis() async => (
        kpis: (
          todayTotal: 486300.0,
          todayCount: 37,
          yesterdayTotal: 431800.0,
          weekTotal: 3125400.0,
          weekCount: 241,
          weekPrevTotal: 2870100.0,
          monthTotal: 12480900.0,
          monthCount: 962,
          monthPrevTotal: 13102000.0,
          avgTicket: 12974.0,
          paymentMethodCounts: const {'efectivo': 610, 'transferencia': 281, 'mixto': 71},
        ),
        failure: null,
      );

  @override
  Future<TopProductsResult> getTopProducts({
    required DateTime from,
    required DateTime to,
    String? category,
    int limit = 10,
  }) async {
    final list = [
      for (var i = 0; i < 10; i++)
        (
          productId: previewProducts[(i * 7) % 30].id,
          productName: previewProducts[(i * 7) % 30].name,
          unitsSold: 180 - i * 15,
          amountTotal: previewProducts[(i * 7) % 30].price * (180 - i * 15),
        ),
    ];
    return (products: list.take(limit).toList(), failure: null);
  }

  @override
  Future<SalesTrendResult> getSalesTrend({required DateTime from, required DateTime to}) async {
    final days = <DailySales>[];
    var d = DateTime(from.year, from.month, from.day);
    var i = 0;
    while (!d.isAfter(to)) {
      final total = 320000.0 + ((i * 97) % 11) * 38000 + (d.weekday >= 6 ? 180000 : 0);
      days.add((day: d, total: total, count: (total / 13000).round()));
      d = d.add(const Duration(days: 1));
      i++;
    }
    return (days: days, failure: null);
  }

  @override
  Future<CategoryBreakdownResult> getCategoryBreakdown({required DateTime from, required DateTime to}) async => (
        categories: [
          (category: 'Abarrotes', unitsSold: 820, amountTotal: 4380000.0, estimatedMargin: 1226000.0),
          (category: 'Bebidas', unitsSold: 1140, amountTotal: 3120000.0, estimatedMargin: 873000.0),
          (category: 'Lácteos', unitsSold: 460, amountTotal: 2010000.0, estimatedMargin: 562000.0),
          (category: 'Licores', unitsSold: 310, amountTotal: 1790000.0, estimatedMargin: 501000.0),
          (category: 'Snacks y Dulces', unitsSold: 990, amountTotal: 1240000.0, estimatedMargin: 347000.0),
          (category: 'Limpieza', unitsSold: 120, amountTotal: 980000.0, estimatedMargin: 274000.0),
        ],
        failure: null,
      );

  @override
  Future<CashierPerformanceResult> getCashierPerformance({required DateTime from, required DateTime to}) async => (
        cashiers: [
          (cashierId: 'u-caj-1', cashierName: 'Andrés Pérez', totalSales: 1840000.0, transactionCount: 142, avgTicket: 12958.0),
          (cashierId: 'u-caj-2', cashierName: 'Marcela Ruiz', totalSales: 1285400.0, transactionCount: 99, avgTicket: 12984.0),
        ],
        failure: null,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ── Gastos ────────────────────────────────────────────────────

const _expenseCategories = [
  ExpenseCategory(id: 'ec-1', name: 'Servicios', icon: 'bolt_outlined', isActive: true),
  ExpenseCategory(id: 'ec-2', name: 'Transporte', icon: 'local_shipping_outlined', isActive: true),
  ExpenseCategory(id: 'ec-3', name: 'Aseo', icon: 'cleaning_services_outlined', isActive: true),
  ExpenseCategory(id: 'ec-4', name: 'Alimentación', icon: 'restaurant_outlined', isActive: false),
];

final _expenses = [
  Expense(id: 'e-1', cashierId: 'u-caj-1', cashRegisterId: 'r-open', categoryId: 'ec-2', categoryName: 'Transporte', amount: 12000, description: 'Domicilio de pedido a proveedor', createdAt: _ago(hours: 3)),
  Expense(id: 'e-2', cashierId: 'u-caj-1', cashRegisterId: 'r-open', categoryId: 'ec-3', categoryName: 'Aseo', amount: 20000, description: 'Bolsas y trapeadores', createdAt: _ago(hours: 1)),
  Expense(id: 'e-3', cashierId: 'u-caj-2', cashRegisterId: 'r-2', categoryId: 'ec-1', categoryName: 'Servicios', amount: 85000, description: 'Recarga de internet del local', createdAt: _ago(days: 2)),
  Expense(id: 'e-4', cashierId: 'u-caj-2', cashRegisterId: 'r-4', categoryId: 'ec-2', categoryName: 'Transporte', amount: 15000, description: 'Taxi para traer mercancía', createdAt: _ago(days: 4)),
];

class PreviewExpenseRepository implements ExpenseRepository {
  @override
  Future<ExpenseListResult> getShiftExpenses(String cashRegisterId) async =>
      (expenses: _expenses.where((e) => e.cashRegisterId == cashRegisterId).toList(), failure: null);

  @override
  Future<ExpenseListResult> getExpensesReport({
    String? cashierId,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? categoryId,
  }) async =>
      (
        expenses: _expenses
            .where((e) => cashierId == null || e.cashierId == cashierId)
            .where((e) => categoryId == null || e.categoryId == categoryId)
            .toList(),
        failure: null,
      );

  @override
  Future<ExpenseCategoryListResult> getCategories({bool activeOnly = false}) async => (
        categories: _expenseCategories.where((c) => !activeOnly || c.isActive).toList(),
        failure: null,
      );

  @override
  Future<({double total, Failure? failure})> getSalesTotalForPeriod({
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async =>
      (total: 3125400.0, failure: null);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ── Inventario ────────────────────────────────────────────────

class PreviewInventoryRepository implements InventoryRepository {
  @override
  Future<StockMovementListResult> getStockMovements({
    required String productId,
    DateTime? from,
    DateTime? to,
  }) async =>
      (
        movements: [
          for (var i = 0; i < 8; i++)
            StockMovement(
              id: 'm-$i',
              productId: productId,
              movementType: i % 3 == 0 ? 'entrada' : 'salida',
              reason: i % 3 == 0 ? 'Compra a proveedor' : 'Venta',
              quantity: i % 3 == 0 ? 24 : 2,
              previousStock: 40 - i,
              newStock: i % 3 == 0 ? 64 - i : 38 - i,
              userName: i.isEven ? 'Laura Gómez' : 'Andrés Pérez',
              createdAt: _ago(days: i, hours: i * 2),
            ),
        ],
        failure: null,
      );

  @override
  Future<RestockRequestListResult> getOpenRestockRequests() async => (
        requests: [
          RestockRequest(id: 'rr-1', productId: 'p-3', requestedAt: _ago(hours: 4), requestedByName: 'Andrés Pérez', notes: 'Se acaba hoy', fulfilled: false),
          RestockRequest(id: 'rr-2', productId: 'p-5', requestedAt: _ago(days: 1), requestedByName: 'Marcela Ruiz', fulfilled: false),
          RestockRequest(id: 'rr-3', productId: 'p-18', requestedAt: _ago(days: 1, hours: 3), requestedByName: 'Andrés Pérez', fulfilled: false),
        ],
        failure: null,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ── Configuración, usuarios y sesión ─────────────────────────

class PreviewStoreSettingsRepository implements StoreSettingsRepository {
  @override
  Future<StoreSettingsResult> getSettings() async => (
        settings: const StoreSettings(
          maxExpenseAmount: 100000,
          weeklyReportEnabled: true,
          weeklyReportEmail: 'dueno@demo.local',
        ),
        failure: null,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class PreviewUserRepository implements UserRepository {
  @override
  Future<({List<Cashier>? cashiers, int? totalCount, Failure? failure})> getCashiers({
    bool? filterActive,
    int page = 0,
    int pageSize = 20,
  }) async {
    final list = _cashiers
        .where((c) => filterActive == null || c.isActive == filterActive)
        .toList();
    return (cashiers: _page(list, page, pageSize), totalCount: list.length, failure: null);
  }

  @override
  Future<({bool success, Failure? failure})> createCashier({
    required String name,
    required String email,
    required String password,
  }) async {
    // Solo vive en memoria: se pierde al recargar la página.
    _cashiers.insert(
      0,
      Cashier(id: 'u-caj-${_cashiers.length + 1}', email: email, name: name, isActive: true, createdAt: DateTime.now()),
    );
    return (success: true, failure: null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class PreviewAuthRepository implements AuthRepository {
  PreviewAuthRepository(this.user);
  final AppUser user;

  @override
  Stream<AppUser?> get authStateChanges => Stream.value(user);

  @override
  Future<AppUser?> getCurrentUser() async => user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
