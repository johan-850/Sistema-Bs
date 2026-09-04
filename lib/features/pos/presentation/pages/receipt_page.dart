// ============================================================
// lib/features/pos/presentation/pages/receipt_page.dart
// Recibo digital — US-031
// ============================================================

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/receipt_pdf.dart';
import '../../domain/entities/cart_item.dart';
import '../../domain/entities/sale.dart';

class ReceiptPage extends StatelessWidget {
  final Sale sale;
  final List<CartItem> items;

  const ReceiptPage({super.key, required this.sale, required this.items});

  static String paymentLabel(String method) => paymentMethodLabel(method);

  @override
  Widget build(BuildContext context) {
    final currencyFmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    final dateFmt = DateFormat('dd/MM/yyyy hh:mm a', 'es');

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Recibo'), automaticallyImplyLeading: false),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Center(
            child: Column(
              children: [
                Icon(Icons.check_circle_rounded, color: AppColors.success, size: 56),
                SizedBox(height: 12),
                Text('Venta confirmada',
                    style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Sistema Bs',
                    style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                Text(dateFmt.format(sale.createdAt.toLocal()),
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                const Divider(height: 24, color: AppColors.border),
                ...items.map((i) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text('${i.name} x${i.quantity}',
                                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                          ),
                          Text(currencyFmt.format(i.subtotal),
                              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                        ],
                      ),
                    )),
                const Divider(height: 24, color: AppColors.border),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total',
                        style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(currencyFmt.format(sale.total),
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
                const SizedBox(height: 10),
                _ReceiptRow(label: 'Método de pago', value: paymentLabel(sale.paymentMethod)),
                if (sale.isCash) ...[
                  _ReceiptRow(label: 'Recibido', value: currencyFmt.format(sale.cashAmount ?? 0)),
                  _ReceiptRow(label: 'Cambio', value: currencyFmt.format(sale.changeAmount ?? 0)),
                ],
                if (sale.isMixed) ...[
                  _ReceiptRow(label: 'Efectivo', value: currencyFmt.format(sale.cashAmount ?? 0)),
                  _ReceiptRow(label: 'Transferencia', value: currencyFmt.format(sale.transferAmount ?? 0)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _sharePdf,
                  icon: const Icon(Icons.share_rounded),
                  label: const Text('Compartir PDF'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _printPdf,
                  icon: const Icon(Icons.print_outlined),
                  label: const Text('Imprimir'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => context.go('/pos'),
              icon: const Icon(Icons.add_shopping_cart_rounded),
              label: const Text('Nueva venta'),
            ),
          ),
        ],
      ),
    );
  }

  List<ReceiptLineItem> get _lineItems =>
      items.map((i) => (name: i.name, quantity: i.quantity, subtotal: i.subtotal)).toList();

  Future<Uint8List> _buildPdfBytes() => buildReceiptPdfBytes(
        saleId: sale.id,
        createdAt: sale.createdAt,
        total: sale.total,
        paymentMethod: sale.paymentMethod,
        items: _lineItems,
        cashAmount: sale.cashAmount,
        transferAmount: sale.transferAmount,
        changeAmount: sale.changeAmount,
      );

  Future<void> _sharePdf() async {
    final bytes = await _buildPdfBytes();
    final xFile = XFile.fromData(bytes, name: 'recibo_${sale.id}.pdf', mimeType: 'application/pdf');
    await Share.shareXFiles([xFile], text: 'Recibo de venta — Sistema Bs');
  }

  Future<void> _printPdf() async {
    await Printing.layoutPdf(
      onLayout: (_) => _buildPdfBytes(),
      name: 'recibo_${sale.id}',
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  final String label;
  final String value;
  const _ReceiptRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
