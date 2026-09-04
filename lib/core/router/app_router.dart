import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/dashboard/presentation/pages/admin_dashboard_page.dart';
import '../../features/dashboard/presentation/pages/admin_cash_registers_page.dart';
import '../../features/cash_register/presentation/pages/cash_register_opening_page.dart';
import '../../features/pos/presentation/pages/pos_page.dart';
import '../../features/pos/presentation/pages/cart_page.dart';
import '../../features/products/presentation/pages/products_list_page.dart';
import '../../features/products/presentation/pages/product_form_page.dart';
import '../../features/products/presentation/pages/product_csv_import_page.dart';
import '../../features/products/presentation/pages/product_catalog_readonly_page.dart';
import '../../features/inventory/presentation/pages/inventory_dashboard_page.dart';
import '../../features/inventory/presentation/pages/stock_movement_history_page.dart';
import '../../features/inventory/presentation/pages/restock_list_page.dart';
import '../../features/users/presentation/pages/users_list_page.dart';
import '../../features/users/presentation/pages/create_cashier_page.dart';
import '../../features/users/presentation/pages/cashier_detail_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/expenses/presentation/pages/shift_expenses_page.dart';
import '../../features/expenses/presentation/pages/expense_categories_admin_page.dart';
import '../../features/expenses/presentation/pages/expenses_report_admin_page.dart';
import '../../features/dashboard/presentation/pages/sales_history_page.dart';
import '../../features/dashboard/presentation/pages/sale_detail_page.dart';
import '../../features/dashboard/presentation/pages/sales_statistics_page.dart';

// ── Rutas nombradas ─────────────────────────────────────────
abstract class AppRoutes {
  static const login                = '/login';
  static const adminDashboard       = '/admin';
  static const cashRegisterOpening  = '/cash-register/opening';
  static const cashRegistersHistory = '/admin/cash-registers';   // US-011
  static const pos                  = '/pos';
  static const cart                 = '/pos/cart';               // US-027/US-028
  static const catalog              = '/catalog';               // US-018
  static const products             = '/admin/products';
  static const inventory            = '/admin/inventory';       // US-020
  static const inventoryRestock     = '/admin/inventory/restock'; // US-024
  static const users                = '/admin/users';
  static const createCashier        = '/admin/users/create';
  static const cashierDetail        = '/admin/users/:id';
  static const settings             = '/settings';
  static const reports              = '/admin/reports';
  static const analytics            = '/admin/analytics';
  static const posExpenses          = '/pos/expenses';           // US-035
  static const expensesReport       = '/admin/expenses';         // US-037
  static const expenseCategories    = '/admin/expenses/categories'; // US-036
  static const salesHistory         = '/admin/sales-history';    // US-044
  static const saleDetail           = '/admin/sales-history/:id'; // US-047
}


