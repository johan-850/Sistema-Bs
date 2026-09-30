// ============================================================
// lib/features/dashboard/presentation/pages/sales_statistics_page.dart
// EP-09 (S-10): Estadísticas y tendencias de ventas — US-050/051/052
// USB-027: en escritorio, dos gráficas por fila y alto según pantalla.
// ============================================================

import 'dart:convert';
import 'dart:math' as math;

import 'package:csv/csv.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/breakpoints.dart';
import '../../../../core/widgets/app_page_bar.dart';
import '../../../../core/widgets/adaptive_sheet.dart';
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

final _money = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

/// Alto de cada fila de gráficas en ancho expandido: las dos filas entran
/// en la pantalla (encabezado, selector de período y márgenes aparte).
double statsRowHeight(double screenHeight) {
  const overhead = AppPageBar.height + 16 + 40 + 16 + 16 + 24;
  return ((screenHeight - overhead) / 2).clamp(280.0, 480.0);
}

/// Paso "redondo" (1, 2 o 5 × 10ⁿ) para unas [ticks] marcas hasta [maxValue].
double niceStep(double maxValue, {int ticks = 4}) {
  if (maxValue <= 0) return 1;
  final raw = maxValue / ticks;
  final magnitude = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  final residual = raw / magnitude;
  final nice = residual <= 1 ? 1.0 : (residual <= 2 ? 2.0 : (residual <= 5 ? 5.0 : 10.0));
  return nice * magnitude;
}

/// Tope del eje: múltiplo de [step] con un poco de aire sobre el máximo,
/// para que el punto más alto no quede pegado al borde.
double axisTop(double maxValue, double step) {
  var top = step * math.max(1, (maxValue / step).ceil());
  if (top < maxValue * 1.08) top += step;
  return top;
}

/// Montos del eje en corto: $450 mil, $1,5 M.
String axisMoney(double value) {
  if (value >= 1e6) {
    final m = value / 1e6;
    return '\$${m.toStringAsFixed(m == m.roundToDouble() ? 0 : 1).replaceAll('.', ',')} M';
  }
  if (value >= 1e3) return '\$${(value / 1e3).round()} mil';
  return '\$${value.round()}';
}

/// Cada cuántos días poner fecha en el eje; entero para que la fecha caiga
/// debajo de su punto (con 7/5 = 1,4 caían corridas).
int labelEvery(int count, {int maxLabels = 7}) => math.max(1, (count / maxLabels).ceil());

class SalesStatisticsPage extends ConsumerWidget {
  const SalesStatisticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(statsPeriodProvider);
    final compact = context.isCompact;

    final selector = SegmentedButton<StatsPeriod>(
      showSelectedIcon: false,
      segments: [
        for (final p in StatsPeriod.values)
          ButtonSegment(
            value: p,
            // En celular un tercio no alcanza para "Trimestre": se achica.
            label: FittedBox(fit: BoxFit.scaleDown, child: Text(p.label, softWrap: false)),
          ),
      ],
      selected: {period},
      onSelectionChanged: (s) => ref.read(statsPeriodProvider.notifier).state = s.first,
    );

    // Ancho fijo: con ancho libre, SegmentedButton mide mal sus textos en
    // web y los corta ("Trimestr").
    final deskSelector = Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(width: 390, child: selector),
    );

    final Widget body;
    if (context.isExpanded) {
      final rowHeight = statsRowHeight(MediaQuery.sizeOf(context).height);
      Widget row(Widget left, Widget right) => SizedBox(
        height: rowHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: left),
            const SizedBox(width: 16),
            Expanded(child: right),
          ],
        ),
      );
      body = ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        children: [
          deskSelector,
          const SizedBox(height: 16),
          row(const _SalesTrendSection(fill: true), const _TopProductsSection(fill: true)),
          const SizedBox(height: 16),
          row(const _CategoryBreakdownSection(fill: true), const _CashierPerformanceSection(fill: true)),
        ],
      );
    } else {
      // Mediano: una por fila pero con alto de monitor; compacto: alto propio.
      Widget sized(Widget section) => compact ? section : SizedBox(height: 380, child: section);
      final fill = !compact;
      body = ListView(
        padding: compact ? const EdgeInsets.all(16) : const EdgeInsets.fromLTRB(24, 16, 24, 24),
        children: [
          compact ? selector : deskSelector,
          const SizedBox(height: 20),
          sized(_SalesTrendSection(fill: fill)),
          const SizedBox(height: 20),
          sized(_TopProductsSection(fill: fill)),
          const SizedBox(height: 20),
          sized(_CategoryBreakdownSection(fill: fill)),
          const SizedBox(height: 20),
          sized(_CashierPerformanceSection(fill: fill)),
        ],
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const AppPageBar(title: 'Estadísticas'),
      body: body,
    );
  }
}

