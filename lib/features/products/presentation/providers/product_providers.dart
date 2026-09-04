// ============================================================
// lib/features/products/presentation/providers/product_providers.dart
// Providers de Riverpod para la Épica 3 — CRUD de Productos
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/datasources/product_remote_datasource.dart';
import '../../data/repositories/product_repository_impl.dart';
import '../../domain/entities/product.dart';
import '../../domain/repositories/product_repository.dart';
import '../../domain/use_cases/product_use_cases.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/failures.dart';

// ── DI (Inyección de dependencias) ────────────────────────────

final productDatasourceProvider = Provider(
  (ref) => ProductRemoteDatasource(ref.read(supabaseClientProvider)),
);

final productRepositoryProvider = Provider<ProductRepository>(
  (ref) => ProductRepositoryImpl(ref.read(productDatasourceProvider)),
);

// ── Use cases ─────────────────────────────────────────────────

final getProductsUseCaseProvider = Provider(
  (ref) => GetProductsUseCase(ref.read(productRepositoryProvider)),
);

final getProductByBarcodeUseCaseProvider = Provider(
  (ref) => GetProductByBarcodeUseCase(ref.read(productRepositoryProvider)),
);

final createProductUseCaseProvider = Provider(
  (ref) => CreateProductUseCase(ref.read(productRepositoryProvider)),
);

final updateProductUseCaseProvider = Provider(
  (ref) => UpdateProductUseCase(ref.read(productRepositoryProvider)),
);

final toggleProductStatusUseCaseProvider = Provider(
  (ref) => ToggleProductStatusUseCase(ref.read(productRepositoryProvider)),
);

final uploadProductImageUseCaseProvider = Provider(
  (ref) => UploadProductImageUseCase(ref.read(productRepositoryProvider)),
);

final deleteProductImageUseCaseProvider = Provider(
  (ref) => DeleteProductImageUseCase(ref.read(productRepositoryProvider)),
);

// ── US-017: Filtro por alerta de stock ─────────────────────────

/// Nivel de alerta de stock para filtrar el listado (US-017).
enum StockAlertFilter { all, low, outOfStock }

// ── US-014: Estado del listado de productos ───────────────────

/// Estado que maneja la lista de productos, búsqueda y paginación.
class ProductListState {
  final List<Product> products;
  final bool isLoading;
  final int currentPage;
  final Failure? failure;

  // Filtros activos
  final String? searchQuery;
  final String? filterCategory;
  final bool showInactive;
  final StockAlertFilter filterStockAlert;

  const ProductListState({
    this.products = const [],
    this.isLoading = false,
    this.currentPage = 0,
    this.failure,
    this.searchQuery,
    this.filterCategory,
    this.showInactive = false,
    this.filterStockAlert = StockAlertFilter.all,
  });

  /// True cuando hay filtros o búsqueda activa
  bool get hasActiveFilters =>
      (searchQuery != null && searchQuery!.isNotEmpty) ||
      filterCategory != null ||
      showInactive ||
      filterStockAlert != StockAlertFilter.all;

  ProductListState copyWith({
    List<Product>? products,
    bool? isLoading,
    int? currentPage,
    Failure? failure,
    String? searchQuery,
    String? filterCategory,
    bool? showInactive,
    StockAlertFilter? filterStockAlert,
    bool clearFailure = false,
    bool clearFilters = false,
  }) =>
      ProductListState(
        products: products ?? this.products,
        isLoading: isLoading ?? this.isLoading,
        currentPage: currentPage ?? this.currentPage,
        failure: clearFailure ? null : (failure ?? this.failure),
        searchQuery:
            clearFilters ? null : (searchQuery ?? this.searchQuery),
        filterCategory:
            clearFilters ? null : (filterCategory ?? this.filterCategory),
        showInactive:
            clearFilters ? false : (showInactive ?? this.showInactive),
        filterStockAlert: clearFilters
            ? StockAlertFilter.all
            : (filterStockAlert ?? this.filterStockAlert),
      );
}

class ProductListNotifier extends StateNotifier<ProductListState> {
  final GetProductsUseCase _getProducts;
  StreamSubscription<List<Map<String, dynamic>>>? _realtimeSub;

  ProductListNotifier(this._getProducts, SupabaseClient client) : super(const ProductListState()) {
    load();
    // Refresco en tiempo real cuando cambia la tabla products (ej. un
    // ajuste de stock o una edición hecha desde otra sesión) — mismo
    // criterio que InventoryListNotifier (EP-04) y PosCatalogNotifier.
    _realtimeSub = client.from('products').stream(primaryKey: ['id']).listen((_) {
      load();
    });
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    super.dispose();
  }

