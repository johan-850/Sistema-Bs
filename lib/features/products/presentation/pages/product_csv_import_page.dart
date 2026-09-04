// ============================================================
// lib/features/products/presentation/pages/product_csv_import_page.dart
// US-019: Carga de productos en lote desde un archivo CSV
// ============================================================

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/confirmation_dialog.dart';
import '../providers/product_providers.dart';

class ProductCsvImportPage extends ConsumerWidget {
  const ProductCsvImportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(productCsvImportProvider);
    final notifier = ref.read(productCsvImportProvider.notifier);

    ref.listen<ProductCsvImportState>(productCsvImportProvider, (_, next) {
      if (next.failure != null) {
        AppSnackbar.warning(context, next.failure!.message);
      }
      if (next.hasImportResult) {
        AppSnackbar.success(
          context,
          '${next.importedCount} producto(s) importado(s)'
          '${next.failedCount! > 0 ? ", ${next.failedCount} con error" : ""}.',
        );
        ref.read(productListProvider.notifier).refresh();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Importar Productos (CSV)'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/admin/products'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          // ── Formato esperado ──
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 18),
                    SizedBox(width: 8),
                    Text('Formato esperado',
                        style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  AppConstants.csvImportHeaders.join(', '),
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                ),
                const SizedBox(height: 4),
                Text(
                  'Máximo ${AppConstants.maxCsvImportRows} productos por archivo. '
                  'Los campos barcode, description y supplier son opcionales.',
                  style: const TextStyle(color: AppColors.textDisabled, fontSize: 12),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _downloadTemplate(context, notifier),
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('Descargar plantilla'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Selección de archivo ──
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: state.isParsing || state.isImporting
                  ? null
                  : notifier.pickAndParseFile,
              icon: state.isParsing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Icon(Icons.upload_file_rounded),
              label: Text(state.rows.isEmpty ? 'Seleccionar archivo CSV' : 'Elegir otro archivo'),
            ),
          ),

          if (state.rows.isNotEmpty) ...[
            const SizedBox(height: 20),
            _SummaryRow(validCount: state.validCount, invalidCount: state.invalidCount),
            const SizedBox(height: 12),
            ...state.rows.map((row) => _CsvRowTile(row: row)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: state.validCount == 0 || state.isImporting || state.hasImportResult
                    ? null
                    : () => _confirmImport(context, notifier, state.validCount),
                icon: state.isImporting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : const Icon(Icons.check_circle_outline_rounded),
                label: Text('Confirmar importación (${state.validCount})'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _downloadTemplate(BuildContext context, ProductCsvImportNotifier notifier) async {
    final csv = notifier.buildTemplateCsv();
    final bytes = utf8.encode(csv);
    final xFile = XFile.fromData(
      Uint8List.fromList(bytes),
      name: 'plantilla_productos.csv',
      mimeType: 'text/csv',
    );
    await Share.shareXFiles([xFile], text: 'Plantilla de importación de productos');
  }

  Future<void> _confirmImport(
    BuildContext context,
    ProductCsvImportNotifier notifier,
    int validCount,
  ) async {
    await ConfirmationDialog.show(
      context,
      title: 'Confirmar importación',
      message: 'Se crearán $validCount producto(s) nuevo(s) en el catálogo. '
          'Esta acción no se puede deshacer.',
      confirmLabel: 'Importar',
      onConfirm: notifier.confirmImport,
    );
  }
}

// ── Resumen de filas válidas / con error ──────────────────────

class _SummaryRow extends StatelessWidget {
  final int validCount;
  final int invalidCount;
  const _SummaryRow({required this.validCount, required this.invalidCount});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _SummaryChip(
          icon: Icons.check_circle_outline_rounded,
          color: AppColors.success,
          label: '$validCount válidas',
        ),
        const SizedBox(width: 10),
        if (invalidCount > 0)
          _SummaryChip(
            icon: Icons.error_outline_rounded,
            color: AppColors.error,
            label: '$invalidCount con error',
          ),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  const _SummaryChip({required this.icon, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── Fila individual del preview ────────────────────────────────

class _CsvRowTile extends StatelessWidget {
  final ProductCsvRow row;
  const _CsvRowTile({required this.row});

  @override
  Widget build(BuildContext context) {
    final isValid = row.isValid;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isValid ? AppColors.border : AppColors.error.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
            size: 18,
            color: isValid ? AppColors.success : AppColors.error,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fila ${row.rowNumber} · ${row.name.isEmpty ? "(sin nombre)" : row.name}',
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (!isValid)
                  Text(
                    row.error!,
                    style: const TextStyle(color: AppColors.error, fontSize: 12),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