// ── Contenedor visual compartido por las secciones ───────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> actions;
  final Widget child;
  final Widget? footer;

  /// El padre fija el alto y el contenido ocupa lo que quede.
  final bool fill;

  const _SectionCard({
    required this.title,
    required this.child,
    required this.fill,
    this.actions = const [],
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 36,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
                ...actions,
              ],
            ),
          ),
          const SizedBox(height: 12),
          fill ? Expanded(child: child) : child,
          if (footer != null) ...[const SizedBox(height: 10), footer!],
        ],
      ),
    );
  }
}

/// En compacto la gráfica no hereda alto del padre: se lo damos fijo.
Widget _chartBox({required bool fill, required double compactHeight, required Widget chart}) =>
    fill ? chart : SizedBox(height: compactHeight, child: chart);

Widget _loadingBox() => const Padding(
  padding: EdgeInsets.all(24),
  child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
);

Widget _emptyBox(String message) => Padding(
  padding: const EdgeInsets.all(16),
  child: Text(message, style: const TextStyle(color: AppColors.textSecondary)),
);

Widget _errorBox() => _emptyBox('No se pudo cargar la información.');

const _axisStyle = TextStyle(color: AppColors.textSecondary, fontSize: 11);
const _tooltipStyle = TextStyle(color: AppColors.textPrimary, fontSize: 12);

AxisTitles _moneyAxis(double step) => AxisTitles(
  sideTitles: SideTitles(
    showTitles: true,
    reservedSize: 64,
    interval: step,
    getTitlesWidget: (value, meta) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Text(axisMoney(value), style: _axisStyle, textAlign: TextAlign.right),
    ),
  ),
);

FlGridData _grid(double step) => FlGridData(
  show: true,
  drawVerticalLine: false,
  horizontalInterval: step,
  getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.border, strokeWidth: 1, dashArray: [4, 4]),
);

const _noTitles = AxisTitles(sideTitles: SideTitles(showTitles: false));

// ── US-050: productos más vendidos ────────────────────────────────

class _TopProductsSection extends ConsumerStatefulWidget {
  final bool fill;
  const _TopProductsSection({required this.fill});

  @override
  ConsumerState<_TopProductsSection> createState() => _TopProductsSectionState();
}

class _TopProductsSectionState extends ConsumerState<_TopProductsSection> {
  bool _sortByAmount = false;

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(topProductsProvider(null));
    final compact = context.isCompact;

    final toggle = SegmentedButton<bool>(
      style: const ButtonStyle(visualDensity: VisualDensity.compact, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(value: false, label: Text('Unidades', softWrap: false)),
        ButtonSegment(value: true, label: Text('Monto', softWrap: false)),
      ],
      selected: {_sortByAmount},
      onSelectionChanged: (s) => setState(() => _sortByAmount = s.first),
    );