  /// Carga (o recarga) la lista con los filtros actuales.
  ///
  /// El filtro de alerta de stock se aplica client-side sobre lo ya
  /// traído: Supabase/PostgREST no compara columnas entre sí
  /// (stock vs min_stock) en una query simple. A la escala de una
  /// tienda pequeña esto es aceptable.
  Future<void> load({int page = 0}) async {
    state = state.copyWith(isLoading: true, currentPage: page, clearFailure: true);

    final result = await _getProducts(
      query: state.searchQuery,
      category: state.filterCategory,
      activeOnly: !state.showInactive,
      page: page,
    );

    if (result.failure != null) {
      state = state.copyWith(isLoading: false, failure: result.failure);
    } else {
      final filtered = switch (state.filterStockAlert) {
        StockAlertFilter.all => result.products,
        StockAlertFilter.low => result.products.where((p) => p.isLowStock && !p.isOutOfStock).toList(),
        StockAlertFilter.outOfStock => result.products.where((p) => p.isOutOfStock).toList(),
      };
      state = state.copyWith(isLoading: false, products: filtered);
    }
  }

  /// Buscar por texto (nombre o código de barras)
  Future<void> search(String query) async {
    state = state.copyWith(searchQuery: query.isEmpty ? null : query);
    await load();
  }

  /// Filtrar por categoría
  Future<void> filterByCategory(String? category) async {
    state = state.copyWith(filterCategory: category);
    await load();
  }

  /// Mostrar/ocultar productos inactivos
  Future<void> toggleShowInactive() async {
    state = state.copyWith(showInactive: !state.showInactive);
    await load();
  }

  /// US-017: Filtrar por alerta de stock (todos / bajo mínimo / agotado)
  Future<void> filterByStockAlert(StockAlertFilter filter) async {
    state = state.copyWith(filterStockAlert: filter);
    await load();
  }

  /// Limpiar todos los filtros
  Future<void> clearFilters() async {
    state = state.copyWith(clearFilters: true);
    await load();
  }

  /// Recargar después de crear/editar un producto
  Future<void> refresh() => load(page: state.currentPage);
}

final productListProvider =
    StateNotifierProvider<ProductListNotifier, ProductListState>(
  (ref) => ProductListNotifier(ref.read(getProductsUseCaseProvider), ref.read(supabaseClientProvider)),
);

// ── US-013 / US-015: Estado del formulario de producto ────────

/// Estado del formulario de creación/edición de producto.
class ProductFormState {
  final bool isLoading;
  final bool success;
  final Failure? failure;
  final Product? savedProduct;

  const ProductFormState({
    this.isLoading = false,
    this.success = false,
    this.failure,
    this.savedProduct,
  });

  ProductFormState copyWith({
    bool? isLoading,
    bool? success,
    Failure? failure,
    Product? savedProduct,
    bool clearFailure = false,
  }) =>
      ProductFormState(
        isLoading: isLoading ?? this.isLoading,
        success: success ?? this.success,
        failure: clearFailure ? null : (failure ?? this.failure),
        savedProduct: savedProduct ?? this.savedProduct,
      );
}

class ProductFormNotifier extends StateNotifier<ProductFormState> {
  final CreateProductUseCase _createUseCase;
  final UpdateProductUseCase _updateUseCase;

  ProductFormNotifier(this._createUseCase, this._updateUseCase)
      : super(const ProductFormState());

  /// US-013: Crear un nuevo producto
  Future<bool> create({
    String? barcode,
    required String name,
    String? description,
    required String category,
    required double price,
    required double costPrice,
    required int stock,
    required int minStock,
    required String unit,
    String? imageUrl,
    String? supplier,
  }) async {
    state = state.copyWith(isLoading: true, clearFailure: true);

    final result = await _createUseCase(
      barcode: barcode,
      name: name,
      description: description,
      category: category,
      price: price,
      costPrice: costPrice,
      stock: stock,
      minStock: minStock,
      unit: unit,
      imageUrl: imageUrl,
      supplier: supplier,
    );

    if (result.failure != null) {
      state = state.copyWith(isLoading: false, failure: result.failure);
      return false;
    }

    state = state.copyWith(
      isLoading: false,
      success: true,
      savedProduct: result.product,
    );
    return true;
  }

