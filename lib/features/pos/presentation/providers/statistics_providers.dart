// ============================================================
// lib/features/pos/presentation/providers/statistics_providers.dart
// Estadísticas y tendencias de ventas — EP-09 S-10 (AdminMaster)
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/repositories/sale_repository.dart';
import '../../domain/use_cases/sale_use_cases.dart';
import 'checkout_provider.dart' show saleRepositoryProvider;

// ── DI ──────────────────────────────────────────────────────────

final getTopProductsUseCaseProvider = Provider(
  (ref) => GetTopProductsUseCase(ref.read(saleRepositoryProvider)),
);

final getSalesTrendUseCaseProvider = Provider(
  (ref) => GetSalesTrendUseCase(ref.read(saleRepositoryProvider)),
);

final getCategoryBreakdownUseCaseProvider = Provider(
  (ref) => GetCategoryBreakdownUseCase(ref.read(saleRepositoryProvider)),
);

final getCashierPerformanceUseCaseProvider = Provider(
  (ref) => GetCashierPerformanceUseCase(ref.read(saleRepositoryProvider)),
);

// ── Selector de período compartido por las 3 secciones ─────────

enum StatsPeriod { week, month, quarter }

extension StatsPeriodX on StatsPeriod {
  String get label => switch (this) {
        StatsPeriod.week => 'Semana',
        StatsPeriod.month => 'Mes',
        StatsPeriod.quarter => 'Trimestre',
      };

  /// Rango del período actual: desde su inicio calendario hasta ahora.
  ({DateTime from, DateTime to}) get range {
    final now = DateTime.now();
    switch (this) {
      case StatsPeriod.week:
        final today = DateTime(now.year, now.month, now.day);
        return (from: today.subtract(Duration(days: now.weekday - 1)), to: now);
      case StatsPeriod.month:
        return (from: DateTime(now.year, now.month), to: now);
      case StatsPeriod.quarter:
        final quarterStartMonth = ((now.month - 1) ~/ 3) * 3 + 1;
        return (from: DateTime(now.year, quarterStartMonth), to: now);
    }
  }

  /// Rango del período calendario anterior equivalente (misma duración),
  /// mismo criterio que `weekPrevStart`/`monthPrevStart` en getSalesKpis.
  ({DateTime from, DateTime to}) get previousRange {
    final current = range;
    switch (this) {
      case StatsPeriod.week:
        return (from: current.from.subtract(const Duration(days: 7)), to: current.from);
      case StatsPeriod.month:
        return (from: DateTime(current.from.year, current.from.month - 1), to: current.from);
      case StatsPeriod.quarter:
        return (from: DateTime(current.from.year, current.from.month - 3), to: current.from);
    }
  }
}

final statsPeriodProvider = StateProvider<StatsPeriod>((ref) => StatsPeriod.week);

// ── US-050: ranking de productos más vendidos ───────────────────

/// key = categoría opcional (null = ranking general top 10, no null =
/// drill-down de US-052 con un límite más alto).
final topProductsProvider =
    FutureProvider.autoDispose.family<List<TopProduct>, String?>((ref, category) async {
  final range = ref.watch(statsPeriodProvider).range;
  final result = await ref.read(getTopProductsUseCaseProvider)(
    from: range.from,
    to: range.to,
    category: category,
    limit: category == null ? 10 : 50,
  );
  return result.products;
});

// ── US-051: tendencia de ventas (actual vs. período anterior) ───

typedef SalesTrendData = ({
  List<DailySales> current,
  List<DailySales> previous,
  DateTime? peakDay,
});

final salesTrendProvider = FutureProvider.autoDispose<SalesTrendData>((ref) async {
  final period = ref.watch(statsPeriodProvider);
  final range = period.range;
  final prevRange = period.previousRange;
  final useCase = ref.read(getSalesTrendUseCaseProvider);

  final currentResult = await useCase(from: range.from, to: range.to);
  final previousResult = await useCase(from: prevRange.from, to: prevRange.to);

  DateTime? peakDay;
  var peakTotal = -1.0;
  for (final d in currentResult.days) {
    if (d.total > peakTotal) {
      peakTotal = d.total;
      peakDay = d.day;
    }
  }

  return (current: currentResult.days, previous: previousResult.days, peakDay: peakDay);
});

// ── US-052: categorías más rentables ─────────────────────────────

final categoryBreakdownProvider = FutureProvider.autoDispose<List<CategoryStat>>((ref) async {
  final range = ref.watch(statsPeriodProvider).range;
  final result = await ref.read(getCategoryBreakdownUseCaseProvider)(from: range.from, to: range.to);
  return result.categories;
});

// ── US-053: desempeño por cajero ──────────────────────────────────

final cashierPerformanceProvider = FutureProvider.autoDispose<List<CashierPerformance>>((ref) async {
  final range = ref.watch(statsPeriodProvider).range;
  final result = await ref.read(getCashierPerformanceUseCaseProvider)(from: range.from, to: range.to);
  return result.cashiers;
});
