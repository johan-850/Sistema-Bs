// ============================================================
// lib/features/dashboard/presentation/pages/admin_cash_registers_page.dart
// Historial de aperturas de caja para el AdminMaster — US-011
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/hover_ink_well.dart';
import '../../../../core/theme/breakpoints.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/adaptive_sheet.dart';
import '../../../../core/widgets/app_page_bar.dart';
import '../../../../core/widgets/data_table_view.dart';
import '../../../../core/widgets/filter_dropdown.dart';
import '../../../cash_register/domain/entities/cash_register.dart';
import '../../../cash_register/presentation/providers/cash_register_providers.dart';
import '../../../users/presentation/providers/users_providers.dart';

class AdminCashRegistersPage extends ConsumerStatefulWidget {
  const AdminCashRegistersPage({super.key});

  @override
  ConsumerState<AdminCashRegistersPage> createState() =>
      _AdminCashRegistersPageState();
}

class _AdminCashRegistersPageState
    extends ConsumerState<AdminCashRegistersPage> {
  final _currencyFmt = NumberFormat('#,###', 'es_CO');
  final _dateFmt     = DateFormat('dd MMM', 'es');
  final _timeFmt     = DateFormat('hh:mm a', 'es');
  final _fullDateFmt = DateFormat('dd/MM/yyyy HH:mm', 'es');

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(registerHistoryProvider);
    final notifier = ref.read(registerHistoryProvider.notifier);

    final compact = context.isCompact;
    return Scaffold(
      appBar: AppPageBar(
        title: 'Historial de cajas',
        actions: [
          // En escritorio los filtros están a la vista sobre la tabla.
          if (compact)
            PageAction(
              icon: Icons.filter_list_rounded,
              label: 'Filtrar',
              highlighted: state.hasActiveFilters,
              onPressed: () => _showFilterSheet(context, notifier),
            ),
        ],
      ),
      body: compact ? _compactBody(state, notifier) : _desktopBody(state, notifier),
    );
  }

  /// USB-024: tabla de turnos con el cuadre de cada uno a la vista; el
  /// detalle completo (denominaciones, notas) abre en un diálogo.
  Widget _desktopBody(RegisterHistoryState state, RegisterHistoryNotifier notifier) {
    final cashiers = ref.watch(cashierListProvider).cashiers;
    final money = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    final dayFmt = DateFormat('dd/MM/yyyy', 'es');
    final hourFmt = DateFormat('h:mm a', 'es');

    Widget amount(double? value, {Color? color, FontWeight? weight}) => Text(
          value == null ? '—' : money.format(value),
          style: TextStyle(
            fontSize: 13,
            color: value == null ? AppColors.textDisabled : color,
            fontWeight: weight,
          ),
        );

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
              FilterDropdown<String?>(
                label: 'Cajero',
                value: state.filterCashierId,
                items: [
                  const DropdownMenuItem(value: null, child: Text('Todos los cajeros')),
                  ...cashiers.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                ],
                onChanged: (v) => notifier.setFilters(
                    cashierId: v, from: state.filterFrom, to: state.filterTo),
              ),
              SizedBox(
                width: 240,
                child: _DatePickerTile(
                  label: 'Desde',
                  value: state.filterFrom,
                  onPicked: (d) => notifier.setFilters(
                      cashierId: state.filterCashierId, from: d, to: state.filterTo),
                ),
              ),
              SizedBox(
                width: 240,
                child: _DatePickerTile(
                  label: 'Hasta',
                  value: state.filterTo,
                  onPicked: (d) => notifier.setFilters(
                      cashierId: state.filterCashierId, from: state.filterFrom, to: d),
                ),
              ),
              if (state.hasActiveFilters)
                TextButton.icon(
                  onPressed: notifier.clearFilters,
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  label: const Text('Limpiar'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: DataTableView<CashRegister, Object>(
              columns: const [
                TableColumn('Turno', flex: 3),
                TableColumn('Cajero', flex: 2),
                TableColumn('Estado', width: 112),
                TableColumn('Base', flex: 2, numeric: true),
                TableColumn('Ventas', flex: 2, numeric: true),
                TableColumn('Esperado', flex: 2, numeric: true),
                TableColumn('Contado', flex: 2, numeric: true),
                TableColumn('Diferencia', flex: 2, numeric: true),
              ],
              rows: state.registers,
              loading: state.isLoading,
              rowAccent: _accentFor,
              onRowTap: (r) => _showDetailSheet(context, r),
              cells: (r) {
                final local = r.openingTime.toLocal();
                final summary = r.closingSummary;
                return [
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(text: dayFmt.format(local)),
                      TextSpan(
                        text: '\n${hourFmt.format(local)}'
                            '${r.closingTime != null ? ' – ${hourFmt.format(r.closingTime!.toLocal())}' : ''}',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ]),
                    style: const TextStyle(fontSize: 13),
                  ),
                  Text(r.cashierName ?? 'Cajero',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13)),
                  _StatusBadge(register: r),
                  amount(r.openingAmount),
                  amount(summary?.salesTotal),
                  amount(summary?.expectedCash),
                  amount(summary?.countedCash),
                  summary == null
                      ? amount(null)
                      : amount(
                          summary.difference,
                          color: _differenceColor(summary.difference),
                          weight: FontWeight.w700,
                        ),
                ];
              },
              empty: state.isLoading ? null : _EmptyState(onRefresh: () => notifier.load()),
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

  Color? _accentFor(CashRegister r) {
    if (r.isOpen) return AppColors.primary;
    if (r.isClosing) return AppColors.stockNearVivid;
    final summary = r.closingSummary;
    return summary == null ? null : _differenceColor(summary.difference);
  }

  Widget _compactBody(RegisterHistoryState state, RegisterHistoryNotifier notifier) {
    return Column(
      children: [
        Expanded(child: _compactList(state, notifier)),
        if (state.currentPage > 0 || state.hasNextPage)
          TablePager(
            page: state.currentPage,
            hasNext: state.hasNextPage,
            onPrevious: notifier.previousPage,
            onNext: notifier.nextPage,
          ),
      ],
    );
  }

  Widget _compactList(RegisterHistoryState state, RegisterHistoryNotifier notifier) {
    return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => notifier.load(),
        child: state.isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : state.registers.isEmpty
                ? _EmptyState(onRefresh: () => notifier.load())
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: state.registers.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _RegisterCard(
                      register: state.registers[i],
                      currencyFmt: _currencyFmt,
                      dateFmt: _dateFmt,
                      timeFmt: _timeFmt,
                      onTap: () => _showDetailSheet(context, state.registers[i]),
                    ),
                  ),
    );
  }

  // ── Filter bottom sheet ────────────────────────────────────

  void _showFilterSheet(
      BuildContext context, RegisterHistoryNotifier notifier) {
    DateTime? from;
    DateTime? to;
    String? cashierId;
    final cashiers = ref.read(cashierListProvider).cashiers;

    showAdaptiveSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filtrar historial',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 20),

              // Cajero (US-045)
              FilterDropdown<String?>(
                label: 'Cajero',
                value: cashierId,
                items: [
                  const DropdownMenuItem(value: null, child: Text('Todos')),
                  ...cashiers.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                ],
                onChanged: (v) => setModal(() => cashierId = v),
              ),
              const SizedBox(height: 12),

              // Fecha desde
              _DatePickerTile(
                label: 'Desde',
                value: from,
                onPicked: (d) => setModal(() => from = d),
              ),
              const SizedBox(height: 12),

              // Fecha hasta
              _DatePickerTile(
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
                        notifier.clearFilters();
                      },
                      child: const Text('Limpiar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        notifier.applyFilters(from: from, to: to, cashierId: cashierId);
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

  // ── Detail bottom sheet (US-011 — detalle de denominaciones) ─

  void _showDetailSheet(BuildContext context, CashRegister register) {
    Widget detail(ScrollController? scrollCtrl) => _RegisterDetailSheet(
          register: register,
          currencyFmt: _currencyFmt,
          fullDateFmt: _fullDateFmt,
          scrollController: scrollCtrl,
        );

    showAdaptiveSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => ctx.isCompact
          ? DraggableScrollableSheet(
              initialChildSize: 0.65,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              expand: false,
              builder: (_, scrollCtrl) => detail(scrollCtrl),
            )
          : detail(null),
    );
  }
}

