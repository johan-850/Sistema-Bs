// ── Rutas nombradas ─────────────────────────────────────────
abstract class AppRoutes {
  static const login                = '/login';
  static const adminDashboard       = '/admin';
  static const cashRegisterOpening  = '/cash-register/opening';
  static const cashRegisterClosing  = '/cash-register/closing';
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
