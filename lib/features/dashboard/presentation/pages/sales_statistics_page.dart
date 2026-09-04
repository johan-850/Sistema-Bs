// ============================================================
// lib/features/dashboard/presentation/pages/sales_statistics_page.dart
// EP-09 (S-10): Estadísticas y tendencias de ventas — US-050/051/052
// ============================================================

import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../pos/domain/repositories/sale_repository.dart';
import '../../../pos/presentation/providers/statistics_providers.dart';

const _kCategoryPalette = [
  AppColors.primary,
  AppColors.secondary,
  AppColors.accent,
  AppColors.info,
  AppColors.success,
  AppColors.warning,
  AppColors.stockNearVivid,
  AppColors.error,
  AppColors.stockCriticalVivid,
  AppColors.primaryLight,
  AppColors.stockOk,
  AppColors.stockWarning,
  AppColors.textSecondary,
];

class SalesStatisticsPage extends ConsumerWidget {
  const SalesStatisticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(statsPeriodProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Estadísticas')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<StatsPeriod>(
            segments: StatsPeriod.values
                .map((p) => ButtonSegment(value: p, label: Text(p.label)))
                .toList(),
            selected: {period},
            onSelectionChanged: (s) => ref.read(statsPeriodProvider.notifier).state = s.first,
          ),
          const SizedBox(height: 20),
          const _TopProductsSection(),
          const SizedBox(height: 20),
          const _SalesTrendSection(),
          const SizedBox(height: 20),
          const _CategoryBreakdownSection(),
          const SizedBox(height: 20),
          const _CashierPerformanceSection(),
        ],
      ),
    );
  }
}

