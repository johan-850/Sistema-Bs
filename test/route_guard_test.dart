// Guard de rol por ruta (USB-038). En web hay barra de direcciones: un
// cajero puede escribir /admin/products a mano, y antes el redirect solo
// miraba si había sesión.

import 'package:flutter_test/flutter_test.dart';
import 'package:sistema_bs/core/router/app_routes.dart';
import 'package:sistema_bs/core/router/route_guard.dart';
import 'package:sistema_bs/features/auth/domain/entities/app_user.dart';

AppUser _user(String role) => AppUser(
      id: 'u1',
      email: 'u1@test.local',
      name: 'Usuario',
      role: role,
      isActive: true,
      createdAt: DateTime.utc(2026, 9, 1),
    );

final _cajero = _user('cajero');
final _admin = _user('adminmaster');

void main() {
  group('sin sesión', () {
    test('cualquier ruta lleva al login', () {
      for (final path in [
        AppRoutes.pos,
        AppRoutes.adminDashboard,
        AppRoutes.products,
        AppRoutes.settings,
      ]) {
        expect(resolveRedirect(user: null, path: path), AppRoutes.login,
            reason: path);
      }
    });

    test('en el login se queda', () {
      expect(resolveRedirect(user: null, path: AppRoutes.login), isNull);
    });
  });

  group('cajero', () {
    test('al entrar va a la apertura de caja', () {
      expect(resolveRedirect(user: _cajero, path: AppRoutes.login),
          AppRoutes.cashRegisterOpening);
    });

    test('escribir una ruta de administración lo devuelve a su pantalla', () {
      for (final path in [
        AppRoutes.adminDashboard,
        AppRoutes.products,
        AppRoutes.users,
        AppRoutes.inventory,
        '/admin/users/abc-123',
        '/admin/products/edit/xyz',
        '/admin/',
        '/admin/ruta-que-no-existe',
      ]) {
        expect(resolveRedirect(user: _cajero, path: path),
            AppRoutes.cashRegisterOpening,
            reason: path);
      }
    });

    test('sus propias pantallas no se tocan', () {
      for (final path in [
        AppRoutes.cashRegisterOpening,
        AppRoutes.pos,
        AppRoutes.cart,
        AppRoutes.catalog,
        AppRoutes.posExpenses,
        AppRoutes.settings,
      ]) {
        expect(resolveRedirect(user: _cajero, path: path), isNull,
            reason: path);
      }
    });
  });

  group('AdminMaster', () {
    test('al entrar va al panel', () {
      expect(resolveRedirect(user: _admin, path: AppRoutes.login),
          AppRoutes.adminDashboard);
    });

    test('entra a las rutas de administración', () {
      for (final path in [
        AppRoutes.adminDashboard,
        AppRoutes.products,
        '/admin/users/abc-123',
      ]) {
        expect(resolveRedirect(user: _admin, path: path), isNull,
            reason: path);
      }
    });
  });

  test('isAdminPath no confunde un prefijo parecido', () {
    expect(isAdminPath('/admin'), isTrue);
    expect(isAdminPath('/admin/products'), isTrue);
    expect(isAdminPath('/administracion'), isFalse);
    expect(isAdminPath('/pos'), isFalse);
  });
}
