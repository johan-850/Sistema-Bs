// ============================================================
// lib/features/products/presentation/pages/products_list_page.dart
// US-014: Listado de productos con búsqueda y filtros
// US-016: Desactivar/reactivar productos
// Diseño: Glassmorphism / Neumorphism dark
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/breakpoints.dart';
import '../../../../core/widgets/adaptive_sheet.dart';
import '../../../../core/widgets/app_page_bar.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/data_table_view.dart';
import '../../../../core/widgets/filter_dropdown.dart';
import '../../../../core/widgets/hover_ink_well.dart';
import '../../../../core/widgets/product_list_card.dart';
import '../../../../core/widgets/product_thumbnail.dart';
import '../../domain/entities/product.dart';
import '../../domain/repositories/product_repository.dart' show ProductSort;
import '../providers/product_providers.dart';

class ProductsListPage extends ConsumerStatefulWidget {
  const ProductsListPage({super.key});

  @override
  ConsumerState<ProductsListPage> createState() => _ProductsListPageState();
}

class _ProductsListPageState extends ConsumerState<ProductsListPage> {
  final _searchController = TextEditingController();
  final _currencyFmt = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0,
  );

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productListProvider);
    final notifier = ref.read(productListProvider.notifier);

    // Escuchar errores
    ref.listen<ProductListState>(productListProvider, (_, next) {
      if (next.failure != null) {
        AppSnackbar.error(context, next.failure!.message);
      }
    });

    final compact = context.isCompact;
    void clearFilters() {
      _searchController.clear();
      notifier.clearFilters();
    }

    void openProduct(Product p) => context.go('/admin/products/edit/${p.id}');

    final search = _SearchBar(
      controller: _searchController,
      onChanged: (q) => notifier.search(q),
      onClear: () {
        _searchController.clear();
        notifier.search('');
      },
    );
    final empty = _EmptyState(
      hasFilters: state.hasActiveFilters,
      onClearFilters: clearFilters,
    );
    final pager = TablePager(
      page: state.currentPage,
      hasNext: state.hasNextPage,
      onPrevious: notifier.previousPage,
      onNext: notifier.nextPage,
    );

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppPageBar(
        title: 'Productos',
        actions: [
          // En escritorio los filtros están a la vista sobre la tabla.
          if (compact) ...[
            // Filtros de categoría + alerta de stock — US-017
            PageAction(
              icon: Icons.filter_list_rounded,
              label: 'Filtrar',
              highlighted: state.filterCategory != null ||
                  state.filterStockAlert != StockAlertFilter.all,
              onPressed: () => _showFilterSheet(context, notifier, state),
            ),
            PageAction(
              icon: state.showInactive
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              label: state.showInactive ? 'Ocultar inactivos' : 'Mostrar inactivos',
              highlighted: state.showInactive,
              onPressed: () => notifier.toggleShowInactive(),
            ),
          ],
          // US-019: Importar productos desde CSV
          PageAction(
            icon: Icons.upload_file_rounded,
            label: 'Importar CSV',
            onPressed: () => context.push('/admin/products/import'),
          ),
          if (!compact)
            PageAction(
              icon: Icons.add_rounded,
              label: 'Nuevo producto',
              primary: true,
              onPressed: () => context.go('/admin/products/new'),
            ),
        ],
      ),
      body: compact
          ? Column(
              children: [
                // ── Barra de búsqueda ──────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: search,
                ),

                // ── Indicador de filtros activos ─────────────────────
                if (state.hasActiveFilters)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _ActiveFiltersChip(
                      category: state.filterCategory,
                      showInactive: state.showInactive,
                      stockAlert: state.filterStockAlert,
                      onClear: clearFilters,
                    ),
                  ),

                // ── Lista de productos ──────────────────────────────
                Expanded(
                  child: state.isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: AppColors.primary),
                        )
                      : state.products.isEmpty
                      ? empty
                      : RefreshIndicator(
                          color: AppColors.primary,
                          onRefresh: () => notifier.refresh(),
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                            itemCount: state.products.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (context, i) => ProductListCard(
                              product: state.products[i],
                              currencyFmt: _currencyFmt,
                              showInactiveBadge: true,
                              onTap: () => openProduct(state.products[i]),
                            ),
                          ),
                        ),
                ),
                if (state.currentPage > 0 || state.hasNextPage) pager,
              ],
            )
          // ── USB-018: tabla de escritorio ───────────────────────
          : Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: search),
                      const SizedBox(width: 12),
                      FilterDropdown<String?>(
                        label: 'Categoría',
                        value: state.filterCategory,
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Todas las categorías')),
                          for (final c in AppConstants.productCategories)
                            DropdownMenuItem(value: c, child: Text(c)),
                        ],
                        onChanged: notifier.filterByCategory,
                      ),
                      const SizedBox(width: 12),
                      FilterDropdown<StockAlertFilter>(
                        label: 'Stock',
                        value: state.filterStockAlert,
                        items: const [
                          DropdownMenuItem(value: StockAlertFilter.all, child: Text('Todo el stock')),
                          DropdownMenuItem(value: StockAlertFilter.low, child: Text('Bajo mínimo')),
                          DropdownMenuItem(value: StockAlertFilter.outOfStock, child: Text('Agotados')),
                        ],
                        onChanged: notifier.filterByStockAlert,
                      ),
                      const SizedBox(width: 12),
                      FilterChip(
                        label: const Text('Incluir inactivos'),
                        selected: state.showInactive,
                        onSelected: (_) => notifier.toggleShowInactive(),
                      ),
                      if (state.hasActiveFilters) ...[
                        const SizedBox(width: 4),
                        TextButton(onPressed: clearFilters, child: const Text('Limpiar')),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: DataTableView<Product, ProductSort>(
                      columns: const [
                        TableColumn('Producto', flex: 5, sortKey: ProductSort.name),
                        TableColumn('Categoría', flex: 2, sortKey: ProductSort.category),
                        TableColumn('Precio', flex: 2, numeric: true, sortKey: ProductSort.price),
                        TableColumn('Costo', flex: 2, numeric: true, sortKey: ProductSort.costPrice),
                        TableColumn('Stock', flex: 2, numeric: true, sortKey: ProductSort.stock),
                        TableColumn('Estado', width: 112),
                      ],
                      rows: state.products,
                      loading: state.isLoading,
                      sortKey: state.sortBy,
                      ascending: state.ascending,
                      onSort: notifier.sort,
                      rowAccent: stockColorFor,
                      onRowTap: openProduct,
                      cells: (p) => [
                        _ProductNameCell(product: p),
                        Text(p.category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        Text(_currencyFmt.format(p.price),
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                        Text(_currencyFmt.format(p.costPrice),
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        _StockCell(product: p),
                        _StatusBadge(active: p.isActive),
                      ],
                      empty: state.isLoading ? null : empty,
                      footer: pager,
                    ),
                  ),
                ],
              ),
            ),

      // ── FAB: Crear producto (en escritorio va en el encabezado) ──
      floatingActionButton: context.isCompact
          ? FloatingActionButton.extended(
              onPressed: () => context.go('/admin/products/new'),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nuevo Producto'),
            )
          : null,
    );
  }

  /// Bottom sheet para filtrar por alerta de stock (US-017) y categoría
  void _showFilterSheet(
    BuildContext context,
    ProductListNotifier notifier,
    ProductListState state,
  ) {
    showAdaptiveSheet(
      context: context,
      builder: (_) => SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── US-017: Alerta de stock ──
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Alerta de Stock',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  children: [
                    _StockAlertChip(
                      label: 'Todos',
                      selected: state.filterStockAlert == StockAlertFilter.all,
                      onTap: () =>
                          notifier.filterByStockAlert(StockAlertFilter.all),
                    ),
                    _StockAlertChip(
                      label: 'Bajo mínimo',
                      color: AppColors.stockWarning,
                      selected: state.filterStockAlert == StockAlertFilter.low,
                      onTap: () =>
                          notifier.filterByStockAlert(StockAlertFilter.low),
                    ),
                    _StockAlertChip(
                      label: 'Agotado',
                      color: AppColors.stockCritical,
                      selected:
                          state.filterStockAlert == StockAlertFilter.outOfStock,
                      onTap: () => notifier.filterByStockAlert(
                        StockAlertFilter.outOfStock,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // ── Categoría ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.category_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Filtrar por Categoría',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    if (state.filterCategory != null)
                      TextButton(
                        onPressed: () => notifier.filterByCategory(null),
                        child: const Text('Limpiar'),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ...AppConstants.productCategories.map(
                (cat) => ListTile(
                  leading: Icon(
                    state.filterCategory == cat
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: state.filterCategory == cat
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    size: 20,
                  ),
                  title: Text(
                    cat,
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                  dense: true,
                  onTap: () {
                    notifier.filterByCategory(cat);
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Search Bar ────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: 'Buscar por nombre o código de barras...',
          hintStyle: const TextStyle(color: AppColors.textDisabled),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.textSecondary,
          ),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                  onPressed: onClear,
                )
              : null,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

// ── Active Filters Chip ───────────────────────────────────────

class _ActiveFiltersChip extends StatelessWidget {
  final String? category;
  final bool showInactive;
  final StockAlertFilter stockAlert;
  final VoidCallback onClear;

  const _ActiveFiltersChip({
    this.category,
    this.showInactive = false,
    this.stockAlert = StockAlertFilter.all,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final labels = <String>[];
    if (stockAlert == StockAlertFilter.low) labels.add('Bajo mínimo');
    if (stockAlert == StockAlertFilter.outOfStock) labels.add('Agotado');
    if (category != null) labels.add(category!);
    if (showInactive) labels.add('Inactivos visibles');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.filter_alt_rounded,
            size: 16,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              labels.join(' · '),
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Quitar filtros',
            onPressed: onClear,
            icon: const Icon(Icons.close_rounded, color: AppColors.primary),
            iconSize: 16,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
          ),
        ],
      ),
    );
  }
}

// ── Chip de filtro de alerta de stock (US-017) ────────────────

class _StockAlertChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _StockAlertChip({
    required this.label,
    this.color = AppColors.primary,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return HoverInkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.15)
              : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// ── Celdas de la tabla (USB-018) ──────────────────────────────

class _ProductNameCell extends StatelessWidget {
  final Product product;
  const _ProductNameCell({required this.product});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ProductThumbnail(imageUrl: product.imageUrl, size: 36),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
              ),
              if (product.barcode != null && product.barcode!.isNotEmpty)
                Text(
                  product.barcode!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StockCell extends StatelessWidget {
  final Product product;
  const _StockCell({required this.product});

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(children: [
        TextSpan(
          text: '${product.stock}',
          style: TextStyle(color: stockColorFor(product), fontWeight: FontWeight.w700),
        ),
        TextSpan(
          text: '  mín ${product.minStock}',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      ]),
      style: const TextStyle(fontSize: 13.5),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool active;
  const _StatusBadge({required this.active});

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.success : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        active ? 'Activo' : 'Inactivo',
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool hasFilters;
  final VoidCallback onClearFilters;

  const _EmptyState({required this.hasFilters, required this.onClearFilters});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasFilters ? Icons.search_off_rounded : Icons.inventory_2_outlined,
            size: 64,
            color: AppColors.textDisabled,
          ),
          const SizedBox(height: 16),
          Text(
            hasFilters
                ? 'No se encontraron productos con esos filtros'
                : 'No hay productos registrados',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          if (hasFilters)
            OutlinedButton.icon(
              onPressed: onClearFilters,
              icon: const Icon(Icons.clear_all_rounded),
              label: const Text('Limpiar filtros'),
            )
          else
            OutlinedButton.icon(
              onPressed: () => context.go('/admin/products/new'),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Crear primer producto'),
            ),
        ],
      ),
    );
  }
}
