// Estadísticas en pantalla grande (USB-027): ejes y distribución.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sistema_bs/features/dashboard/presentation/pages/sales_statistics_page.dart';
import 'package:sistema_bs/features/pos/presentation/providers/statistics_providers.dart';

final _products = [
  for (var i = 0; i < 10; i++)
    (
      productId: 'p$i',
      productName: i == 0 ? 'Pasta Doria spaghetti 250 g' : 'Producto $i',
      unitsSold: 50 - i * 4,
      amountTotal: 120000.0 - i * 9000,
    ),
];

Future<void> _pump(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final start = DateTime(2026, 9, 28);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        topProductsProvider.overrideWith((ref, category) async => _products),
        salesTrendProvider.overrideWith(
          (ref) async => (
            current: [
              for (var i = 0; i < 3; i++) (day: start.add(Duration(days: i)), total: 400000.0 + i * 50000, count: 30),
            ],
            previous: [
              for (var i = 0; i < 7; i++)
                (day: start.subtract(Duration(days: 7 - i)), total: 380000.0 + i * 20000, count: 28),
            ],
            peakDay: start.add(const Duration(days: 2)),
          ),
        ),
        categoryBreakdownProvider.overrideWith(
          (ref) async => [
            (category: 'Abarrotes', unitsSold: 120, amountTotal: 900000.0, estimatedMargin: 250000.0),
            (category: 'Carnes y Embutidos', unitsSold: 40, amountTotal: 600000.0, estimatedMargin: 180000.0),
            (category: 'Bebidas', unitsSold: 90, amountTotal: 400000.0, estimatedMargin: 120000.0),
          ],
        ),
        cashierPerformanceProvider.overrideWith(
          (ref) async => [
            (
              cashierId: 'c1',
              cashierName: 'Andrés Pérez',
              totalSales: 1800000.0,
              transactionCount: 140,
              avgTicket: 12857.0,
            ),
            (
              cashierId: 'c2',
              cashierName: 'Marcela Ruiz',
              totalSales: 1300000.0,
              transactionCount: 101,
              avgTicket: 12871.0,
            ),
          ],
        ),
      ],
      child: const MaterialApp(home: SalesStatisticsPage()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  test('el eje usa pasos redondos con aire sobre el máximo', () {
    expect(niceStep(0), 1);
    expect(niceStep(100), 50);
    expect(niceStep(12480900), 5000000);
    expect(axisTop(12480900, 5000000), 15000000);
    // Justo en un múltiplo: se agrega un paso para que no toque el borde.
    expect(axisTop(10000000, 5000000), 15000000);
  });

  test('montos del eje en corto', () {
    expect(axisMoney(0), '\$0');
    expect(axisMoney(450000), '\$450 mil');
    expect(axisMoney(1500000), '\$1,5 M');
    expect(axisMoney(2000000), '\$2 M');
  });

  test('la fecha cae en un día entero', () {
    expect(labelEvery(3), 1);
    expect(labelEvery(7), 1);
    expect(labelEvery(31), 5);
    expect(labelEvery(92), 14);
  });

  test('dos filas de gráficas entran en la pantalla', () {
    expect(statsRowHeight(768), 296);
    expect(statsRowHeight(1080), 452);
    expect(statsRowHeight(600), 280);
    expect(statsRowHeight(1600), 480);
  });

  testWidgets('en escritorio van dos por fila y se ven las cuatro', (tester) async {
    await _pump(tester, const Size(1366, 768));

    final trend = tester.getTopLeft(find.text('Tendencia de ventas'));
    final top = tester.getTopLeft(find.text('Productos más vendidos'));
    expect(top.dy, trend.dy);
    expect(top.dx, greaterThan(trend.dx));

    final cashiers = tester.getBottomLeft(find.text('Desempeño por cajero'));
    expect(cashiers.dy, lessThan(768));

    // El nombre completo, derecho, no girado ni cortado a 70 px.
    expect(find.text('Pasta Doria spaghetti 250 g'), findsOneWidget);
    expect(find.text('Transacciones'), findsOneWidget);
    // Una fecha por día de la semana en curso, cada una bajo su punto.
    for (final day in ['28/09', '29/09', '30/09']) {
      expect(find.text(day), findsOneWidget, reason: day);
    }
    expect(find.text('Haz clic en una barra para ver sus productos.'), findsOneWidget);
  });

  testWidgets('al pasar el mouse por un producto se ve su detalle', (tester) async {
    await _pump(tester, const Size(1366, 768));

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.text('Pasta Doria spaghetti 250 g')));
    await tester.pump(const Duration(seconds: 1));

    expect(find.textContaining('50 u. · '), findsOneWidget);
  });

  testWidgets('en tablet va una por fila, con alto de monitor', (tester) async {
    await _pump(tester, const Size(1024, 768));

    final trend = tester.getTopLeft(find.text('Tendencia de ventas'));
    await tester.scrollUntilVisible(
      find.text('Productos más vendidos'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    final top = tester.getTopLeft(find.text('Productos más vendidos'));
    expect(top.dx, trend.dx);
  });

  testWidgets('en celular se apilan sin desbordes', (tester) async {
    await _pump(tester, const Size(390, 844));

    expect(find.text('Tendencia de ventas'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('# Trans.'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('# Trans.'), findsOneWidget);
    expect(find.text('Toca una barra para ver sus productos.'), findsOneWidget);
  });
}
