// ============================================================
// lib/features/dashboard/presentation/pages/sale_detail_page.dart
// US-047: detalle de una venta histórica (AdminMaster)
// US-049: productos archivados, restaurables desde acá
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/utils/receipt_pdf.dart';
import '../../../pos/domain/entities/sale.dart';
import '../../../pos/domain/entities/sale_item.dart';
import '../../../pos/presentation/providers/sales_history_providers.dart';
import '../../../products/presentation/providers/product_providers.dart'
    show toggleProductStatusUseCaseProvider, productListProvider;

class SaleDetailPage extends ConsumerWidget {
  final String saleId;
  const SaleDetailPage({super.key, required this.saleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(saleDetailProvider(saleId));

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: Text('Venta #${saleId.substring(0, 8)}')),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (_, _) => const Center(
          child: Text('Error al cargar la venta', style: TextStyle(color: AppColors.error)),
        ),
        data: (result) {
          if (result.failure != null || result.sale == null) {
            return Center(
              child: Text(result.failure?.message ?? 'Venta no encontrada',
                  style: const TextStyle(color: AppColors.error)),
            );
          }
          return _SaleDetailBody(sale: result.sale!, items: result.items);
        },
      ),
    );
  }
}

class _SaleDetailBody extends ConsumerWidget {
  final Sale sale;
  final List<SaleItem> items;

  const _SaleDetailBody({required this.sale, required this.items});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencyFmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    final dateFmt = DateFormat('dd/MM/yyyy hh:mm a', 'es');

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (sale.isCancelled) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.error),
            ),
            child: const Row(
              children: [
                Icon(Icons.cancel_outlined, color: AppColors.error, size: 18),
                SizedBox(width: 8),
                Text('Venta cancelada', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              const Text('Total', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 4),
              Text(currencyFmt.format(sale.total),
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 30)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _InfoRow(label: 'Fecha', value: dateFmt.format(sale.createdAt.toLocal())),
        _InfoRow(label: 'Cajero', value: sale.cashierName ?? 'Desconocido'),
        _InfoRow(label: 'Método de pago', value: paymentMethodLabel(sale.paymentMethod)),
        if (sale.isCash) ...[
          _InfoRow(label: 'Recibido', value: currencyFmt.format(sale.cashAmount ?? 0)),
          _InfoRow(label: 'Cambio', value: currencyFmt.format(sale.changeAmount ?? 0)),
        ],
        if (sale.isMixed) ...[
          _InfoRow(label: 'Efectivo', value: currencyFmt.format(sale.cashAmount ?? 0)),
          _InfoRow(label: 'Transferencia', value: currencyFmt.format(sale.transferAmount ?? 0)),
        ],
        const SizedBox(height: 20),
        const Text('Ítems', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
        const SizedBox(height: 8),
        ...items.map((item) => _SaleItemTile(item: item, currencyFmt: currencyFmt)),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _shareReceipt(context),
            icon: const Icon(Icons.share_rounded),
            label: const Text('Compartir recibo'),
          ),
        ),
      ],
    );
  }

  Future<void> _shareReceipt(BuildContext context) async {
    final bytes = await buildReceiptPdfBytes(
      saleId: sale.id,
      createdAt: sale.createdAt,
      total: sale.total,
      paymentMethod: sale.paymentMethod,
      items: items.map((i) => (name: i.productName, quantity: i.quantity, subtotal: i.subtotal)).toList(),
      cashAmount: sale.cashAmount,
      transferAmount: sale.transferAmount,
      changeAmount: sale.changeAmount,
    );
    final xFile = XFile.fromData(bytes, name: 'recibo_${sale.id}.pdf', mimeType: 'application/pdf');
    await Share.shareXFiles([xFile], text: 'Recibo de venta — Sistema Bs');
  }
}

class _SaleItemTile extends ConsumerStatefulWidget {
  final SaleItem item;
  final NumberFormat currencyFmt;
  const _SaleItemTile({required this.item, required this.currencyFmt});

  @override
  ConsumerState<_SaleItemTile> createState() => _SaleItemTileState();
}

class _SaleItemTileState extends ConsumerState<_SaleItemTile> {
  bool _isRestoring = false;

  Future<void> _restore() async {
    setState(() => _isRestoring = true);
    final result = await ref.read(toggleProductStatusUseCaseProvider)(
      productId: widget.item.productId,
      isActive: true,
    );
    if (!mounted) return;
    setState(() => _isRestoring = false);

    if (result.failure != null) {
      AppSnackbar.error(context, result.failure!.message);
      return;
    }
    ref.invalidate(saleDetailProvider(widget.item.saleId));
    ref.invalidate(productListProvider);
    AppSnackbar.success(context, '"${widget.item.productName}" restaurado al catálogo');
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: item.isProductArchived ? AppColors.warning : AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(item.productName,
                            style: const TextStyle(
                                color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (item.isProductArchived) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('Archivado',
                              style: TextStyle(color: AppColors.warning, fontSize: 10, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text('${item.quantity} x ${widget.currencyFmt.format(item.unitPrice)}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            Text(widget.currencyFmt.format(item.subtotal),
                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
            if (item.isProductArchived) ...[
              const SizedBox(width: 8),
              _isRestoring
                  ? const SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                  : IconButton(
                      tooltip: 'Restaurar producto',
                      icon: const Icon(Icons.restore_rounded, color: AppColors.primary, size: 20),
                      onPressed: _restore,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
