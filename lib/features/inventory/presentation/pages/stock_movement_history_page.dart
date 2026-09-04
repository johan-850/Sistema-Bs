// ============================================================
// lib/features/inventory/presentation/pages/stock_movement_history_page.dart
// US-023: Historial de movimientos de stock de un producto
// ============================================================

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../products/domain/entities/product.dart';
import '../../../products/presentation/providers/product_providers.dart' show productRepositoryProvider;
import '../../domain/entities/stock_movement.dart';
import '../providers/inventory_providers.dart';

const Map<String, String> _reasonLabels = {
  'venta': 'Venta',
  'recepcion': 'Recepción',
  'merma': 'Merma',
  'devolucion': 'Devolución',
  'ajuste': 'Ajuste',
};

class StockMovementHistoryPage extends ConsumerStatefulWidget {
  final String productId;
  const StockMovementHistoryPage({super.key, required this.productId});

  @override
  ConsumerState<StockMovementHistoryPage> createState() => _StockMovementHistoryPageState();
}

class _StockMovementHistoryPageState extends ConsumerState<StockMovementHistoryPage> {
  final _dateFmt = DateFormat('dd/MM/yyyy HH:mm');
  Product? _product;

  @override
  void initState() {
    super.initState();
    _loadProduct();
  }

  Future<void> _loadProduct() async {
    final result = await ref.read(productRepositoryProvider).getProductById(widget.productId);
    if (mounted && result.product != null) {
      setState(() => _product = result.product);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(stockMovementHistoryProvider(widget.productId));
    final notifier = ref.read(stockMovementHistoryProvider(widget.productId).notifier);

    ref.listen<StockMovementHistoryState>(stockMovementHistoryProvider(widget.productId), (_, next) {
      if (next.failure != null) AppSnackbar.error(context, next.failure!.message);
    });

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(_product?.name ?? 'Historial de movimientos'),
        actions: [
          IconButton(
            tooltip: 'Exportar CSV',
            icon: const Icon(Icons.download_rounded),
            onPressed: () => _exportCSV(context, state.movements),
          ),
          IconButton(
            icon: Badge(
              isLabelVisible: state.hasDateFilter,
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.date_range_rounded),
            ),
            onPressed: () => _showDateFilterSheet(context, notifier, state),
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : state.movements.isEmpty
              ? const Center(
                  child: Text('Sin movimientos registrados',
                      style: TextStyle(color: AppColors.textSecondary)),
                )
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () => notifier.load(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: state.movements.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) =>
                        _MovementTile(movement: state.movements[i], dateFmt: _dateFmt),
                  ),
                ),
    );
  }

  void _showDateFilterSheet(
    BuildContext context,
    StockMovementHistoryNotifier notifier,
    StockMovementHistoryState state,
  ) {
    DateTime? from = state.from;
    DateTime? to = state.to;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Filtrar por fecha',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: AppColors.textPrimary)),
              const SizedBox(height: 20),
              _DateTile(
                label: 'Desde',
                value: from,
                onPicked: (d) => setModal(() => from = d),
              ),
              const SizedBox(height: 12),
              _DateTile(
                label: 'Hasta',
                value: to,
                onPicked: (d) => setModal(() => to = d),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        notifier.filterByDateRange(from: null, to: null);
                      },
                      child: const Text('Limpiar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        notifier.filterByDateRange(from: from, to: to);
                      },
                      child: const Text('Aplicar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportCSV(BuildContext context, List<StockMovement> movements) async {
    if (movements.isEmpty) {
      AppSnackbar.warning(context, 'No hay movimientos para exportar.');
      return;
    }
    final rows = [
      ['Fecha', 'Tipo', 'Motivo', 'Cantidad', 'Stock anterior', 'Stock nuevo', 'Usuario', 'Notas'],
      ...movements.map((m) => [
            _dateFmt.format(m.createdAt.toLocal()),
            m.isEntrada ? 'Entrada' : 'Salida',
            _reasonLabels[m.reason] ?? m.reason,
            m.quantity,
            m.previousStock,
            m.newStock,
            m.userName ?? '',
            m.notes ?? '',
          ]),
    ];
    final csv = const ListToCsvConverter().convert(rows);
    final bytes = utf8.encode(csv);
    final xFile = XFile.fromData(
      Uint8List.fromList(bytes),
      name: 'movimientos_stock_${DateTime.now().millisecondsSinceEpoch}.csv',
      mimeType: 'text/csv',
    );
    await Share.shareXFiles([xFile], text: 'Historial de movimientos de stock');
  }
}

class _MovementTile extends StatelessWidget {
  final StockMovement movement;
  final DateFormat dateFmt;
  const _MovementTile({required this.movement, required this.dateFmt});

  @override
  Widget build(BuildContext context) {
    final color = movement.isEntrada ? AppColors.success : AppColors.error;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(
              movement.isEntrada ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${movement.isEntrada ? '+' : '-'}${movement.quantity}',
                      style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    const SizedBox(width: 8),
                    Text(_reasonLabels[movement.reason] ?? movement.reason,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Saldo: ${movement.previousStock} → ${movement.newStock}',
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                ),
                if (movement.notes != null && movement.notes!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(movement.notes!,
                      style: const TextStyle(color: AppColors.textDisabled, fontSize: 12)),
                ],
                const SizedBox(height: 6),
                Text(
                  '${dateFmt.format(movement.createdAt.toLocal())}'
                  '${movement.userName != null ? ' · ${movement.userName}' : ''}',
                  style: const TextStyle(color: AppColors.textDisabled, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onPicked;

  const _DateTile({required this.label, required this.value, required this.onPicked});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2024),
          lastDate: DateTime.now(),
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: const ColorScheme.dark(primary: AppColors.primary, surface: AppColors.surfaceCard),
            ),
            child: child!,
          ),
        );
        if (picked != null) onPicked(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 10),
            Text(
              '$label: ${value != null ? fmt.format(value!) : 'Cualquier fecha'}',
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
