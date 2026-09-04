// ============================================================
// lib/features/inventory/presentation/pages/restock_list_page.dart
// US-024: Lista de productos para restock (bajo stock mínimo)
// ============================================================

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/confirmation_dialog.dart';
import '../../../products/domain/entities/product.dart';
import '../providers/inventory_providers.dart';

class RestockListPage extends ConsumerWidget {
  const RestockListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(restockListProvider);
    final notifier = ref.read(restockListProvider.notifier);

    ref.listen<RestockListState>(restockListProvider, (_, next) {
      if (next.failure != null) AppSnackbar.error(context, next.failure!.message);
    });

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Lista de Restock'),
        actions: [
          IconButton(
            tooltip: 'Exportar CSV',
            icon: const Icon(Icons.download_rounded),
            onPressed: () => _exportCSV(context, state.lowStockProducts),
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : state.lowStockProducts.isEmpty
              ? const Center(
                  child: Text('No hay productos bajo el stock mínimo 🎉',
                      style: TextStyle(color: AppColors.textSecondary)),
                )
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () => notifier.load(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: state.lowStockProducts.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final product = state.lowStockProducts[i];
                      final requested = state.requestedProductIds.contains(product.id);
                      return _RestockRow(
                        product: product,
                        alreadyRequested: requested,
                        onMarkRequested: requested
                            ? null
                            : () => _confirmMarkRequested(context, notifier, product),
                      );
                    },
                  ),
                ),
    );
  }

  Future<void> _confirmMarkRequested(
    BuildContext context,
    RestockListNotifier notifier,
    Product product,
  ) async {
    await ConfirmationDialog.show(
      context,
      title: 'Marcar pedido realizado',
      message: '¿Confirmas que ya se hizo el pedido de "${product.name}" al proveedor?',
      confirmLabel: 'Confirmar',
      onConfirm: () async {
        final ok = await notifier.markRequested(product.id);
        if (context.mounted && ok) {
          AppSnackbar.success(context, 'Marcado como pedido realizado.');
        }
      },
    );
  }

  Future<void> _exportCSV(BuildContext context, List<Product> products) async {
    if (products.isEmpty) {
      AppSnackbar.warning(context, 'No hay productos para exportar.');
      return;
    }
    final rows = [
      ['Código', 'Nombre', 'Stock actual', 'Stock mínimo', 'Diferencia'],
      ...products.map((p) => [
            p.barcode ?? '',
            p.name,
            p.stock,
            p.minStock,
            p.minStock - p.stock,
          ]),
    ];
    final csv = const ListToCsvConverter().convert(rows);
    final bytes = utf8.encode(csv);
    final xFile = XFile.fromData(
      Uint8List.fromList(bytes),
      name: 'restock_${DateTime.now().millisecondsSinceEpoch}.csv',
      mimeType: 'text/csv',
    );
    await Share.shareXFiles([xFile], text: 'Lista de restock');
  }
}

class _RestockRow extends StatelessWidget {
  final Product product;
  final bool alreadyRequested;
  final VoidCallback? onMarkRequested;

  const _RestockRow({
    required this.product,
    required this.alreadyRequested,
    required this.onMarkRequested,
  });

  @override
  Widget build(BuildContext context) {
    final color = product.isOutOfStock ? AppColors.stockCritical : AppColors.stockWarning;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(product.name,
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              Text(
                'Faltan ${product.minStock - product.stock}',
                style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Stock: ${product.stock} / mín. ${product.minStock} ${product.unit}',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: alreadyRequested
                ? OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.check_circle_outline_rounded, color: AppColors.success),
                    label: const Text('Pedido realizado', style: TextStyle(color: AppColors.success)),
                  )
                : OutlinedButton.icon(
                    onPressed: onMarkRequested,
                    icon: const Icon(Icons.local_shipping_outlined),
                    label: const Text('Marcar pedido realizado'),
                  ),
          ),
        ],
      ),
    );
  }
}