  /// US-015: Actualizar un producto existente
  Future<bool> update({
    required String productId,
    String? barcode,
    String? name,
    String? description,
    String? category,
    double? price,
    double? costPrice,
    int? stock,
    int? minStock,
    String? unit,
    bool? isActive,
    String? imageUrl,
    String? supplier,
  }) async {
    state = state.copyWith(isLoading: true, clearFailure: true);

    final result = await _updateUseCase(
      productId: productId,
      barcode: barcode,
      name: name,
      description: description,
      category: category,
      price: price,
      costPrice: costPrice,
      stock: stock,
      minStock: minStock,
      unit: unit,
      isActive: isActive,
      imageUrl: imageUrl,
      supplier: supplier,
    );

    if (result.failure != null) {
      state = state.copyWith(isLoading: false, failure: result.failure);
      return false;
    }

    state = state.copyWith(
      isLoading: false,
      success: true,
      savedProduct: result.product,
    );
    return true;
  }

  /// Resetear estado del formulario
  void reset() => state = const ProductFormState();
}

final productFormProvider =
    StateNotifierProvider.autoDispose<ProductFormNotifier, ProductFormState>(
  (ref) => ProductFormNotifier(
    ref.read(createProductUseCaseProvider),
    ref.read(updateProductUseCaseProvider),
  ),
);

// ── US-019: Importación masiva de productos vía CSV ───────────

/// Una fila del CSV ya parseada y validada.
/// [error] es null cuando la fila es válida y lista para importar.
class ProductCsvRow {
  final int rowNumber; // Número de fila en el archivo (2 = primera fila de datos)
  final String? barcode;
  final String name;
  final String? description;
  final String category;
  final double price;
  final double costPrice;
  final int stock;
  final int minStock;
  final String unit;
  final String? supplier;
  final String? error;

  const ProductCsvRow({
    required this.rowNumber,
    this.barcode,
    required this.name,
    this.description,
    required this.category,
    required this.price,
    required this.costPrice,
    required this.stock,
    required this.minStock,
    required this.unit,
    this.supplier,
    this.error,
  });

  bool get isValid => error == null;

  ProductCsvRow withError(String newError) => ProductCsvRow(
        rowNumber: rowNumber,
        barcode: barcode,
        name: name,
        description: description,
        category: category,
        price: price,
        costPrice: costPrice,
        stock: stock,
        minStock: minStock,
        unit: unit,
        supplier: supplier,
        error: newError,
      );
}

class ProductCsvImportState {
  final List<ProductCsvRow> rows;
  final bool isParsing;
  final bool isImporting;
  final int? importedCount;
  final int? failedCount;
  final Failure? failure;

  const ProductCsvImportState({
    this.rows = const [],
    this.isParsing = false,
    this.isImporting = false,
    this.importedCount,
    this.failedCount,
    this.failure,
  });

  int get validCount => rows.where((r) => r.isValid).length;
  int get invalidCount => rows.length - validCount;
  bool get hasImportResult => importedCount != null;

  ProductCsvImportState copyWith({
    List<ProductCsvRow>? rows,
    bool? isParsing,
    bool? isImporting,
    int? importedCount,
    int? failedCount,
    Failure? failure,
    bool clearFailure = false,
  }) =>
      ProductCsvImportState(
        rows: rows ?? this.rows,
        isParsing: isParsing ?? this.isParsing,
        isImporting: isImporting ?? this.isImporting,
        importedCount: importedCount ?? this.importedCount,
        failedCount: failedCount ?? this.failedCount,
        failure: clearFailure ? null : (failure ?? this.failure),
      );
}

class ProductCsvImportNotifier extends StateNotifier<ProductCsvImportState> {
  final CreateProductUseCase _createUseCase;

  ProductCsvImportNotifier(this._createUseCase)
      : super(const ProductCsvImportState());

  /// Genera el CSV de plantilla (header + fila de ejemplo) para descargar.
  String buildTemplateCsv() {
    final rows = [
      AppConstants.csvImportHeaders,
      [
        '7701234567890',
        'Arroz Diana 500g',
        'Arroz blanco premium',
        'Abarrotes',
        '3500',
        '2800',
        '50',
        '10',
        'unidad',
        'Distribuidora XYZ',
      ],
    ];
    return const ListToCsvConverter().convert(rows);
  }

  /// Abre el selector de archivos, parsea el CSV elegido y valida cada fila.
  Future<void> pickAndParseFile() async {
    state = state.copyWith(
      isParsing: true,
      clearFailure: true,
      rows: [],
      importedCount: null,
      failedCount: null,
    );

    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) {
        state = state.copyWith(isParsing: false);
        return;
      }

      final bytes = picked.files.single.bytes;
      if (bytes == null) {
        state = state.copyWith(
          isParsing: false,
          failure: const UnexpectedFailure('No se pudo leer el archivo seleccionado.'),
        );
        return;
      }

      final content = utf8.decode(bytes, allowMalformed: true);
      final table = const CsvToListConverter(eol: '\n').convert(content);
      if (table.isEmpty) {
        state = state.copyWith(
          isParsing: false,
          failure: const ValidationFailure('El archivo CSV está vacío.'),
        );
        return;
      }