// ── Provider del router ─────────────────────────────────────
final appRouterProvider = Provider<GoRouter>((ref) {
  final authStream = ref.watch(authStateStreamProvider);

  return GoRouter(
    initialLocation: AppRoutes.login,
    redirect: (context, state) {
      // Si el stream aún está cargando, no redirigir todavía
      if (authStream.isLoading) return null;

      final user = authStream.valueOrNull;
      final isLoggedIn = user != null;
      final isLoginPage = state.matchedLocation == AppRoutes.login;

      if (!isLoggedIn && !isLoginPage) return AppRoutes.login;
      if (isLoggedIn && isLoginPage) {
        // Leer el rol directamente del usuario ya cargado (evita race condition)
        final role = user.role;
        return role == 'adminmaster'
            ? AppRoutes.adminDashboard
            : AppRoutes.cashRegisterOpening;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (_, _) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.adminDashboard,
        name: 'admin-dashboard',
        builder: (_, _) => const AdminDashboardPage(),
      ),
      GoRoute(
        path: AppRoutes.cashRegisterOpening,
        name: 'cash-register-opening',
        builder: (_, _) => const CashRegisterOpeningPage(),
      ),
      // US-011: Historial de aperturas (solo AdminMaster)
      GoRoute(
        path: AppRoutes.cashRegistersHistory,
        name: 'cash-registers-history',
        builder: (_, _) => const AdminCashRegistersPage(),
      ),
      GoRoute(
        path: AppRoutes.pos,
        name: 'pos',
        builder: (_, _) => const PosPage(),
      ),
      // US-027/US-028: Carrito de venta
      GoRoute(
        path: AppRoutes.cart,
        name: 'pos-cart',
        builder: (_, _) => const CartPage(),
      ),
      GoRoute(
        path: AppRoutes.users,
        name: 'users',
        builder: (_, _) => const UsersListPage(),
      ),
      GoRoute(
        path: AppRoutes.createCashier,
        name: 'create-cashier',
        builder: (_, _) => const CreateCashierPage(),
      ),
      GoRoute(
        path: AppRoutes.cashierDetail,
        name: 'cashier-detail',
        builder: (_, state) => CashierDetailPage(cashierId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.settings,
        name: 'settings',
        builder: (_, _) => const SettingsPage(),
      ),
      // EP-03: CRUD de Productos
      GoRoute(
        path: AppRoutes.products,
        name: 'products',
        builder: (_, _) => const ProductsListPage(),
      ),
      GoRoute(
        path: '/admin/products/new',
        name: 'product-new',
        builder: (_, _) => const ProductFormPage(),
      ),
      GoRoute(
        path: '/admin/products/edit/:id',
        name: 'product-edit',
        builder: (_, state) => ProductFormPage(
          productId: state.pathParameters['id'],
        ),
      ),
      // US-019: Import masivo de productos vía CSV
      GoRoute(
        path: '/admin/products/import',
        name: 'product-import',
        builder: (_, _) => const ProductCsvImportPage(),
      ),
      // US-018: Catálogo de solo lectura para Cajero
      GoRoute(
        path: AppRoutes.catalog,
        name: 'catalog',
        builder: (_, _) => const ProductCatalogReadonlyPage(),
      ),
      // EP-04: Inventario y Stock
      GoRoute(
        path: AppRoutes.inventory,
        name: 'inventory',
        builder: (_, _) => const InventoryDashboardPage(),
      ),
      GoRoute(
        path: '/admin/inventory/:productId/movements',
        name: 'inventory-movements',
        builder: (_, state) => StockMovementHistoryPage(
          productId: state.pathParameters['productId']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.inventoryRestock,
        name: 'inventory-restock',
        builder: (_, _) => const RestockListPage(),
      ),
      // EP-06: Gastos de Caja
      GoRoute(
        path: AppRoutes.posExpenses,
        name: 'pos-expenses',
        builder: (_, _) => const ShiftExpensesPage(),
      ),
      GoRoute(
        path: AppRoutes.expensesReport,
        name: 'expenses-report',
        builder: (_, _) => const ExpensesReportAdminPage(),
      ),
      GoRoute(
        path: AppRoutes.expenseCategories,
        name: 'expense-categories',
        builder: (_, _) => const ExpenseCategoriesAdminPage(),
      ),
      // EP-08: Historial de Ventas y Reportes
      GoRoute(
        path: AppRoutes.salesHistory,
        name: 'sales-history',
        builder: (_, _) => const SalesHistoryPage(),
      ),
      GoRoute(
        path: AppRoutes.saleDetail,
        name: 'sale-detail',
        builder: (_, state) => SaleDetailPage(saleId: state.pathParameters['id']!),
      ),
      // EP-09 (S-10): Estadísticas y tendencias de ventas
      GoRoute(
        path: AppRoutes.analytics,
        name: 'sales-statistics',
        builder: (_, _) => const SalesStatisticsPage(),
      ),
    ],


    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Ruta no encontrada: ${state.error}')),
    ),
  );
});
