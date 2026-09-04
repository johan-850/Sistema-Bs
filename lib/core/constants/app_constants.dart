/// Constantes globales de la aplicación Sistema Bs
abstract class AppConstants {
  // ── Roles ────────────────────────────────────────────────
  static const String roleAdmin   = 'adminmaster';
  static const String roleCajero  = 'cajero';

  // ── Paginación ───────────────────────────────────────────
  static const int pageSize = 20;

  // ── Tablas Supabase — EP-01 ───────────────────────────────
  static const String tableProfiles          = 'profiles';
  static const String tableUserActivityLogs  = 'user_activity_logs';

  // ── Tablas Supabase — EP-02 ───────────────────────────────
  static const String tableCashRegisters     = 'cash_registers';
  static const String tableCashMovements     = 'cash_movements';

  // ── Tablas Supabase — EP-03 ───────────────────────────────
  static const String tableProducts          = 'products';
  static const String tableStockMovements    = 'stock_movements';

  // ── Storage buckets — EP-03 ───────────────────────────────
  static const String storageBucketProductImages = 'product-images';

  // ── Tablas / RPC Supabase — EP-04 ─────────────────────────
  static const String tableRestockRequests = 'restock_requests';
  static const String rpcAdjustStock       = 'adjust_product_stock';

  /// Dirección del movimiento de stock (US-021)
  static const List<String> stockMovementTypes = ['entrada', 'salida'];

  /// Motivos disponibles en el formulario de ajuste manual.
  /// 'venta' no está aquí: queda reservado para cuando EP-05 (POS)
  /// registre movimientos automáticos.
  static const List<String> stockAdjustmentReasons = [
    'recepcion',
    'merma',
    'devolucion',
    'ajuste',
  ];

  // ── Tablas / RPC Supabase — EP-05 ─────────────────────────
  static const String tableSales             = 'sales';
  static const String tableSaleItems         = 'sale_items';
  static const String rpcConfirmSale         = 'confirm_sale';
  static const String tableSaleCancellations = 'sale_cancellations';
  static const String tableLowStockAlerts    = 'low_stock_alerts';

  /// Métodos de pago disponibles en el cobro (US-030)
  static const List<String> paymentMethods = ['efectivo', 'transferencia', 'mixto'];

  // ── QR de pago y comprobante de transferencia ──────────────
  static const String tableStoreSettings           = 'store_settings';
  static const String storageBucketStoreAssets     = 'store-assets';
  static const String storageBucketReceiptPhotos   = 'receipt-photos';

  // ── Tablas Supabase — EP-06 (Gastos de Caja) ──────────────
  static const String tableExpenses          = 'expenses';
  static const String tableExpenseCategories = 'expense_categories';

  // ── Edge Functions ────────────────────────────────────────
  static const String fnCreateCashier        = 'create-cashier';
  static const String fnToggleCashierStatus  = 'toggle-cashier-status';
  static const String fnSendWeeklyReport     = 'send-weekly-report';

  // ── Validación ────────────────────────────────────────────
  static const int minPasswordLength = 6;
  static const int maxNameLength     = 80;
  static const int maxNotesLength    = 300;
  static const int maxProductNameLength  = 120;
  static const int maxDescriptionLength  = 500;

  // ── Import CSV de productos — US-019 ──────────────────────
  static const int maxCsvImportRows = 500;
  static const List<String> csvImportHeaders = [
    'barcode',
    'name',
    'description',
    'category',
    'price',
    'cost_price',
    'stock',
    'min_stock',
    'unit',
    'supplier',
  ];

  // ── Timeouts ──────────────────────────────────────────────
  static const Duration requestTimeout = Duration(seconds: 15);

  // ── Categorías de productos predeterminadas ────────────────
  /// Lista de categorías comunes para abarroterías colombianas.
  /// El usuario también puede escribir una categoría personalizada.
  static const List<String> productCategories = [
    'General',
    'Abarrotes',
    'Bebidas',
    'Lácteos',
    'Carnes y Embutidos',
    'Panadería',
    'Frutas y Verduras',
    'Snacks y Dulces',
    'Limpieza',
    'Cuidado Personal',
    'Licores',
    'Mascotas',
    'Otros',
  ];

  // ── Unidades de medida ─────────────────────────────────────
  static const List<String> productUnits = [
    'unidad',
    'kg',
    'g',
    'lt',
    'ml',
    'paquete',
    'caja',
    'docena',
  ];

  // ── Denominaciones COP ────────────────────────────────────

  /// Monedas (llave → valor en pesos)
  static const Map<String, int> coinDenominations = {
    'coin_50':   50,
    'coin_100':  100,
    'coin_200':  200,
    'coin_500':  500,
    'coin_1000': 1000,
  };

  /// Billetes (llave → valor en pesos)
  static const Map<String, int> billDenominations = {
    'bill_1000':   1000,
    'bill_2000':   2000,
    'bill_5000':   5000,
    'bill_10000':  10000,
    'bill_20000':  20000,
    'bill_50000':  50000,
    'bill_100000': 100000,
  };
}

