import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/breakpoints.dart';
import '../../../../core/utils/receipt_pdf.dart' show paymentMethodLabel;
import '../../../../core/widgets/app_page_bar.dart';
import '../../../../core/widgets/hover_ink_well.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../pos/domain/repositories/sale_repository.dart' show SalesKpis;
import '../../../pos/presentation/providers/sales_history_providers.dart';

final _money = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

/// Variación de [current] respecto de [previous] (0.1 = +10%). Null si no
/// hay base para comparar: un período anterior sin ventas daría infinito.
double? periodChange(double current, double previous) =>
    previous > 0 ? (current - previous) / previous : null;

/// Dashboard del AdminMaster — US-048, USB-026: lo esencial sin desplazarse.
class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateStreamProvider).valueOrNull;
    final kpis = ref.watch(salesKpisProvider);
    final compact = context.isCompact;
    // Celular angosto: una columna; dos no dejan leer ni las cifras.
    final compactColumns = MediaQuery.sizeOf(context).width < 520 ? 1 : 2;

    final date = DateFormat("EEEE d 'de' MMMM", 'es').format(DateTime.now());
    final today = date[0].toUpperCase() + date.substring(1);

    void reload() => ref.invalidate(salesKpisProvider);

    final Widget indicators = kpis.when(
      loading: () => const _KpiPlaceholder(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (_, _) => _KpiPlaceholder(child: _LoadError(onRetry: reload)),
      data: (k) => k == null
          ? _KpiPlaceholder(child: _LoadError(onRetry: reload))
          : _Grid(columns: compact ? compactColumns : 4, children: _kpiCards(k)),
    );
    final methods = _PaymentMethodsCard(counts: kpis.valueOrNull?.paymentMethodCounts);

    return Scaffold(
      appBar: AppPageBar(
        title: 'Dashboard',
        subtitle: user == null ? today : 'Hola, ${user.name.split(' ').first} · $today',
        actions: [
          PageAction(
            icon: Icons.refresh_rounded,
            label: 'Actualizar',
            onPressed: kpis.isLoading ? null : reload,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: compact ? const EdgeInsets.all(16) : const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            indicators,
            const SizedBox(height: 16),
            if (compact) ...[
              methods,
              const SizedBox(height: 16),
              _QuickActions(columns: compactColumns),
            ] else
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 2, child: methods),
                    const SizedBox(width: 16),
                    // Por ancho de pantalla y no con LayoutBuilder, que no
                    // funciona dentro de IntrinsicHeight.
                    Expanded(
                      flex: 3,
                      child: _QuickActions(columns: MediaQuery.sizeOf(context).width >= 1600 ? 3 : 2),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _kpiCards(SalesKpis k) {
    String sales(int n) => n == 1 ? '1 venta' : '$n ventas';
    return [
      _KpiCard(
        icon: Icons.today_rounded,
        label: 'Hoy',
        value: k.todayTotal,
        detail: sales(k.todayCount),
        change: _Change(k.todayTotal, k.yesterdayTotal, 'vs. ayer', 'Ayer, hasta esta hora'),
      ),
      _KpiCard(
        icon: Icons.date_range_rounded,
        label: 'Esta semana',
        value: k.weekTotal,
        detail: sales(k.weekCount),
        change: _Change(k.weekTotal, k.weekPrevTotal, 'vs. semana pasada', 'Semana pasada, hasta este día y hora'),
      ),
      _KpiCard(
        icon: Icons.calendar_month_rounded,
        label: 'Este mes',
        value: k.monthTotal,
        detail: sales(k.monthCount),
        change: _Change(k.monthTotal, k.monthPrevTotal, 'vs. mes pasado', 'Mes pasado, hasta este día y hora'),
      ),
      _KpiCard(
        icon: Icons.receipt_rounded,
        label: 'Ticket promedio',
        value: k.avgTicket,
        detail: '${sales(k.monthCount)} del mes',
      ),
    ];
  }
}

/// Filas de [columns] celdas del mismo alto; la última se completa con
/// huecos para que las tarjetas no se estiren.
class _Grid extends StatelessWidget {
  final int columns;
  final List<Widget> children;
  final double spacing;

  const _Grid({required this.columns, required this.children, this.spacing = 16});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += columns) {
      if (rows.isNotEmpty) rows.add(SizedBox(height: spacing));
      rows.add(IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var j = 0; j < columns; j++) ...[
              if (j > 0) SizedBox(width: spacing),
              Expanded(child: i + j < children.length ? children[i + j] : const SizedBox()),
            ],
          ],
        ),
      ));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final Widget child;
  const _Panel({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

// ── Indicadores ────────────────────────────────────────────────

class _Change {
  final double current;
  final double previous;
  final String caption;
  final String previousLabel;
  const _Change(this.current, this.previous, this.caption, this.previousLabel);
}

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final double value;
  final String detail;
  final _Change? change;

  const _KpiCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
    this.change,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            // softWrap: IntrinsicHeight mide el texto sin escalar; si pudiera
            // partirse en líneas, la tarjeta saldría más alta de lo que se ve.
            child: Text(
              _money.format(value),
              maxLines: 1,
              softWrap: false,
              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 26),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          if (change != null) ...[
            const SizedBox(height: 10),
            _ChangeBadge(change!),
          ],
        ],
      ),
    );
  }
}

