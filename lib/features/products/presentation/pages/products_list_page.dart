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
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/product_list_card.dart';
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

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Inventario'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/admin'),
        ),
        actions: [
          // US-019: Importar productos desde CSV
          IconButton(
            tooltip: 'Importar CSV',
            icon: const Icon(Icons.upload_file_rounded),
            onPressed: () => context.push('/admin/products/import'),
          ),
          // Botón de filtros (categoría + alerta de stock — US-017)
          IconButton(
            icon: Badge(
              isLabelVisible:
                  state.filterCategory != null ||
                  state.filterStockAlert != StockAlertFilter.all,
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.filter_list_rounded),
            ),
            onPressed: () => _showFilterSheet(context, notifier, state),
          ),
          // Toggle productos inactivos
          IconButton(
            icon: Icon(
              state.showInactive
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              color: state.showInactive ? AppColors.warning : null,
            ),
            tooltip: state.showInactive
                ? 'Ocultar inactivos'
                : 'Mostrar inactivos',
            onPressed: () => notifier.toggleShowInactive(),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Barra de búsqueda ──────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: _SearchBar(
              controller: _searchController,
              onChanged: (q) => notifier.search(q),
              onClear: () {
                _searchController.clear();
                notifier.search('');
              },
            ),
          ),

          // ── Indicador de filtros activos ─────────────────────
          if (state.hasActiveFilters)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _ActiveFiltersChip(
                category: state.filterCategory,
                showInactive: state.showInactive,
                stockAlert: state.filterStockAlert,
                onClear: () {
                  _searchController.clear();
                  notifier.clearFilters();
                },
              ),
            ),

          // ── Lista de productos ──────────────────────────────
          Expanded(
            child: state.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : state.products.isEmpty
                ? _EmptyState(
                    hasFilters: state.hasActiveFilters,
                    onClearFilters: () {
                      _searchController.clear();
                      notifier.clearFilters();
                    },
                  )
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
                        onTap: () => context.go(
                          '/admin/products/edit/${state.products[i].id}',
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),

      // ── FAB: Crear producto ─────────────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/admin/products/new'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuevo Producto'),
      ),
    );
  }

  /// Bottom sheet para filtrar por alerta de stock (US-017) y categoría
  void _showFilterSheet(
    BuildContext context,
    ProductListNotifier notifier,
    ProductListState state,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
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
          GestureDetector(
            onTap: onClear,
            child: const Icon(
              Icons.close_rounded,
              size: 16,
              color: AppColors.primary,
            ),
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
    return GestureDetector(
      onTap: onTap,
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
