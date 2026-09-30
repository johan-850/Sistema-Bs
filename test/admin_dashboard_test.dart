// Dashboard del AdminMaster (USB-026): comparativas y distribución.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sistema_bs/features/auth/domain/entities/app_user.dart';
import 'package:sistema_bs/features/auth/presentation/providers/auth_providers.dart';
import 'package:sistema_bs/features/dashboard/presentation/pages/admin_dashboard_page.dart';
import 'package:sistema_bs/features/pos/domain/repositories/sale_repository.dart';
import 'package:sistema_bs/features/pos/presentation/providers/sales_history_providers.dart';

const SalesKpis _kpis = (
  todayTotal: 486300.0,
  todayCount: 37,
  yesterdayTotal: 431800.0, // +12,6 %
  weekTotal: 3125400.0,
  weekCount: 241,
  weekPrevTotal: 0.0, // sin base
  monthTotal: 12480900.0,
  monthCount: 962,
  monthPrevTotal: 13102000.0, // -4,7 %
  avgTicket: 12974.0,
  paymentMethodCounts: {'efectivo': 610, 'transferencia': 281, 'mixto': 71},
);

Future<void> _pump(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(ProviderScope(
    overrides: [
      salesKpisProvider.overrideWith((ref) async => _kpis),
      authStateStreamProvider.overrideWith(
        (ref) => Stream.value(AppUser(
          id: 'u1',
          email: 'admin@demo.local',
          name: 'Laura Gómez',
          role: 'adminmaster',
          isActive: true,
          createdAt: DateTime(2026),
        )),
      ),
    ],
    child: const MaterialApp(home: AdminDashboardPage()),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  test('periodChange no compara contra un período sin ventas', () {
    expect(periodChange(100, 0), isNull);
    expect(periodChange(0, 0), isNull);
    expect(periodChange(110, 100), closeTo(0.1, 1e-9));
    expect(periodChange(90, 100), closeTo(-0.1, 1e-9));
  });

  testWidgets('en escritorio: indicadores con comparativa y accesos, sin desbordes', (tester) async {
    await _pump(tester, const Size(1366, 768));

    expect(find.textContaining('Hola, Laura'), findsOneWidget);
    expect(find.text('+13%'), findsOneWidget);
    expect(find.text('-5%'), findsOneWidget);
    expect(find.text('Sin ventas para comparar'), findsOneWidget);
    expect(find.text('Accesos rápidos'), findsOneWidget);
    expect(find.text('Nuevo producto'), findsOneWidget);

    // Lo esencial entra en la pantalla sin desplazarse.
    final bottom = tester.getBottomLeft(find.text('Estadísticas')).dy;
    expect(bottom, lessThan(768));
  });

  testWidgets('en celular se apila sin desbordes', (tester) async {
    await _pump(tester, const Size(390, 844));

    expect(find.text('Hoy'), findsOneWidget);
    expect(find.text('Métodos de pago · este mes'), findsOneWidget);

    // La cifra grande no infla la tarjeta al medir su alto.
    final card = find.ancestor(of: find.text('Hoy'), matching: find.byType(Container)).first;
    expect(tester.getSize(card).height, lessThan(170));
  });
}