/// US-045: verde si el cuadre es exacto, amarillo hasta 5.000 de
/// diferencia, rojo por encima. Mismo criterio en la tarjeta y la tabla.
Color _differenceColor(double difference) {
  if (difference == 0) return AppColors.success;
  return difference.abs() <= 5000 ? AppColors.stockNearVivid : AppColors.stockCriticalVivid;
}

class _StatusBadge extends StatelessWidget {
  final CashRegister register;
  const _StatusBadge({required this.register});

  @override
  Widget build(BuildContext context) {
    final (label, color) = register.isOpen
        ? ('Abierta', AppColors.success)
        : register.isClosing
            ? ('Cerrando', AppColors.stockNearVivid)
            : ('Cerrada', AppColors.textSecondary);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: register.isClosed ? AppColors.surfaceElevated : color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 11),
      ),
    );
  }
}

// ── Tarjeta de apertura en lista ──────────────────────────────

class _RegisterCard extends StatelessWidget {
  final CashRegister register;
  final NumberFormat currencyFmt;
  final DateFormat dateFmt;
  final DateFormat timeFmt;
  final VoidCallback onTap;

  const _RegisterCard({
    required this.register,
    required this.currencyFmt,
    required this.dateFmt,
    required this.timeFmt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final local = register.openingTime.toLocal();
    final isOpen = register.isOpen;
    final isClosing = register.isClosing;

    return HoverInkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isOpen
                ? AppColors.primary.withValues(alpha: 0.4)
                : isClosing
                    ? AppColors.stockNearVivid.withValues(alpha: 0.5)
                    : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            // ── Fecha ─────────────────────────────────────────
            Column(
              children: [
                Text(
                  dateFmt.format(local).toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                Text(
                  timeFmt.format(local),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            const VerticalDivider(width: 1, color: AppColors.border),
            const SizedBox(width: 16),

            // ── Info cajero + monto ────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    register.cashierName ?? 'Cajero',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\$${currencyFmt.format(register.openingAmount)}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),

            // ── Badge estado (Abierta / Cerrando / Cerrada) ────
            _StatusBadge(register: register),
            // US-045: punto ok/alerta según la diferencia del cuadre.
            if (register.isClosed && register.closingSummary != null) ...[
              const SizedBox(width: 8),
              Tooltip(
                message: register.closingSummary!.difference == 0
                    ? 'Cuadre exacto'
                    : 'Diferencia: ${NumberFormat('#,###', 'es_CO').format(register.closingSummary!.difference.abs())}',
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _differenceColor(register.closingSummary!.difference),
                  ),
                ),
              ),
            ],
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textDisabled, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Detalle de apertura (bottom sheet) ────────────────────────

class _RegisterDetailSheet extends StatelessWidget {
  final CashRegister register;
  final NumberFormat currencyFmt;
  final DateFormat fullDateFmt;
  /// Null en el diálogo de escritorio: sin hoja arrastrable que lo controle.
  final ScrollController? scrollController;

  const _RegisterDetailSheet({
    required this.register,
    required this.currencyFmt,
    required this.fullDateFmt,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final coinEntries = register.openingBreakdown.entries
        .where((e) => e.key.startsWith('coin_') && e.value > 0)
        .toList();
    final billEntries = register.openingBreakdown.entries
        .where((e) => e.key.startsWith('bill_') && e.value > 0)
        .toList();

    final draggable = scrollController != null;

    return ListView(
      controller: scrollController,
      shrinkWrap: !draggable,
      padding: EdgeInsets.fromLTRB(24, draggable ? 8 : 24, 24, 24),
      children: [
        if (draggable)
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

        // Cajero + timestamp (US-012)
        Text(
          register.cashierName ?? 'Cajero',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Abierta el ${fullDateFmt.format(register.openingTime.toLocal())}',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 20),

        // Total
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              AppColors.primary.withValues(alpha: 0.15),
              AppColors.secondary.withValues(alpha: 0.08),
            ]),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total apertura',
                  style: TextStyle(color: AppColors.textSecondary)),
              Text(
                '\$${currencyFmt.format(register.openingAmount)}',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Desglose
        if (coinEntries.isNotEmpty) ...[
          const _SheetSectionLabel('Monedas'),
          const SizedBox(height: 8),
          ...coinEntries.map((e) => _DenomRow(
                denomKey: e.key,
                quantity: e.value,
                currencyFmt: currencyFmt,
                isCoin: true,
              )),
          const SizedBox(height: 12),
        ],
        if (billEntries.isNotEmpty) ...[
          const _SheetSectionLabel('Billetes'),
          const SizedBox(height: 8),
          ...billEntries.map((e) => _DenomRow(
                denomKey: e.key,
                quantity: e.value,
                currencyFmt: currencyFmt,
                isCoin: false,
              )),
        ],

        // Notas
        if (register.notes != null && register.notes!.isNotEmpty) ...[
          const SizedBox(height: 16),
          const _SheetSectionLabel('Notas del cajero'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              register.notes!,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 14, height: 1.5),
            ),
          ),
        ],

        // ── Cuadre de cierre (US-042) ────────────────────────
        if (register.isClosed && register.closingSummary != null) ...[
          const SizedBox(height: 20),
          const Divider(color: AppColors.border),
          const SizedBox(height: 12),
          const _SheetSectionLabel('Cuadre de cierre'),
          const SizedBox(height: 8),
          _CuadreRow(label: 'Ventas efectivo', value: register.closingSummary!.salesEfectivo, currencyFmt: currencyFmt),
          _CuadreRow(label: 'Ventas mixto (efectivo)', value: register.closingSummary!.salesMixtoEfectivo, currencyFmt: currencyFmt),
          _CuadreRow(label: 'Ventas transferencia', value: register.closingSummary!.salesTransferencia, currencyFmt: currencyFmt),
          _CuadreRow(label: 'Total ventas', value: register.closingSummary!.salesTotal, currencyFmt: currencyFmt, emphasize: true),
          _CuadreRow(label: 'Transacciones', value: register.closingSummary!.transactionCount.toDouble(), currencyFmt: currencyFmt, isCount: true),
          _CuadreRow(label: 'Gastos', value: register.closingSummary!.totalExpenses, currencyFmt: currencyFmt),
          const SizedBox(height: 8),
          _CuadreRow(label: 'Efectivo esperado', value: register.closingSummary!.expectedCash, currencyFmt: currencyFmt, emphasize: true),
          _CuadreRow(label: 'Efectivo contado', value: register.closingSummary!.countedCash, currencyFmt: currencyFmt, emphasize: true),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Diferencia',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w700)),
                Text(
                  '\$${currencyFmt.format(register.closingSummary!.difference)}',
                  style: TextStyle(
                    color: register.closingSummary!.difference == 0
                        ? AppColors.success
                        : (register.closingSummary!.difference.abs() <= 5000
                            ? AppColors.stockNearVivid
                            : AppColors.stockCriticalVivid),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          if (register.closingNotes != null && register.closingNotes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                register.closingNotes!,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, height: 1.5),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _CuadreRow extends StatelessWidget {
  final String label;
  final double value;
  final NumberFormat currencyFmt;
  final bool emphasize;
  final bool isCount;

  const _CuadreRow({
    required this.label,
    required this.value,
    required this.currencyFmt,
    this.emphasize = false,
    this.isCount = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: emphasize ? FontWeight.w600 : FontWeight.normal)),
          Text(
            isCount ? value.toInt().toString() : '\$${currencyFmt.format(value)}',
            style: TextStyle(
              color: emphasize ? AppColors.textPrimary : AppColors.textSecondary,
              fontSize: emphasize ? 14 : 13,
              fontWeight: emphasize ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Subwidgets utilitarios ────────────────────────────────────

class _DenomRow extends StatelessWidget {
  final String denomKey;
  final int quantity;
  final NumberFormat currencyFmt;
  final bool isCoin;

  const _DenomRow({
    required this.denomKey,
    required this.quantity,
    required this.currencyFmt,
    required this.isCoin,
  });

  @override
  Widget build(BuildContext context) {
    final denomVal = AppConstants.coinDenominations[denomKey] ??
        AppConstants.billDenominations[denomKey] ??
        0;
    final subtotal = denomVal * quantity;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(
            isCoin ? Icons.toll_rounded : Icons.payments_rounded,
            size: 15,
            color: AppColors.primary,
          ),
          const SizedBox(width: 10),
          Text(
            '\$${currencyFmt.format(denomVal)}  ×  $quantity',
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          ),
          const Spacer(),
          Text(
            '\$${currencyFmt.format(subtotal)}',
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _SheetSectionLabel extends StatelessWidget {
  final String label;
  const _SheetSectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _DatePickerTile extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onPicked;

  const _DatePickerTile({
    required this.label,
    required this.value,
    required this.onPicked,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');
    return HoverInkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2024),
          lastDate: DateTime.now(),
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: const ColorScheme.dark(
                primary: AppColors.primary,
                surface: AppColors.surfaceCard,
              ),
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
            const Icon(Icons.calendar_today_rounded,
                size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 10),
            Text(
              '$label: ${value != null ? fmt.format(value!) : 'Cualquier fecha'}',
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            ),
            const Spacer(),
            if (value != null)
              const Icon(Icons.check_circle_rounded,
                  size: 16, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onRefresh;
  const _EmptyState({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.point_of_sale_outlined,
              size: 56, color: AppColors.textDisabled),
          const SizedBox(height: 16),
          const Text(
            'Sin aperturas registradas',
            style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Las aperturas de caja aparecerán aquí.',
            style: TextStyle(color: AppColors.textDisabled, fontSize: 13),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Actualizar'),
          ),
        ],
      ),
    );
  }
}