      final header = table.first.map((h) => h.toString().trim().toLowerCase()).toList();
      final missing = AppConstants.csvImportHeaders.where((h) => !header.contains(h)).toList();
      if (missing.isNotEmpty) {
        state = state.copyWith(
          isParsing: false,
          failure: ValidationFailure('Faltan columnas en el CSV: ${missing.join(', ')}'),
        );
        return;
      }
      final colIndex = {for (final h in AppConstants.csvImportHeaders) h: header.indexOf(h)};

      final dataRows = table.skip(1).toList();
      final truncated = dataRows.length > AppConstants.maxCsvImportRows;
      final limitedRows = dataRows.take(AppConstants.maxCsvImportRows).toList();

      final parsed = <ProductCsvRow>[
        for (var i = 0; i < limitedRows.length; i++)
          _parseRow(rowNumber: i + 2, row: limitedRows[i], colIndex: colIndex),
      ];

      state = state.copyWith(
        isParsing: false,
        rows: parsed,
        failure: truncated
            ? ValidationFailure(
                'El archivo tiene más de ${AppConstants.maxCsvImportRows} filas; '
                'solo se cargaron las primeras ${AppConstants.maxCsvImportRows}.')
            : null,
      );
    } catch (e) {
      state = state.copyWith(
        isParsing: false,
        failure: UnexpectedFailure('Error al leer el CSV: $e'),
      );
    }
  }

  ProductCsvRow _parseRow({
    required int rowNumber,
    required List<dynamic> row,
    required Map<String, int> colIndex,
  }) {
    String cell(String col) {
      final i = colIndex[col]!;
      return i < row.length ? row[i].toString().trim() : '';
    }

    final name = cell('name');
    final category = cell('category');
    final unit = cell('unit');
    final barcode = cell('barcode');
    final description = cell('description');
    final supplier = cell('supplier');

    final price = double.tryParse(cell('price'));
    final costRaw = cell('cost_price');
    final cost = double.tryParse(costRaw.isEmpty ? '0' : costRaw);
    final stock = int.tryParse(cell('stock'));
    final minStockRaw = cell('min_stock');
    final minStock = int.tryParse(minStockRaw.isEmpty ? '5' : minStockRaw);

    String? error;
    if (name.isEmpty) {
      error = 'Nombre vacío';
    } else if (category.isEmpty) {
      error = 'Categoría vacía';
    } else if (unit.isEmpty) {
      error = 'Unidad vacía';
    } else if (price == null || price <= 0) {
      error = 'Precio inválido';
    } else if (cost == null || cost < 0) {
      error = 'Costo inválido';
    } else if (cost > price) {
      error = 'Costo mayor que el precio';
    } else if (stock == null || stock < 0) {
      error = 'Stock inválido';
    } else if (minStock == null || minStock < 0) {
      error = 'Stock mínimo inválido';
    }

    return ProductCsvRow(
      rowNumber: rowNumber,
      barcode: barcode.isEmpty ? null : barcode,
      name: name,
      description: description.isEmpty ? null : description,
      category: category,
      price: price ?? 0,
      costPrice: cost ?? 0,
      stock: stock ?? 0,
      minStock: minStock ?? 5,
      unit: unit,
      supplier: supplier.isEmpty ? null : supplier,
      error: error,
    );
  }

  /// Importa las filas válidas una por una, reutilizando CreateProductUseCase
  /// (que ya valida duplicados de código de barras y reglas de negocio).
  Future<void> confirmImport() async {
    final updatedRows = [...state.rows];
    var imported = 0;
    var failed = 0;

    state = state.copyWith(isImporting: true);

    for (var i = 0; i < updatedRows.length; i++) {
      final row = updatedRows[i];
      if (!row.isValid) {
        failed++;
        continue;
      }

      final result = await _createUseCase(
        barcode: row.barcode,
        name: row.name,
        description: row.description,
        category: row.category,
        price: row.price,
        costPrice: row.costPrice,
        stock: row.stock,
        minStock: row.minStock,
        unit: row.unit,
        supplier: row.supplier,
      );

      if (result.failure != null) {
        failed++;
        updatedRows[i] = row.withError(result.failure!.message);
      } else {
        imported++;
      }
    }

    state = state.copyWith(
      isImporting: false,
      rows: updatedRows,
      importedCount: imported,
      failedCount: failed,
    );
  }

  void reset() => state = const ProductCsvImportState();
}

final productCsvImportProvider = StateNotifierProvider.autoDispose<
    ProductCsvImportNotifier, ProductCsvImportState>(
  (ref) => ProductCsvImportNotifier(ref.read(createProductUseCaseProvider)),
);
