// ============================================================
// lib/features/inventory/presentation/pages/inventory_dashboard_page.dart
// US-020: Dashboard de inventario con semáforo, filtro de alerta,
// export CSV y actualización en tiempo real (Supabase Realtime)
// ============================================================

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/breakpoints.dart';
import '../../../../core/widgets/adaptive_sheet.dart';
import '../../../../core/widgets/app_page_bar.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/data_table_view.dart';
import '../../../../core/widgets/product_list_card.dart';
import '../../../products/domain/entities/product.dart';
import '../../../products/domain/repositories/product_repository.dart'
    show ProductSort;
import '../../../products/presentation/providers/product_providers.dart'
    show StockAlertFilter;
import '../providers/inventory_providers.dart';
import '../widgets/stock_adjustment_sheet.dart';

class InventoryDashboardPage extends ConsumerStatefulWidget {
  const InventoryDashboardPage({super.key});

  @override
  ConsumerState<InventoryDashboardPage> createState() =>
      _InventoryDashboardPageState();
}

class _InventoryDashboardPageState
    extends ConsumerState<InventoryDashboardPage> {
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
    final state = ref.watch(inventoryListProvider);
    final notifier = ref.read(inventoryListProvider.notifier);

    ref.listen<InventoryListState>(inventoryListProvider, (_, next) {
      if (next.failure != null) {
        AppSnackbar.error(context, next.failure!.message);
      }
    });

    final compact = context.isCompact;
    void openMovements(Product p) =>
        context.push('/admin/inventory/${p.id}/movements');

    final search = TextField(
      controller: _searchController,
      onChanged: (q) => notifier.search(q),
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: 'Buscar por nombre o código de barras...',
        hintStyle: const TextStyle(color: AppColors.textDisabled),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: AppColors.textSecondary,
        ),
        filled: true,
        fillColor: AppColors.surfaceElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppPageBar(
        title: 'Inventario',
        actions: [
          // En escritorio el filtro de alerta está a la vista.
          if (compact)
            PageAction(
              icon: Icons.filter_list_rounded,
              label: 'Filtrar',
              highlighted: state.filterStockAlert != StockAlertFilter.all,
              onPressed: () => _showAlertFilterSheet(context, notifier, state),
            ),
          PageAction(
            icon: Icons.download_rounded,
            label: 'Exportar CSV',
            onPressed: () => _exportCSV(context, state.products),
          ),
          PageAction(
            icon: Icons.playlist_add_check_rounded,
            label: 'Lista de restock',
            onPressed: () => context.push('/admin/inventory/restock'),
          ),
        ],
      ),
      body: compact
          ? _compactBody(state, notifier, search)
          // ── USB-020: tabla de escritorio ───────────────────────
          : Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: search),
                      const SizedBox(width: 16),
                      SegmentedButton<StockAlertFilter>(
                        showSelectedIcon: false,
                        segments: [
                          ButtonSegment(
                            value: StockAlertFilter.all,
                            label: Text('Todos · ${state.totalCount}'),
                          ),
                          ButtonSegment(
                            value: StockAlertFilter.low,
                            label: Text('Bajo mínimo · ${state.lowCount}'),
                          ),
                          ButtonSegment(
                            value: StockAlertFilter.outOfStock,
                            label: Text('Agotados · ${state.outCount}'),
                          ),
                        ],
                        selected: {state.filterStockAlert},
                        onSelectionChanged: (s) =>
                            notifier.filterByStockAlert(s.first),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: DataTableView<Product, ProductSort>(
                      columns: const [
                        TableColumn(
                          'Producto',
                          flex: 5,
                          sortKey: ProductSort.name,
                        ),
                        TableColumn(
                          'Categoría',
                          flex: 2,
                          sortKey: ProductSort.category,
                        ),
                        TableColumn(
                          'Precio',
                          flex: 2,
                          numeric: true,
                          sortKey: ProductSort.price,
                        ),
                        TableColumn(
                          'Stock',
                          flex: 2,
                          numeric: true,
                          sortKey: ProductSort.stock,
                        ),
                        TableColumn('', width: 256),
                      ],
                      rows: state.products,
                      loading: state.isLoading,
                      sortKey: state.sortBy,
                      ascending: state.ascending,
                      onSort: notifier.sort,
                      rowAccent: stockColorFor,
                      onRowTap: openMovements,
                      cells: (p) => [
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: p.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (p.barcode != null && p.barcode!.isNotEmpty)
                                TextSpan(
                                  text: '\n${p.barcode}',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11.5,
                                  ),
                                ),
                            ],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13.5),
                        ),
                        Text(
                          p.category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          _currencyFmt.format(p.price),
                          style: const TextStyle(fontSize: 13),
                        ),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '${p.stock}',
                                style: TextStyle(
                                  color: stockColorFor(p),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              TextSpan(
                                text: '  mín ${p.minStock}',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          style: const TextStyle(fontSize: 13.5),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              onPressed: () =>
                                  StockAdjustmentSheet.show(context, p),
                              icon: const Icon(Icons.tune_rounded, size: 18),
                              label: const Text('Ajustar'),
                            ),
                            TextButton.icon(
                              onPressed: () => openMovements(p),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.textSecondary,
                              ),
                              icon: const Icon(Icons.history_rounded, size: 18),
                              label: const Text('Historial'),
                            ),
                          ],
                        ),
                      ],
                      empty: state.isLoading
                          ? null
                          : const Center(
                              child: Text(
                                'No hay productos para mostrar',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _compactBody(
    InventoryListState state,
    InventoryListNotifier notifier,
    Widget search,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: search,
        ),
        if (state.hasActiveFilters)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Chip(
                label: Text(_alertLabel(state.filterStockAlert)),
                onDeleted: () =>
                    notifier.filterByStockAlert(StockAlertFilter.all),
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                labelStyle: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: state.isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : state.products.isEmpty
              ? const Center(
                  child: Text(
                    'No hay productos para mostrar',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () => notifier.load(),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: state.products.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => ProductListCard(
                      product: state.products[i],
                      currencyFmt: _currencyFmt,
                      showMinStock: true,
                      onTap: () => context.push(
                        '/admin/inventory/${state.products[i].id}/movements',
                      ),
                      trailing: IconButton(
                        tooltip: 'Ajustar stock',
                        icon: const Icon(
                          Icons.tune_rounded,
                          color: AppColors.primary,
                        ),
                        onPressed: () => StockAdjustmentSheet.show(
                          context,
                          state.products[i],
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  String _alertLabel(StockAlertFilter filter) => switch (filter) {
    StockAlertFilter.all => '',
    StockAlertFilter.low => 'Bajo mínimo',
    StockAlertFilter.outOfStock => 'Agotado',
  };

  void _showAlertFilterSheet(
    BuildContext context,
    InventoryListNotifier notifier,
    InventoryListState state,
  ) {
    showAdaptiveSheet(
      context: context,
      maxWidth: 400,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _alertTile(
              ctx,
              notifier,
              'Todos',
              StockAlertFilter.all,
              state.filterStockAlert,
            ),
            _alertTile(
              ctx,
              notifier,
              'Bajo mínimo',
              StockAlertFilter.low,
              state.filterStockAlert,
            ),
            _alertTile(
              ctx,
              notifier,
              'Agotado',
              StockAlertFilter.outOfStock,
              state.filterStockAlert,
            ),
          ],
        ),
      ),
    );
  }

  Widget _alertTile(
    BuildContext ctx,
    InventoryListNotifier notifier,
    String label,
    StockAlertFilter value,
    StockAlertFilter current,
  ) {
    return ListTile(
      leading: Icon(
        current == value
            ? Icons.radio_button_checked_rounded
            : Icons.radio_button_off_rounded,
        color: current == value ? AppColors.primary : AppColors.textSecondary,
      ),
      title: Text(label, style: const TextStyle(color: AppColors.textPrimary)),
      onTap: () {
        notifier.filterByStockAlert(value);
        Navigator.pop(ctx);
      },
    );
  }

  Future<void> _exportCSV(BuildContext context, List<Product> products) async {
    if (products.isEmpty) {
      AppSnackbar.warning(context, 'No hay productos para exportar.');
      return;
    }
    final rows = [
      ['Código', 'Nombre', 'Categoría', 'Stock', 'Stock mínimo', 'Estado'],
      ...products.map(
        (p) => [
          p.barcode ?? '',
          p.name,
          p.category,
          p.stock,
          p.minStock,
          p.isOutOfStock ? 'Agotado' : (p.isLowStock ? 'Bajo mínimo' : 'OK'),
        ],
      ),
    ];
    final csv = const ListToCsvConverter().convert(rows);
    final bytes = utf8.encode(csv);
    final xFile = XFile.fromData(
      Uint8List.fromList(bytes),
      name: 'inventario_${DateTime.now().millisecondsSinceEpoch}.csv',
      mimeType: 'text/csv',
    );
    await Share.shareXFiles([xFile], text: 'Exportación de Inventario');
  }
}
