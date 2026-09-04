import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../pos/presentation/providers/sales_history_providers.dart';
import '../../../../core/utils/receipt_pdf.dart' show paymentMethodLabel;

/// Dashboard principal del AdminMaster — US-048 (base)
/// Drawer de navegación a todos los módulos del sistema
class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateStreamProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Configuración',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      drawer: _AdminDrawer(userName: user?.name ?? ''),
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
            const SizedBox(height: 24),

            // Módulos de acceso rápido
            Text('Módulos', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.1,
              children: [
                _ModuleCard(icon: Icons.people_rounded, label: 'Cajeros', color: AppColors.primary,
                    onTap: () => context.push('/admin/users')),
                _ModuleCard(icon: Icons.inventory_2_outlined, label: 'Productos', color: AppColors.secondary,
                    onTap: () => context.push('/admin/products')),
                _ModuleCard(icon: Icons.bar_chart_rounded, label: 'Inventario', color: AppColors.warning,
                    onTap: () => context.push('/admin/inventory')),
                _ModuleCard(icon: Icons.payments_outlined, label: 'Gastos', color: AppColors.error,
                    onTap: () => context.push('/admin/expenses')),
                _ModuleCard(icon: Icons.receipt_long_rounded, label: 'Reportes', color: AppColors.info,
                    onTap: () => context.push('/admin/sales-history')),
                _ModuleCard(icon: Icons.analytics_rounded, label: 'Estadísticas', color: AppColors.accent,
                    onTap: () => context.push('/admin/analytics')),
                _ModuleCard(icon: Icons.settings_outlined, label: 'Configuración', color: AppColors.textSecondary,
                    onTap: () => context.push('/settings')),
              ],
            ),
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
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.6,
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

class _ModuleCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ModuleCard({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

class _AdminDrawer extends StatelessWidget {
  final String userName;
  const _AdminDrawer({required this.userName});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.surfaceCard,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Icon(Icons.storefront_rounded, color: AppColors.primary, size: 48),
            const SizedBox(height: 8),
            const Text('Sistema Bs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text(userName, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const Divider(height: 32),
            // Wrapped in Expanded+ListView to prevent Column overflow
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _drawerItem(context, Icons.dashboard_rounded, 'Dashboard', '/admin'),
                  const _DrawerSectionLabel('Turno y Caja'),
                  _drawerItem(context, Icons.point_of_sale_rounded, 'Historial de Cajas', '/admin/cash-registers'),
                  const _DrawerSectionLabel('Tienda'),
                  _drawerItem(context, Icons.people_rounded, 'Cajeros', '/admin/users'),
                  _drawerItem(context, Icons.inventory_2_outlined, 'Productos', '/admin/products'),
                  _drawerItem(context, Icons.bar_chart_rounded, 'Inventario', '/admin/inventory'),
                  _drawerItem(context, Icons.payments_outlined, 'Gastos', '/admin/expenses'),
                  const _DrawerSectionLabel('Reportes'),
                  _drawerItem(context, Icons.receipt_long_rounded, 'Historial de ventas', '/admin/sales-history'),
                  _drawerItem(context, Icons.analytics_rounded, 'Estadísticas', '/admin/analytics'),
                ],

              ),
            ),
            const Divider(),
            _drawerItem(context, Icons.settings_outlined, 'Configuración', '/settings'),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(BuildContext context, IconData icon, String label, String route) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary, size: 22),
      title: Text(label),
      onTap: () {
        Navigator.pop(context);
        context.go(route);
      },
    );
  }
}

/// Etiqueta de sección en el Drawer del Admin
class _DrawerSectionLabel extends StatelessWidget {
  final String label;
  const _DrawerSectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: AppColors.textDisabled,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