// ── Contenedor visual compartido por las 3 secciones ─────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> actions;
  final Widget child;
  const _SectionCard({required this.title, this.actions = const [], required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
              if (actions.isNotEmpty) Row(children: actions),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

Widget _loadingBox() => const Padding(
      padding: EdgeInsets.all(24),
      child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
    );

Widget _emptyBox(String message) => Padding(
      padding: const EdgeInsets.all(16),
      child: Text(message, style: const TextStyle(color: AppColors.textSecondary)),
    );

Widget _errorBox() => _emptyBox('No se pudo cargar la información.');

// ── US-050: productos más vendidos ────────────────────────────────

class _TopProductsSection extends ConsumerStatefulWidget {
  const _TopProductsSection();

  @override
  ConsumerState<_TopProductsSection> createState() => _TopProductsSectionState();
}

class _TopProductsSectionState extends ConsumerState<_TopProductsSection> {
  bool _sortByAmount = false;

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(topProductsProvider(null));
    final currencyFmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

    return _SectionCard(
      title: 'Productos más vendidos',
      actions: [
        IconButton(
          tooltip: 'Exportar CSV',
          icon: const Icon(Icons.ios_share_rounded, size: 20),
          onPressed: (productsAsync.valueOrNull ?? const []).isEmpty
              ? null
              : () => _exportCsv(productsAsync.value!),
        ),
      ],
      child: productsAsync.when(
        loading: _loadingBox,
        error: (_, _) => _errorBox(),
        data: (products) {
          if (products.isEmpty) return _emptyBox('Sin ventas en el período seleccionado.');

          final sorted = [...products]
            ..sort((a, b) => _sortByAmount
                ? b.amountTotal.compareTo(a.amountTotal)
                : b.unitsSold.compareTo(a.unitsSold));
          final maxY = (_sortByAmount ? sorted.first.amountTotal : sorted.first.unitsSold.toDouble());

          return Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Unidades')),
                  ButtonSegment(value: true, label: Text('Monto')),
                ],
                selected: {_sortByAmount},
                onSelectionChanged: (s) => setState(() => _sortByAmount = s.first),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 260,
                width: double.infinity,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxY <= 0 ? 1 : maxY * 1.2,
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final p = sorted[group.x.toInt()];
                          return BarTooltipItem(
                            '${p.productName}\n${p.unitsSold} u. · ${currencyFmt.format(p.amountTotal)}',
                            const TextStyle(color: AppColors.textPrimary, fontSize: 11),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 64,
                          getTitlesWidget: (value, meta) {
                            final i = value.toInt();
                            if (i < 0 || i >= sorted.length) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Transform.rotate(
                                angle: -0.6,
                                child: SizedBox(
                                  width: 70,
                                  child: Text(
                                    sorted[i].productName,
                                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 9),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    barGroups: [
                      for (var i = 0; i < sorted.length; i++)
                        BarChartGroupData(x: i, barRods: [
                          BarChartRodData(
                            toY: _sortByAmount ? sorted[i].amountTotal : sorted[i].unitsSold.toDouble(),
                            color: AppColors.primary,
                            width: 16,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ]),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _exportCsv(List<TopProduct> products) async {
    final rows = <List<dynamic>>[
      ['producto', 'unidades_vendidas', 'monto_total'],
      for (final p in products) [p.productName, p.unitsSold, p.amountTotal],
    ];
    final csv = const ListToCsvConverter().convert(rows);
    final bytes = utf8.encode(csv);
    final xFile = XFile.fromData(bytes,
        name: 'top_productos_${DateTime.now().millisecondsSinceEpoch}.csv', mimeType: 'text/csv');
    await Share.shareXFiles([xFile], text: 'Ranking de productos más vendidos');
  }
}

// ── US-051: tendencia de ventas ───────────────────────────────────

class _SalesTrendSection extends ConsumerWidget {
  const _SalesTrendSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendAsync = ref.watch(salesTrendProvider);
    final currencyFmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    final dateFmt = DateFormat('dd/MM');

    return _SectionCard(
      title: 'Tendencia de ventas',
      child: trendAsync.when(
        loading: _loadingBox,
        error: (_, _) => _errorBox(),
        data: (trend) {
          if (trend.current.isEmpty) return _emptyBox('Sin ventas en el período seleccionado.');

          final maxLen =
              trend.current.length > trend.previous.length ? trend.current.length : trend.previous.length;
          final maxTotal = [
            for (final d in trend.current) d.total,
            for (final d in trend.previous) d.total,
          ].fold<double>(0, (m, v) => v > m ? v : m);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  _LegendDot(color: AppColors.primary, label: 'Actual'),
                  SizedBox(width: 12),
                  _LegendDot(color: AppColors.textDisabled, label: 'Período anterior'),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 220,
                width: double.infinity,
                child: LineChart(
                  LineChartData(
                    minY: 0,
                    maxY: maxTotal <= 0 ? 1 : maxTotal * 1.2,
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 26,
                          interval: (maxLen / 5).clamp(1, maxLen).toDouble(),
                          getTitlesWidget: (value, meta) {
                            final i = value.toInt();
                            if (i < 0 || i >= trend.current.length) return const SizedBox.shrink();
                            return Text(dateFmt.format(trend.current[i].day),
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 9));
                          },
                        ),
                      ),
                    ),
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipItems: (spots) => spots.map((s) {
                          final series = s.barIndex == 0 ? trend.current : trend.previous;
                          final i = s.x.toInt();
                          final day = i >= 0 && i < series.length ? dateFmt.format(series[i].day) : '';
                          return LineTooltipItem(
                            '$day\n${currencyFmt.format(s.y)}',
                            const TextStyle(color: AppColors.textPrimary, fontSize: 11),
                          );
                        }).toList(),
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: [
                          for (var i = 0; i < trend.current.length; i++)
                            FlSpot(i.toDouble(), trend.current[i].total),
                        ],
                        isCurved: true,
                        color: AppColors.primary,
                        barWidth: 2.5,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, bar, index) {
                            final isPeak =
                                trend.peakDay != null && trend.current[index].day == trend.peakDay;
                            return FlDotCirclePainter(
                              radius: isPeak ? 5 : 0,
                              color: AppColors.accent,
                              strokeColor: AppColors.accent,
                            );
                          },
                        ),
                        belowBarData:
                            BarAreaData(show: true, color: AppColors.primary.withValues(alpha: 0.1)),
                      ),
                      LineChartBarData(
                        spots: [
                          for (var i = 0; i < trend.previous.length; i++)
                            FlSpot(i.toDouble(), trend.previous[i].total),
                        ],
                        isCurved: true,
                        color: AppColors.textDisabled,
                        barWidth: 2,
                        dotData: const FlDotData(show: false),
                        dashArray: const [6, 4],
                      ),
                    ],
                  ),
                ),
              ),
              if (trend.peakDay != null) ...[
                const SizedBox(height: 8),
                Text('Día pico: ${DateFormat('dd/MM/yyyy').format(trend.peakDay!)}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        ],
      );
}

// ── US-052: categorías más rentables ──────────────────────────────

class _CategoryBreakdownSection extends ConsumerWidget {
  const _CategoryBreakdownSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoryBreakdownProvider);
    final currencyFmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

    return _SectionCard(
      title: 'Categorías más rentables',
      child: categoriesAsync.when(
        loading: _loadingBox,
        error: (_, _) => _errorBox(),
        data: (categories) {
          if (categories.isEmpty) return _emptyBox('Sin ventas en el período seleccionado.');

          final maxMargin = categories.map((c) => c.estimatedMargin).fold<double>(0, (m, v) => v > m ? v : m);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 240,
                width: double.infinity,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxMargin <= 0 ? 1 : maxMargin * 1.2,
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    barTouchData: BarTouchData(
                      touchCallback: (event, response) {
                        if (event is! FlTapUpEvent) return;
                        final index = response?.spot?.touchedBarGroupIndex;
                        if (index == null || index < 0 || index >= categories.length) return;
                        _showDrillDown(context, categories[index].category);
                      },
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final c = categories[group.x.toInt()];
                          return BarTooltipItem(
                            '${c.category}\n${currencyFmt.format(c.estimatedMargin)} margen\n'
                            '${c.unitsSold} u. · ${currencyFmt.format(c.amountTotal)}',
                            const TextStyle(color: AppColors.textPrimary, fontSize: 11),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 70,
                          getTitlesWidget: (value, meta) {
                            final i = value.toInt();
                            if (i < 0 || i >= categories.length) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Transform.rotate(
                                angle: -0.6,
                                child: SizedBox(
                                  width: 70,
                                  child: Text(
                                    categories[i].category,
                                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 9),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    barGroups: [
                      for (var i = 0; i < categories.length; i++)
                        BarChartGroupData(x: i, barRods: [
                          BarChartRodData(
                            toY: categories[i].estimatedMargin,
                            color: _kCategoryPalette[i % _kCategoryPalette.length],
                            width: 20,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ]),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text('Toca una barra para ver sus productos.',
                  style: TextStyle(color: AppColors.textDisabled, fontSize: 11)),
            ],
          );
        },
      ),
    );
  }

  void _showDrillDown(BuildContext context, String category) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _CategoryDrillDownSheet(category: category),
    );
  }
}

class _CategoryDrillDownSheet extends ConsumerWidget {
  final String category;
  const _CategoryDrillDownSheet({required this.category});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(topProductsProvider(category));
    final currencyFmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(category,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            const Text('Productos vendidos en el período seleccionado',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 12),
            Flexible(
              child: productsAsync.when(
                loading: _loadingBox,
                error: (_, _) => _errorBox(),
                data: (products) {
                  if (products.isEmpty) return _emptyBox('Sin productos vendidos en esta categoría.');
                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: products.length,
                    separatorBuilder: (_, _) => const Divider(color: AppColors.border, height: 16),
                    itemBuilder: (_, i) {
                      final p = products[i];
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(p.productName,
                                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13))),
                          Text('${p.unitsSold} u. · ${currencyFmt.format(p.amountTotal)}',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── US-053: desempeño por cajero ──────────────────────────────────

class _CashierPerformanceSection extends ConsumerWidget {
  const _CashierPerformanceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cashiersAsync = ref.watch(cashierPerformanceProvider);
    final currencyFmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

    return _SectionCard(
      title: 'Desempeño por cajero',
      child: cashiersAsync.when(
        loading: _loadingBox,
        error: (_, _) => _errorBox(),
        data: (cashiers) {
          if (cashiers.isEmpty) return _emptyBox('Sin ventas en el período seleccionado.');

          return Column(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(flex: 2, child: Text('Cajero',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600))),
                    Expanded(child: Text('Ventas', textAlign: TextAlign.right,
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600))),
                    Expanded(child: Text('# Trans.', textAlign: TextAlign.right,
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600))),
                    Expanded(child: Text('Ticket prom.', textAlign: TextAlign.right,
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600))),
                  ],
                ),
              ),
              const Divider(color: AppColors.border, height: 16),
              ...cashiers.map((c) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(c.cashierName,
                              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        Expanded(
                          child: Text(currencyFmt.format(c.totalSales), textAlign: TextAlign.right,
                              style: const TextStyle(
                                  color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 12)),
                        ),
                        Expanded(
                          child: Text('${c.transactionCount}', textAlign: TextAlign.right,
                              style: const TextStyle(color: AppColors.textPrimary, fontSize: 12)),
                        ),
                        Expanded(
                          child: Text(currencyFmt.format(c.avgTicket), textAlign: TextAlign.right,
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        ),
                      ],
                    ),
                  )),
            ],
          );
        },
      ),
    );
  }
}