    return _SectionCard(
      title: 'Productos más vendidos',
      fill: widget.fill,
      actions: [
        // En celular no entra junto al título: va arriba del ranking.
        if (!compact) SizedBox(width: 220, child: toggle),
        IconButton(
          tooltip: 'Exportar CSV',
          icon: const Icon(Icons.ios_share_rounded, size: 20),
          onPressed: (productsAsync.valueOrNull ?? const []).isEmpty ? null : () => _exportCsv(productsAsync.value!),
        ),
      ],
      child: productsAsync.when(
        loading: _loadingBox,
        error: (_, _) => _errorBox(),
        data: (products) {
          if (products.isEmpty) return _emptyBox('Sin ventas en el período seleccionado.');

          final sorted = [...products]
            ..sort(
              (a, b) => _sortByAmount ? b.amountTotal.compareTo(a.amountTotal) : b.unitsSold.compareTo(a.unitsSold),
            );

          final ranking = _RankedBars(
            fill: widget.fill,
            items: [
              for (final p in sorted)
                (
                  label: p.productName,
                  value: _sortByAmount ? p.amountTotal : p.unitsSold.toDouble(),
                  valueLabel: _sortByAmount ? _money.format(p.amountTotal) : '${p.unitsSold} u.',
                  tooltip: '${p.productName}\n${p.unitsSold} u. · ${_money.format(p.amountTotal)}',
                ),
            ],
          );
          if (!compact) return ranking;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [toggle, const SizedBox(height: 12), ranking],
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
    final xFile = XFile.fromData(
      bytes,
      name: 'top_productos_${DateTime.now().millisecondsSinceEpoch}.csv',
      mimeType: 'text/csv',
    );
    await Share.shareXFiles([xFile], text: 'Ranking de productos más vendidos');
  }
}

typedef _BarItem = ({String label, double value, String valueLabel, String tooltip});

/// Ranking en barras horizontales: el nombre se lee derecho y completo,
/// no girado bajo una barra vertical. Al pasar el mouse, el detalle.
class _RankedBars extends StatelessWidget {
  final List<_BarItem> items;
  final bool fill;
  const _RankedBars({required this.items, required this.fill});

  @override
  Widget build(BuildContext context) {
    final max = items.fold<double>(0, (m, e) => math.max(m, e.value));
    double share(_BarItem e) => max <= 0 ? 0 : e.value / max;

    Widget rank(int i) => SizedBox(
      width: 24,
      child: Text(
        '${i + 1}',
        style: const TextStyle(color: AppColors.textDisabled, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
    Widget bar(_BarItem e, double thickness) => ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: share(e),
        minHeight: thickness,
        color: AppColors.primary,
        backgroundColor: AppColors.surfaceElevated,
      ),
    );
    Widget name(_BarItem e) => Text(
      e.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
    );
    Widget amount(_BarItem e) =>
        Text(e.valueLabel, maxLines: 1, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12));

    if (!fill) {
      // Celular: nombre y cifra arriba, barra abajo, a todo el ancho.
      return Column(
        children: [
          for (var i = 0; i < items.length; i++)
            Tooltip(
              message: items[i].tooltip,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        rank(i),
                        Expanded(child: name(items[i])),
                        const SizedBox(width: 8),
                        amount(items[i]),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Padding(padding: const EdgeInsets.only(left: 24), child: bar(items[i], 6)),
                  ],
                ),
              ),
            ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Mínimo 5 filas de alto: con pocos productos no se estiran.
        final rowHeight = (constraints.maxHeight / math.max(items.length, 5)).clamp(20.0, 40.0);
        return Column(
          children: [
            for (var i = 0; i < items.length; i++)
              SizedBox(
                height: rowHeight,
                child: Tooltip(
                  message: items[i].tooltip,
                  child: Row(
                    children: [
                      rank(i),
                      Expanded(flex: 5, child: name(items[i])),
                      const SizedBox(width: 8),
                      Expanded(flex: 4, child: bar(items[i], 10)),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 88,
                        child: Align(alignment: Alignment.centerRight, child: amount(items[i])),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ── US-051: tendencia de ventas ───────────────────────────────────

class _SalesTrendSection extends ConsumerWidget {
  final bool fill;
  const _SalesTrendSection({required this.fill});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendAsync = ref.watch(salesTrendProvider);
    final dateFmt = DateFormat('dd/MM');
    final peakDay = trendAsync.valueOrNull?.peakDay;

    return _SectionCard(
      title: 'Tendencia de ventas',
      fill: fill,
      footer: trendAsync.valueOrNull == null || trendAsync.value!.current.isEmpty
          ? null
          : Wrap(
              spacing: 16,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const _LegendDot(color: AppColors.primary, label: 'Actual'),
                const _LegendDot(color: AppColors.textDisabled, label: 'Período anterior'),
                if (peakDay != null) Text('Día pico: ${DateFormat('dd/MM/yyyy').format(peakDay)}', style: _axisStyle),
              ],
            ),
      child: trendAsync.when(
        loading: _loadingBox,
        error: (_, _) => _errorBox(),
        data: (trend) {
          if (trend.current.isEmpty) return _emptyBox('Sin ventas en el período seleccionado.');

          final maxLen = math.max(trend.current.length, trend.previous.length);
          final maxTotal = [
            for (final d in trend.current) d.total,
            for (final d in trend.previous) d.total,
          ].fold<double>(0, math.max);
          final step = niceStep(maxTotal);

          final chart = LineChart(
            LineChartData(
              minY: 0,
              maxY: axisTop(maxTotal, step),
              gridData: _grid(step),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: _moneyAxis(step),
                topTitles: _noTitles,
                rightTitles: _noTitles,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: labelEvery(maxLen).toDouble(),
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= trend.current.length) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(dateFmt.format(trend.current[i].day), style: _axisStyle),
                      );
                    },
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => AppColors.surfaceElevated,
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipItems: (spots) => spots.map((s) {
                    final current = s.barIndex == 0;
                    final series = current ? trend.current : trend.previous;
                    final i = s.x.toInt();
                    final day = i >= 0 && i < series.length ? dateFmt.format(series[i].day) : '';
                    return LineTooltipItem(
                      '${current ? 'Actual' : 'Anterior'} · $day\n${_money.format(s.y)}',
                      _tooltipStyle,
                    );
                  }).toList(),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: [for (var i = 0; i < trend.current.length; i++) FlSpot(i.toDouble(), trend.current[i].total)],
                  isCurved: true,
                  preventCurveOverShooting: true,
                  color: AppColors.primary,
                  barWidth: 3,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, bar, index) {
                      final isPeak = trend.peakDay != null && trend.current[index].day == trend.peakDay;
                      return FlDotCirclePainter(
                        radius: isPeak ? 5 : 0,
                        color: AppColors.accent,
                        strokeColor: AppColors.accent,
                      );
                    },
                  ),
                  belowBarData: BarAreaData(show: true, color: AppColors.primary.withValues(alpha: 0.1)),
                ),
                LineChartBarData(
                  spots: [
                    for (var i = 0; i < trend.previous.length; i++) FlSpot(i.toDouble(), trend.previous[i].total),
                  ],
                  isCurved: true,
                  preventCurveOverShooting: true,
                  color: AppColors.textDisabled,
                  barWidth: 2,
                  dotData: const FlDotData(show: false),
                  dashArray: const [6, 4],
                ),
              ],
            ),
          );
          return _chartBox(fill: fill, compactHeight: 240, chart: chart);
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
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(label, style: _axisStyle),
    ],
  );
}

// ── US-052: categorías más rentables ──────────────────────────────

class _CategoryBreakdownSection extends ConsumerWidget {
  final bool fill;
  const _CategoryBreakdownSection({required this.fill});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoryBreakdownProvider);
    final compact = context.isCompact;

    return _SectionCard(
      title: 'Categorías más rentables',
      fill: fill,
      footer: (categoriesAsync.valueOrNull ?? const []).isEmpty
          ? null
          : Text(
              compact ? 'Toca una barra para ver sus productos.' : 'Haz clic en una barra para ver sus productos.',
              style: const TextStyle(color: AppColors.textDisabled, fontSize: 11),
            ),
      child: categoriesAsync.when(
        loading: _loadingBox,
        error: (_, _) => _errorBox(),
        data: (categories) {
          if (categories.isEmpty) return _emptyBox('Sin ventas en el período seleccionado.');

          final maxMargin = categories.map((c) => c.estimatedMargin).fold<double>(0, math.max);
          final step = niceStep(maxMargin);

          final chart = LayoutBuilder(
            builder: (context, constraints) {
              // Con espacio, las etiquetas van derechas y en dos líneas;
              // si no, giradas como en celular.
              final perBar = (constraints.maxWidth - 64) / categories.length;
              final straight = perBar >= 60;

              return BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: axisTop(maxMargin, step),
                  gridData: _grid(step),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(
                    mouseCursorResolver: (event, response) =>
                        response?.spot != null ? SystemMouseCursors.click : MouseCursor.defer,
                    touchCallback: (event, response) {
                      if (event is! FlTapUpEvent) return;
                      final index = response?.spot?.touchedBarGroupIndex;
                      if (index == null || index < 0 || index >= categories.length) return;
                      _showDrillDown(context, categories[index].category);
                    },
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => AppColors.surfaceElevated,
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final c = categories[group.x.toInt()];
                        return BarTooltipItem(
                          '${c.category}\n${_money.format(c.estimatedMargin)} de margen\n'
                          '${c.unitsSold} u. · ${_money.format(c.amountTotal)} vendidos',
                          _tooltipStyle,
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: _moneyAxis(step),
                    topTitles: _noTitles,
                    rightTitles: _noTitles,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: straight ? 38 : 70,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= categories.length) return const SizedBox.shrink();
                          final label = categories[i].category;
                          if (straight) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: SizedBox(
                                width: perBar - 8,
                                child: Text(
                                  label,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: _axisStyle,
                                ),
                              ),
                            );
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Transform.rotate(
                              angle: -0.6,
                              child: SizedBox(
                                width: 80,
                                child: Text(
                                  label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
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
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: categories[i].estimatedMargin,
                            color: _kCategoryPalette[i % _kCategoryPalette.length],
                            width: (perBar * 0.45).clamp(14.0, 44.0),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      ),
                  ],
                ),
              );
            },
          );
          return _chartBox(fill: fill, compactHeight: 260, chart: chart);
        },
      ),
    );
  }

  void _showDrillDown(BuildContext context, String category) {
    showAdaptiveSheet(
      context: context,
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

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              category,
              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            const Text(
              'Productos vendidos en el período seleccionado',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
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
                            child: Text(
                              p.productName,
                              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                            ),
                          ),
                          Text(
                            '${p.unitsSold} u. · ${_money.format(p.amountTotal)}',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
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
  final bool fill;
  const _CashierPerformanceSection({required this.fill});

  static const _headerStyle = TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cashiersAsync = ref.watch(cashierPerformanceProvider);
    final compact = context.isCompact;

    return _SectionCard(
      title: 'Desempeño por cajero',
      fill: fill,
      child: cashiersAsync.when(
        loading: _loadingBox,
        error: (_, _) => _errorBox(),
        data: (cashiers) {
          if (cashiers.isEmpty) return _emptyBox('Sin ventas en el período seleccionado.');

          final maxSales = cashiers.map((c) => c.totalSales).fold<double>(0, math.max);
          final header = Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const Expanded(flex: 2, child: Text('Cajero', style: _headerStyle)),
                const Expanded(
                  child: Text('Ventas', textAlign: TextAlign.right, style: _headerStyle),
                ),
                Expanded(
                  child: Text(compact ? '# Trans.' : 'Transacciones', textAlign: TextAlign.right, style: _headerStyle),
                ),
                const Expanded(
                  child: Text('Ticket prom.', textAlign: TextAlign.right, style: _headerStyle),
                ),
              ],
            ),
          );
          final rows = [
            for (final c in cashiers)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              c.cashierName,
                              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 5),
                            // Parte de lo vendido respecto del que más vendió.
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: maxSales <= 0 ? 0 : c.totalSales / maxSales,
                                minHeight: 4,
                                color: AppColors.primary,
                                backgroundColor: AppColors.surfaceElevated,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        _money.format(c.totalSales),
                        textAlign: TextAlign.right,
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${c.transactionCount}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        _money.format(c.avgTicket),
                        textAlign: TextAlign.right,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
          ];

          return Column(
            children: [
              header,
              const Divider(color: AppColors.border, height: 16),
              if (fill) Expanded(child: ListView(children: rows)) else ...rows,
            ],
          );
        },
      ),
    );
  }
}
