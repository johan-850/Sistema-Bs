// ============================================================
// lib/features/inventory/presentation/widgets/stock_adjustment_sheet.dart
// US-021: Ajuste manual de stock (entrada/salida + motivo)
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../products/domain/entities/product.dart';
import '../providers/inventory_providers.dart';

const Map<String, String> _reasonLabels = {
  'recepcion': 'Recepción',
  'merma': 'Merma',
  'devolucion': 'Devolución',
  'ajuste': 'Ajuste',
};

class StockAdjustmentSheet extends ConsumerStatefulWidget {
  final Product product;
  const StockAdjustmentSheet({super.key, required this.product});

  static Future<bool?> show(BuildContext context, Product product) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: StockAdjustmentSheet(product: product),
      ),
    );
  }

  @override
  ConsumerState<StockAdjustmentSheet> createState() => _StockAdjustmentSheetState();
}

class _StockAdjustmentSheetState extends ConsumerState<StockAdjustmentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _quantityCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _movementType = 'entrada';
  String _reason = AppConstants.stockAdjustmentReasons.first;

  @override
  void dispose() {
    _quantityCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(stockAdjustmentProvider);

    ref.listen<StockAdjustmentState>(stockAdjustmentProvider, (_, next) {
      if (next.failure != null) AppSnackbar.error(context, next.failure!.message);
      if (next.success) Navigator.pop(context, true);
    });

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.tune_rounded, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ajustar stock — ${widget.product.name}',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Stock actual: ${widget.product.stock} ${widget.product.unit}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),

            // Tipo: entrada / salida
            Row(
              children: AppConstants.stockMovementTypes.map((type) {
                final selected = _movementType == type;
                final isEntrada = type == 'entrada';
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: isEntrada ? 8 : 0),
                    child: OutlinedButton.icon(
                      onPressed: () => setState(() => _movementType = type),
                      icon: Icon(isEntrada ? Icons.add_rounded : Icons.remove_rounded),
                      label: Text(isEntrada ? 'Entrada' : 'Salida'),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: selected
                            ? (isEntrada ? AppColors.success : AppColors.error).withValues(alpha: 0.15)
                            : null,
                        foregroundColor: selected
                            ? (isEntrada ? AppColors.success : AppColors.error)
                            : AppColors.textSecondary,
                        side: BorderSide(
                          color: selected
                              ? (isEntrada ? AppColors.success : AppColors.error)
                              : AppColors.border,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Motivo
            DropdownButtonFormField<String>(
              initialValue: _reason,
              dropdownColor: AppColors.surfaceElevated,
              isExpanded: true,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: const InputDecoration(
                labelText: 'Motivo',
                prefixIcon: Icon(Icons.notes_rounded),
              ),
              items: AppConstants.stockAdjustmentReasons
                  .map((r) => DropdownMenuItem(value: r, child: Text(_reasonLabels[r] ?? r)))
                  .toList(),
              onChanged: (v) => setState(() => _reason = v ?? _reason),
            ),
            const SizedBox(height: 12),

            // Cantidad
            TextFormField(
              controller: _quantityCtrl,
              style: const TextStyle(color: AppColors.textPrimary),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Cantidad *',
                prefixIcon: Icon(Icons.numbers_rounded),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Obligatorio';
                final val = int.tryParse(v);
                if (val == null || val <= 0) return 'Debe ser mayor a 0';
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Notas
            TextFormField(
              controller: _notesCtrl,
              style: const TextStyle(color: AppColors.textPrimary),
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notas (opcional)',
                prefixIcon: Icon(Icons.description_outlined),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: state.isLoading ? null : _submit,
                icon: state.isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : const Icon(Icons.check_rounded),
                label: const Text('Confirmar ajuste'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    ref.read(stockAdjustmentProvider.notifier).adjust(
          productId: widget.product.id,
          movementType: _movementType,
          reason: _reason,
          quantity: int.parse(_quantityCtrl.text),
          notes: _notesCtrl.text.isEmpty ? null : _notesCtrl.text,
        );
  }
}
