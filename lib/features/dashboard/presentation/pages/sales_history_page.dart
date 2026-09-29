// ============================================================
// lib/features/dashboard/presentation/pages/sales_history_page.dart
// US-044: historial de ventas con filtros (AdminMaster)
// US-046: exportar a CSV/PDF
// ============================================================

import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/breakpoints.dart';
import '../../../../core/widgets/app_page_bar.dart';
import '../../../../core/widgets/data_table_view.dart';
import '../../../../core/widgets/hover_ink_well.dart';
import '../../../../core/utils/receipt_pdf.dart';
import '../../../../core/widgets/filter_dropdown.dart';
import '../../../pos/domain/entities/sale.dart';
import '../../../pos/domain/repositories/sale_repository.dart' show SaleSort;
import '../../../pos/presentation/providers/sales_history_providers.dart';
import '../../../users/domain/entities/cashier.dart';
import '../../../users/presentation/providers/users_providers.dart';

class SalesHistoryPage extends ConsumerStatefulWidget {
  const SalesHistoryPage({super.key});

  @override
  ConsumerState<SalesHistoryPage> createState() => _SalesHistoryPageState();
}

class _SalesHistoryPageState extends ConsumerState<SalesHistoryPage> {
  final _searchCtrl = TextEditingController();
  final _minCtrl = TextEditingController();
  final _maxCtrl = TextEditingController();
  String? _draftCashierId;
  String? _draftPaymentMethod;
  DateTime? _draftDateFrom;
  DateTime? _draftDateTo;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(salesHistoryProvider);
    final notifier = ref.read(salesHistoryProvider.notifier);
    final cashiers = ref.watch(cashierListProvider).cashiers;
    final cashierNames = {for (final c in cashiers) c.id: c.name};
    final currencyFmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    final dateFmt = DateFormat('dd/MM/yyyy hh:mm a', 'es');

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppPageBar(
        title: 'Historial de ventas',
        actions: [
          PageAction(
            icon: Icons.ios_share_rounded,
            label: 'Exportar CSV',
            onPressed: state.sales.isEmpty ? null : () => _exportCsv(state.sales, cashierNames),
          ),
          PageAction(
            icon: Icons.picture_as_pdf_outlined,
            label: 'Exportar PDF',
            onPressed: state.sales.isEmpty ? null : () => _exportPdf(state.sales, cashierNames, currencyFmt),
          ),
        ],
      ),
      body: context.isCompact
          ? _compactBody(state, notifier, cashiers, cashierNames, currencyFmt, dateFmt)
          : _desktopBody(state, notifier, cashiers, cashierNames, currencyFmt),
    );
  }

  void _clearAll(SalesHistoryNotifier notifier) {
    setState(() {
      _draftCashierId = null;
      _draftPaymentMethod = null;
      _draftDateFrom = null;
      _draftDateTo = null;
      _minCtrl.clear();
      _maxCtrl.clear();
      _searchCtrl.clear();
    });
    notifier.clearFilters();
  }

  void _openSale(Sale sale) => context.push('/admin/sales-history/${sale.id}');

  /// USB-025: filtros siempre a la vista sobre una tabla con orden por
  /// columna y paginación.
  Widget _desktopBody(
    SalesHistoryState state,
    SalesHistoryNotifier notifier,
    List<Cashier> cashiers,
    Map<String, String> cashierNames,
    NumberFormat currencyFmt,
  ) {
    final dayFmt = DateFormat('dd/MM/yyyy', 'es');
    final hourFmt = DateFormat('h:mm a', 'es');
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'ID exacto de venta + Enter',
                    prefixIcon: Icon(Icons.search_rounded),
                    isDense: true,
                  ),
                  onSubmitted: (v) => notifier.searchById(v.trim().isEmpty ? null : v.trim()),
                ),
              ),
              // En escritorio cada filtro se aplica al cambiarlo (los montos,
              // con Enter): el botón "Aplicar" es un paso de más con mouse.
              FilterDropdown<String?>(
                label: 'Cajero',
                value: _draftCashierId,
                items: [
                  const DropdownMenuItem(value: null, child: Text('Todos los cajeros')),
                  ...cashiers.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                ],
                onChanged: (v) {
                  setState(() => _draftCashierId = v);
                  _applyFilters();
                },
              ),
              FilterDropdown<String?>(
                label: 'Método',
                value: _draftPaymentMethod,
                items: [
                  const DropdownMenuItem(value: null, child: Text('Todos los métodos')),
                  // Etiqueta corta: el desplegable mide lo que su opción más larga.
                  ...AppConstants.paymentMethods.map(
                    (m) => DropdownMenuItem(value: m, child: Text(m == 'mixto' ? 'Mixto' : paymentMethodLabel(m))),
                  ),
                ],
                onChanged: (v) {
                  setState(() => _draftPaymentMethod = v);
                  _applyFilters();
                },
              ),
              OutlinedButton.icon(
                onPressed: () => _pickDateRange(context, applyNow: true),
                icon: const Icon(Icons.date_range_outlined, size: 18),
                label: Text(
                  _draftDateFrom == null
                      ? 'Rango de fechas'
                      : '${DateFormat('dd/MM/yy').format(_draftDateFrom!)} - ${DateFormat('dd/MM/yy').format(_draftDateTo ?? DateTime.now())}',
                ),
              ),
              SizedBox(
                width: 130,
                child: TextField(
                  controller: _minCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  decoration: const InputDecoration(labelText: 'Monto mín.', isDense: true),
                  onSubmitted: (_) => _applyFilters(),
                ),
              ),
              SizedBox(
                width: 130,
                child: TextField(
                  controller: _maxCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  decoration: const InputDecoration(labelText: 'Monto máx.', isDense: true),
                  onSubmitted: (_) => _applyFilters(),
                ),
              ),
              if (state.hasActiveFilters)
                TextButton.icon(
                  onPressed: () => _clearAll(notifier),
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  label: const Text('Limpiar'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: DataTableView<Sale, SaleSort>(
              columns: const [
                TableColumn('Fecha', flex: 2, sortKey: SaleSort.date),
                TableColumn('Cajero', flex: 2),
                TableColumn('Método', flex: 2, sortKey: SaleSort.paymentMethod),
                TableColumn('Productos', flex: 5),
                TableColumn('Total', flex: 2, numeric: true, sortKey: SaleSort.total),
              ],
              rows: state.sales,
              loading: state.isLoading,
              sortKey: state.sortBy,
              ascending: state.ascending,
              onSort: notifier.sort,
              onRowTap: _openSale,
              cells: (sale) {
                final local = sale.createdAt.toLocal();
                final cancelled = sale.status == 'cancelled';
                return [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: dayFmt.format(local)),
                        TextSpan(
                          text: '\n${hourFmt.format(local)}',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                  Text(
                    sale.cashierName ?? cashierNames[sale.cashierId] ?? 'Cajero',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                  Text(
                    // En la columna no cabe "Mixto (efectivo + transferencia)".
                    sale.paymentMethod == 'mixto' ? 'Mixto' : paymentMethodLabel(sale.paymentMethod),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  Text(
                    sale.itemsPreview.isEmpty ? '—' : sale.itemsPreview.join(', '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        currencyFmt.format(sale.total),
                        style: TextStyle(
                          color: cancelled ? AppColors.textDisabled : AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          decoration: cancelled ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      if (cancelled) const Text('Anulada', style: TextStyle(color: AppColors.error, fontSize: 11)),
                    ],
                  ),
                ];
              },
              empty: state.isLoading
                  ? null
                  : Center(
                      child: Text(
                        state.failure?.message ?? 'Sin ventas para los filtros seleccionados',
                        style: TextStyle(color: state.failure != null ? AppColors.error : AppColors.textSecondary),
                      ),
                    ),
              footer: TablePager(
                page: state.currentPage,
                hasNext: state.hasNextPage,
                onPrevious: notifier.previousPage,
                onNext: notifier.nextPage,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactBody(
    SalesHistoryState state,
    SalesHistoryNotifier notifier,
    List<Cashier> cashiers,
    Map<String, String> cashierNames,
    NumberFormat currencyFmt,
    DateFormat dateFmt,
  ) {
    return RefreshIndicator(
      onRefresh: () => notifier.load(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'Buscar por ID exacto de venta...',
                    prefixIcon: Icon(Icons.search_rounded),
                    isDense: true,
                  ),
                  onSubmitted: (v) => notifier.searchById(v.trim().isEmpty ? null : v.trim()),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Buscar',
                icon: const Icon(Icons.arrow_forward_rounded),
                onPressed: () {
                  final v = _searchCtrl.text.trim();
                  notifier.searchById(v.isEmpty ? null : v);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterDropdown<String?>(
                label: 'Cajero',
                value: _draftCashierId,
                items: [
                  const DropdownMenuItem(value: null, child: Text('Todos')),
                  ...cashiers.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                ],
                onChanged: (v) => setState(() => _draftCashierId = v),
              ),
              FilterDropdown<String?>(
                label: 'Método',
                value: _draftPaymentMethod,
                items: [
                  const DropdownMenuItem(value: null, child: Text('Todos')),
                  ...AppConstants.paymentMethods.map(
                    (m) => DropdownMenuItem(value: m, child: Text(paymentMethodLabel(m))),
                  ),
                ],
                onChanged: (v) => setState(() => _draftPaymentMethod = v),
              ),
              OutlinedButton.icon(
                onPressed: () => _pickDateRange(context),
                icon: const Icon(Icons.date_range_outlined, size: 18),
                label: Text(
                  _draftDateFrom == null
                      ? 'Rango de fechas'
                      : '${DateFormat('dd/MM/yy').format(_draftDateFrom!)} - ${DateFormat('dd/MM/yy').format(_draftDateTo ?? DateTime.now())}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _minCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  decoration: const InputDecoration(labelText: 'Monto mín.', isDense: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _maxCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  decoration: const InputDecoration(labelText: 'Monto máx.', isDense: true),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(onPressed: _applyFilters, child: const Text('Aplicar')),
            ],
          ),
          if (state.hasActiveFilters) ...[
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: () => _clearAll(notifier),
              icon: const Icon(Icons.clear_rounded, size: 18),
              label: const Text('Limpiar filtros'),
            ),
          ],
          const SizedBox(height: 16),
          const Divider(color: AppColors.border),
          const SizedBox(height: 8),
          if (state.isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          else if (state.failure != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(state.failure!.message, style: const TextStyle(color: AppColors.error)),
              ),
            )
          else if (state.sales.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Sin ventas para los filtros seleccionados',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            ...state.sales.map(
              (sale) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: HoverInkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _openSale(sale),
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
                              Text(
                                sale.itemsPreview.isNotEmpty
                                    ? sale.itemsPreview.join(', ')
                                    : paymentMethodLabel(sale.paymentMethod),
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${sale.cashierName ?? cashierNames[sale.cashierId] ?? 'Cajero'} · ${paymentMethodLabel(sale.paymentMethod)} · ${dateFmt.format(sale.createdAt.toLocal())}',
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '#${sale.id.substring(0, 8)}',
                                style: const TextStyle(color: AppColors.textDisabled, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          currencyFmt.format(sale.total),
                          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.chevron_right_rounded, color: AppColors.textDisabled, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (state.currentPage > 0 || state.hasNextPage)
            TablePager(
              page: state.currentPage,
              hasNext: state.hasNextPage,
              onPrevious: notifier.previousPage,
              onNext: notifier.nextPage,
            ),
        ],
      ),
    );
  }

  void _applyFilters() {
    final notifier = ref.read(salesHistoryProvider.notifier);
    _searchCtrl.clear();
    notifier.applyFilters(
      dateFrom: _draftDateFrom,
      dateTo: _draftDateTo,
      cashierId: _draftCashierId,
      paymentMethod: _draftPaymentMethod,
      minAmount: double.tryParse(_minCtrl.text),
      maxAmount: double.tryParse(_maxCtrl.text),
    );
  }

  Future<void> _pickDateRange(BuildContext context, {bool applyNow = false}) async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDateRange:
          _draftDateFrom != null ? DateTimeRange(start: _draftDateFrom!, end: _draftDateTo ?? now) : null,
    );
    if (range == null) return;
    setState(() {
      _draftDateFrom = range.start;
      _draftDateTo = DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59);
    });
    if (applyNow) _applyFilters();
  }

  Future<void> _exportCsv(List<Sale> sales, Map<String, String> cashierNames) async {
    final dateFmt = DateFormat('yyyy-MM-dd HH:mm');
    final rows = <List<dynamic>>[
      ['id', 'fecha', 'cajero', 'metodo_pago', 'total'],
      for (final s in sales)
        [
          s.id,
          dateFmt.format(s.createdAt.toLocal()),
          s.cashierName ?? cashierNames[s.cashierId] ?? s.cashierId ?? '',
          s.paymentMethod,
          s.total,
        ],
    ];
    final csv = const ListToCsvConverter().convert(rows);
    final bytes = utf8.encode(csv);
    final xFile =
        XFile.fromData(bytes, name: 'ventas_${DateTime.now().millisecondsSinceEpoch}.csv', mimeType: 'text/csv');
    await Share.shareXFiles([xFile], text: 'Historial de ventas');
  }

  Future<void> _exportPdf(List<Sale> sales, Map<String, String> cashierNames, NumberFormat currencyFmt) async {
    final dateFmt = DateFormat('dd/MM/yy HH:mm');
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(level: 0, child: pw.Text('Historial de ventas')),
          pw.TableHelper.fromTextArray(
            headers: ['Fecha', 'Cajero', 'Método', 'Total'],
            data: sales
                .map((s) => [
                      dateFmt.format(s.createdAt.toLocal()),
                      s.cashierName ?? cashierNames[s.cashierId] ?? '',
                      paymentMethodLabel(s.paymentMethod),
                      currencyFmt.format(s.total),
                    ])
                .toList(),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
    await Printing.sharePdf(bytes: await doc.save(), filename: 'ventas_${DateTime.now().millisecondsSinceEpoch}.pdf');
  }
}
