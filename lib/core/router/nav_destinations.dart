import 'package:flutter/material.dart';

import '../../features/auth/domain/entities/app_user.dart';
import 'app_routes.dart';

class NavDestination {
  final String label;
  final IconData icon;
  final String route;
  const NavDestination(this.label, this.icon, this.route);
}

class NavSection {
  final String? title;
  final List<NavDestination> destinations;
  const NavSection(this.title, this.destinations);
}

const navSettings =
    NavDestination('Configuración', Icons.settings_outlined, AppRoutes.settings);

const _adminSections = [
  NavSection(null, [
    NavDestination('Dashboard', Icons.dashboard_rounded, AppRoutes.adminDashboard),
  ]),
  NavSection('Turno y caja', [
    NavDestination('Historial de cajas', Icons.point_of_sale_rounded,
        AppRoutes.cashRegistersHistory),
  ]),
  NavSection('Tienda', [
    NavDestination('Cajeros', Icons.people_rounded, AppRoutes.users),
    NavDestination('Productos', Icons.inventory_2_outlined, AppRoutes.products),
    NavDestination('Inventario', Icons.bar_chart_rounded, AppRoutes.inventory),
    NavDestination('Gastos', Icons.payments_outlined, AppRoutes.expensesReport),
  ]),
  NavSection('Reportes', [
    NavDestination('Historial de ventas', Icons.receipt_long_rounded,
        AppRoutes.salesHistory),
    NavDestination('Estadísticas', Icons.analytics_rounded, AppRoutes.analytics),
  ]),
];

List<NavSection> navSectionsFor(AppUser user) {
  if (user.isAdmin) return _adminSections;
  return [
    NavSection(null, [
      const NavDestination('Ventas', Icons.storefront_rounded, AppRoutes.pos),
      const NavDestination('Carrito', Icons.shopping_cart_outlined, AppRoutes.cart),
      const NavDestination('Catálogo', Icons.inventory_2_outlined, AppRoutes.catalog),
      if (user.expensesEnabled)
        const NavDestination('Gastos', Icons.payments_outlined, AppRoutes.posExpenses),
    ]),
  ];
}

/// Gana el destino más específico: /pos/cart marca Carrito, no Ventas.
String? selectedRoute(String path, Iterable<NavDestination> destinations) {
  String? best;
  for (final d in destinations) {
    final contains = path == d.route || path.startsWith('${d.route}/');
    if (contains && (best == null || d.route.length > best.length)) {
      best = d.route;
    }
  }
  return best;
}
