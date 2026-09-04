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
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/product_list_card.dart';
import '../../../products/domain/entities/product.dart';
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

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Inventario'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/admin'),
        ),
        actions: [
          IconButton(
            tooltip: 'Lista de restock',
            icon: const Icon(Icons.playlist_add_check_rounded),
            onPressed: () => context.push('/admin/inventory/restock'),
          ),
          IconButton(
            tooltip: 'Exportar CSV',
            icon: const Icon(Icons.download_rounded),
            onPressed: () => _exportCSV(context, state.products),
          ),
          IconButton(
            icon: Badge(
              isLabelVisible: state.filterStockAlert != StockAlertFilter.all,
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.filter_list_rounded),
            ),
            onPressed: () => _showAlertFilterSheet(context, notifier, state),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
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
            ),
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
      ),
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
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
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
