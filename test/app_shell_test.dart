// Barra lateral (USB-011) montada de verdad, a anchos de escritorio.
// Un desborde de layout hace fallar el test.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sistema_bs/core/widgets/app_shell.dart';
import 'package:sistema_bs/features/auth/domain/entities/app_user.dart';
import 'package:sistema_bs/features/auth/presentation/providers/auth_providers.dart';

final _admin = AppUser(
  id: 'u1',
  email: 'admin@test.local',
  name: 'Ana Admin',
  role: 'adminmaster',
  isActive: true,
  createdAt: DateTime.utc(2026, 9, 1),
);

class _Page extends StatelessWidget {
  final String name;
  const _Page(this.name);
  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text('página $name')));
}

Future<void> _pumpShell(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: '/admin',
    routes: [
      ShellRoute(
        builder: (_, state, child) => AppShell(location: state.uri.path, child: child),
        routes: [
          for (final p in [
            '/admin',
            '/admin/products',
            '/admin/products/edit/:id',
            '/admin/cash-registers',
            '/admin/users',
            '/admin/inventory',
            '/admin/expenses',
            '/admin/sales-history',
            '/admin/analytics',
            '/settings',
          ])
            GoRoute(path: p, builder: (_, s) => _Page(s.uri.path)),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(ProviderScope(
    overrides: [
      authStateStreamProvider.overrideWith((_) => Stream.value(_admin)),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pumpAndSettle();
}

Color? _labelColor(WidgetTester tester, String label) =>
    tester.widget<Text>(find.text(label)).style?.color;

void main() {
  testWidgets('expandido: etiquetas, secciones y usuario visibles', (tester) async {
    await _pumpShell(tester, const Size(1366, 768));

    expect(find.text('Sistema Bs'), findsOneWidget);
    expect(find.text('Ana Admin · AdminMaster'), findsOneWidget);
    expect(find.text('TIENDA'), findsOneWidget);
    for (final label in ['Dashboard', 'Productos', 'Estadísticas', 'Configuración']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('página /admin'), findsOneWidget);
  });

  testWidgets('navegar mueve la marca y conserva la barra', (tester) async {
    await _pumpShell(tester, const Size(1366, 768));
    final shellElement = tester.element(find.byType(AppShell));

    await tester.tap(find.text('Productos'));
    await tester.pumpAndSettle();

    expect(find.text('página /admin/products'), findsOneWidget);
    expect(_labelColor(tester, 'Productos'), isNot(_labelColor(tester, 'Dashboard')));
    // El mismo Element: la barra no se volvió a montar.
    expect(tester.element(find.byType(AppShell)), same(shellElement));
  });

  testWidgets('desde una subpantalla, el destino marcado vuelve a la raíz', (tester) async {
    await _pumpShell(tester, const Size(1366, 768));
    GoRouter.of(tester.element(find.byType(AppShell))).go('/admin/products/edit/7');
    await tester.pumpAndSettle();
    expect(find.text('página /admin/products/edit/7'), findsOneWidget);

    await tester.tap(find.text('Productos'));
    await tester.pumpAndSettle();
    expect(find.text('página /admin/products'), findsOneWidget);
  });

  testWidgets('medio: solo íconos, con tooltip', (tester) async {
    await _pumpShell(tester, const Size(1024, 768));

    expect(find.text('Productos'), findsNothing);
    expect(find.text('TIENDA'), findsNothing);
    expect(find.byTooltip('Productos'), findsOneWidget);

    await tester.tap(find.byTooltip('Productos'));
    await tester.pumpAndSettle();
    expect(find.text('página /admin/products'), findsOneWidget);
  });

  testWidgets('ventana angosta y baja: no desborda y todo destino es alcanzable', (tester) async {
    await _pumpShell(tester, const Size(400, 420));
    expect(find.text('página /admin'), findsOneWidget);

    await tester.scrollUntilVisible(find.byTooltip('Estadísticas'), 50);
    await tester.ensureVisible(find.byTooltip('Estadísticas'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Estadísticas'));
    await tester.pumpAndSettle();
    expect(find.text('página /admin/analytics'), findsOneWidget);
  });
}
