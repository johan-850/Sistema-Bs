// Barra lateral (USB-011): qué destinos ve cada rol y cuál queda marcado.

import 'package:flutter_test/flutter_test.dart';
import 'package:sistema_bs/core/router/app_routes.dart';
import 'package:sistema_bs/core/router/nav_destinations.dart';
import 'package:sistema_bs/features/auth/domain/entities/app_user.dart';

AppUser _user(String role, {bool expensesEnabled = true}) => AppUser(
      id: 'u1',
      email: 'u1@test.local',
      name: 'Usuario',
      role: role,
      isActive: true,
      expensesEnabled: expensesEnabled,
      createdAt: DateTime.utc(2026, 9, 1),
    );

List<String> _routes(AppUser user) => [
      for (final s in navSectionsFor(user))
        for (final d in s.destinations) d.route,
    ];

void main() {
  group('destinos por rol', () {
    test('el AdminMaster ve solo rutas de administración', () {
      final routes = _routes(_user('adminmaster'));
      expect(routes, contains(AppRoutes.products));
      expect(routes, contains(AppRoutes.salesHistory));
      expect(routes.every((r) => r.startsWith('/admin')), isTrue);
    });

    test('el cajero no ve ninguna ruta de administración', () {
      final routes = _routes(_user('cajero'));
      expect(routes, [AppRoutes.pos, AppRoutes.cart, AppRoutes.catalog, AppRoutes.posExpenses]);
    });

    test('sin el módulo de gastos habilitado, el cajero no ve Gastos', () {
      final routes = _routes(_user('cajero', expensesEnabled: false));
      expect(routes, isNot(contains(AppRoutes.posExpenses)));
    });
  });

  group('destino marcado', () {
    final admin = [
      for (final s in navSectionsFor(_user('adminmaster'))) ...s.destinations,
      navSettings,
    ];
    final cajero = [
      for (final s in navSectionsFor(_user('cajero'))) ...s.destinations,
      navSettings,
    ];

    final casosAdmin = {
      '/admin': AppRoutes.adminDashboard,
      '/admin/products': AppRoutes.products,
      '/admin/products/edit/abc': AppRoutes.products,
      '/admin/products/import': AppRoutes.products,
      '/admin/inventory/p1/movements': AppRoutes.inventory,
      '/admin/expenses/categories': AppRoutes.expensesReport,
      '/admin/sales-history/v1': AppRoutes.salesHistory,
      '/admin/users/create': AppRoutes.users,
      '/settings': AppRoutes.settings,
    };
    casosAdmin.forEach((path, esperado) {
      test('admin en $path marca $esperado', () {
        expect(selectedRoute(path, admin), esperado);
      });
    });

    final casosCajero = {
      '/pos': AppRoutes.pos,
      '/pos/cart': AppRoutes.cart,
      '/pos/expenses': AppRoutes.posExpenses,
      '/catalog': AppRoutes.catalog,
    };
    casosCajero.forEach((path, esperado) {
      test('cajero en $path marca $esperado', () {
        expect(selectedRoute(path, cajero), esperado);
      });
    });

    test('un prefijo parecido no cuenta como la misma sección', () {
      expect(selectedRoute('/possible', cajero), isNull);
    });
  });
}
