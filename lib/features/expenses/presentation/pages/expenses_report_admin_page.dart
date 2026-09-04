// ============================================================
// lib/features/expenses/presentation/pages/expenses_report_admin_page.dart
// US-037: reporte consolidado de gastos (AdminMaster)
// ============================================================

import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/filter_dropdown.dart';
import '../../../users/presentation/providers/users_providers.dart';
import '../../domain/entities/expense.dart';
import '../providers/expense_providers.dart';

/// Umbral por defecto para la alerta "gastos vs. ventas" — no es un
/// valor del backlog, es un punto de partida razonable; se puede
/// ajustar después si el negocio quiere otro %.
const double _kExpensesAlertThresholdPercent = 20;

class ExpensesReportAdminPage extends ConsumerWidget {
  const ExpensesReportAdminPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(expensesReportProvider);
    final notifier = ref.read(expensesReportProvider.notifier);
    final cashiers = ref.watch(cashierListProvider).cashiers;
    final categories = ref.watch(expenseCategoriesProvider).categories;
    final cashierNames = {for (final c in cashiers) c.id: c.name};
    final currencyFmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    final dateFmt = DateFormat('dd/MM/yyyy hh:mm a', 'es');

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Gastos'),
        actions: [
          IconButton(
            tooltip: 'Categorías',
            icon: const Icon(Icons.category_outlined),
            onPressed: () => context.push('/admin/expenses/categories'),
          ),
          IconButton(
            tooltip: 'Exportar CSV',
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: state.expenses.isEmpty ? null : () => _exportCsv(state.expenses, cashierNames),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: notifier.load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Filtros ──
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterDropdown<String?>(
                  label: 'Cajero',
                  value: state.filterCashierId,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Todos')),
                    ...cashiers.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                  ],
                  onChanged: notifier.filterByCashier,
                ),
                FilterDropdown<String?>(
                  label: 'Categoría',
                  value: state.filterCategoryId,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Todas')),
                    ...categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                  ],
                  onChanged: notifier.filterByCategory,
                ),
                OutlinedButton.icon(
                  onPressed: () => _pickDateRange(context, notifier, state),
                  icon: const Icon(Icons.date_range_outlined, size: 18),
                  label: Text(
                    state.filterDateFrom == null
                        ? 'Rango de fechas'
                        : '${DateFormat('dd/MM/yy').format(state.filterDateFrom!)} - ${DateFormat('dd/MM/yy').format(state.filterDateTo ?? DateTime.now())}',
                  ),
                ),
                if (state.filterCashierId != null ||
                    state.filterCategoryId != null ||
                    state.filterDateFrom != null)
                  TextButton.icon(
                    onPressed: notifier.clearFilters,
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    label: const Text('Limpiar'),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Totales ──
            Row(
              children: [
                Expanded(
                  child: _TotalCard(
                    label: 'Gastos',
                    value: currencyFmt.format(state.expensesTotal),
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TotalCard(
                    label: 'Ventas del período',
                    value: currencyFmt.format(state.salesTotal),
                    color: AppColors.success,
                  ),
                ),
              ],
            ),

            if (state.salesTotal > 0 && state.expensesPercentOfSales > _kExpensesAlertThresholdPercent) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.stockCriticalVivid.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.stockCriticalVivid),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_rounded, color: AppColors.stockCriticalVivid),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Los gastos representan el ${state.expensesPercentOfSales.toStringAsFixed(1)}% de las ventas del período (umbral: $_kExpensesAlertThresholdPercent%).',
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (state.totalsByCategory.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Por categoría',
                  style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 8),
              ...state.totalsByCategory.entries.map((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(e.key, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        Text(currencyFmt.format(e.value),
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                      ],
                    ),
                  )),
            ],

            const SizedBox(height: 20),
            const Divider(color: AppColors.border),
            const SizedBox(height: 8),

            if (state.isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: AppColors.primary)))
            else if (state.expenses.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Sin gastos para los filtros seleccionados',
                      style: TextStyle(color: AppColors.textSecondary)),
                ),
              )
            else
              ...state.expenses.map((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(e.categoryName,
                                    style: const TextStyle(
                                        color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                                const SizedBox(height: 2),
                                Text(
                                  '${cashierNames[e.cashierId] ?? 'Cajero'} · ${dateFmt.format(e.createdAt.toLocal())}',
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                ),
                                if (e.description.isNotEmpty)
                                  Text(e.description,
                                      style: const TextStyle(color: AppColors.textDisabled, fontSize: 11)),
                              ],
                            ),
                          ),
                          Text(currencyFmt.format(e.amount),
                              style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDateRange(BuildContext context, ExpensesReportNotifier notifier, ExpensesReportState state) async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDateRange: state.filterDateFrom != null
          ? DateTimeRange(start: state.filterDateFrom!, end: state.filterDateTo ?? now)
          : null,
    );
    if (range == null) return;
    await notifier.filterByDateRange(range.start, DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59));
  }

  Future<void> _exportCsv(List<Expense> expenses, Map<String, String> cashierNames) async {
    final dateFmt = DateFormat('yyyy-MM-dd HH:mm');
    final rows = <List<dynamic>>[
      ['fecha', 'cajero', 'categoria', 'monto', 'descripcion'],
      for (final e in expenses)
        [
          dateFmt.format(e.createdAt.toLocal()),
          cashierNames[e.cashierId] ?? e.cashierId,
          e.categoryName,
          e.amount,
          e.description,
        ],
    ];
    final csv = const ListToCsvConverter().convert(rows);
    final bytes = utf8.encode(csv);
    final xFile = XFile.fromData(bytes,
        name: 'gastos_${DateTime.now().millisecondsSinceEpoch}.csv', mimeType: 'text/csv');
    await Share.shareXFiles([xFile], text: 'Reporte de gastos de caja');
  }
}

class _TotalCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _TotalCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 17)),
        ],
      ),
    );
  }
}
