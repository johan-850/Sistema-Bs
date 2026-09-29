import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_page_bar.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../pos/presentation/providers/sales_history_providers.dart';
import '../../../../core/utils/receipt_pdf.dart' show paymentMethodLabel;

/// Dashboard principal del AdminMaster — US-048 (base)
class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateStreamProvider).valueOrNull;

    return Scaffold(
      appBar: const AppPageBar(title: 'Dashboard'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bienvenida
            if (user != null)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary.withValues(alpha: 0.15), AppColors.secondary.withValues(alpha: 0.1)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.waving_hand_rounded, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Hola, ${user.name.split(' ').first} 👋',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
                          const Text('Panel de administración',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),

            // US-048: KPIs de ventas
            const _SalesKpiSection(),
          ],
        ),
      ),
    );
  }
}

/// US-048: tarjetas KPI (ventas hoy/semana/mes, comparativa, ticket
/// promedio y métodos de pago más usados).
class _SalesKpiSection extends ConsumerWidget {
  const _SalesKpiSection();

  String _comparisonLabel(double current, double previous) {
    if (previous <= 0) return current > 0 ? 'Nuevo' : '';
    final pct = ((current - previous) / previous) * 100;
    final sign = pct >= 0 ? '+' : '';
    return '$sign${pct.toStringAsFixed(0)}% vs. período anterior';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kpisAsync = ref.watch(salesKpisProvider);
    final currencyFmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

    return kpisAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (kpis) {
        if (kpis == null) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ventas', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 280,
                mainAxisExtent: 88,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
              ),
              children: [
                _KpiCard(label: 'Hoy', value: currencyFmt.format(kpis.todayTotal), sub: '${kpis.todayCount} ventas'),
                _KpiCard(
                  label: 'Esta semana',
                  value: currencyFmt.format(kpis.weekTotal),
                  sub: _comparisonLabel(kpis.weekTotal, kpis.weekPrevTotal),
                ),
                _KpiCard(
                  label: 'Este mes',
                  value: currencyFmt.format(kpis.monthTotal),
                  sub: _comparisonLabel(kpis.monthTotal, kpis.monthPrevTotal),
                ),
                _KpiCard(
                  label: 'Ticket promedio',
                  value: currencyFmt.format(kpis.avgTicket),
                  sub: '${kpis.monthCount} transacciones (mes)',
                ),
              ],
            ),
            if (kpis.paymentMethodCounts.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
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
                    const Text('Métodos de pago más usados (mes)',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    const SizedBox(height: 8),
                    ...(kpis.paymentMethodCounts.entries.toList()
                          ..sort((a, b) => b.value.compareTo(a.value)))
                        .map((e) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(paymentMethodLabel(e.key),
                                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                                  Text('${e.value}',
                                      style: const TextStyle(
                                          color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                                ],
                              ),
                            )),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final String sub;

  const _KpiCard({required this.label, required this.value, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          if (sub.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(sub,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ],
      ),
    );
  }
}