class _ChangeBadge extends StatelessWidget {
  final _Change change;
  const _ChangeBadge(this.change);

  @override
  Widget build(BuildContext context) {
    final ratio = periodChange(change.current, change.previous);
    if (ratio == null) {
      return const Text(
        'Sin ventas para comparar',
        style: TextStyle(color: AppColors.textDisabled, fontSize: 12),
      );
    }
    final pct = (ratio * 100).round();
    final color = pct > 0 ? AppColors.success : (pct < 0 ? AppColors.error : AppColors.textSecondary);
    final icon = pct > 0
        ? Icons.arrow_upward_rounded
        : (pct < 0 ? Icons.arrow_downward_rounded : Icons.remove_rounded);

    return Tooltip(
      message: '${change.previousLabel}: ${_money.format(change.previous)}',
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 2),
                Text(
                  '${pct > 0 ? '+' : ''}$pct%',
                  style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              change.caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiPlaceholder extends StatelessWidget {
  final Widget child;
  const _KpiPlaceholder({required this.child});

  @override
  Widget build(BuildContext context) => SizedBox(height: 132, child: Center(child: child));
}

class _LoadError extends StatelessWidget {
  final VoidCallback onRetry;
  const _LoadError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('No se pudieron cargar las ventas.', style: TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Reintentar'),
        ),
      ],
    );
  }
}

// ── Métodos de pago ────────────────────────────────────────────

class _PaymentMethodsCard extends StatelessWidget {
  /// Null mientras cargan (o si fallaron) los indicadores.
  final Map<String, int>? counts;
  const _PaymentMethodsCard({required this.counts});

  @override
  Widget build(BuildContext context) {
    final entries = (counts?.entries.toList() ?? [])..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<int>(0, (sum, e) => sum + e.value);

    return _Panel(
      title: 'Métodos de pago · este mes',
      child: total == 0
          ? Text(
              counts == null ? '—' : 'Sin ventas este mes',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            )
          : Column(
              children: [
                for (final e in entries) ...[
                  if (e != entries.first) const SizedBox(height: 14),
                  _MethodRow(label: paymentMethodLabel(e.key), count: e.value, share: e.value / total),
                ],
              ],
            ),
    );
  }
}

class _MethodRow extends StatelessWidget {
  final String label;
  final int count;
  final double share;
  const _MethodRow({required this.label, required this.count, required this.share});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$count · ${(share * 100).round()}%',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: share,
            minHeight: 6,
            color: AppColors.primary,
            backgroundColor: AppColors.surfaceElevated,
          ),
        ),
      ],
    );
  }
}

// ── Accesos rápidos ────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  final int columns;
  const _QuickActions({required this.columns});

  @override
  Widget build(BuildContext context) {
    // Lo del día a día que no es solo "abrir una sección": las acciones de
    // alta abren directo el formulario.
    final tiles = [
      _QuickActionTile(
        icon: Icons.add_box_outlined,
        title: 'Nuevo producto',
        subtitle: 'Agregar al catálogo',
        onTap: () => context.go('/admin/products/new'),
      ),
      _QuickActionTile(
        icon: Icons.playlist_add_check_rounded,
        title: 'Lista de reposición',
        subtitle: 'Productos por pedir',
        onTap: () => context.go(AppRoutes.inventoryRestock),
      ),
      _QuickActionTile(
        icon: Icons.person_add_alt_1_rounded,
        title: 'Nuevo cajero',
        subtitle: 'Crear una cuenta',
        onTap: () => context.push(AppRoutes.createCashier),
      ),
      _QuickActionTile(
        icon: Icons.receipt_long_rounded,
        title: 'Historial de ventas',
        subtitle: 'Ventas y anulaciones',
        onTap: () => context.go(AppRoutes.salesHistory),
      ),
      _QuickActionTile(
        icon: Icons.point_of_sale_rounded,
        title: 'Historial de cajas',
        subtitle: 'Aperturas y cuadres',
        onTap: () => context.go(AppRoutes.cashRegistersHistory),
      ),
      _QuickActionTile(
        icon: Icons.analytics_rounded,
        title: 'Estadísticas',
        subtitle: 'Tendencias y rankings',
        onTap: () => context.go(AppRoutes.analytics),
      ),
    ];
    return _Panel(
      title: 'Accesos rápidos',
      child: _Grid(columns: columns, spacing: 10, children: tiles),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);
    return HoverInkWell(
      onTap: onTap,
      borderRadius: radius,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated.withValues(alpha: 0.5),
          borderRadius: radius,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
