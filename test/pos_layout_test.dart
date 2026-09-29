// Punto de venta de escritorio (USB-014): catálogo y carrito lado a lado.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sistema_bs/features/cash_register/domain/entities/cash_register.dart';
import 'package:sistema_bs/features/cash_register/presentation/providers/cash_register_providers.dart';
import 'package:sistema_bs/features/pos/presentation/pages/pos_page.dart';
import 'package:sistema_bs/features/pos/presentation/providers/pos_catalog_provider.dart';
import 'package:sistema_bs/features/products/domain/entities/product.dart';

final _t = DateTime.utc(2026, 9, 29, 12);

Product _product(String id, String name, {int stock = 50}) => Product(
      id: id,
      name: name,
      category: 'Abarrotes',
      price: 2900,
      costPrice: 2000,
      stock: stock,
      minStock: 5,
      unit: 'unidad',
      isActive: true,
      createdAt: _t,
      updatedAt: _t,
    );

final _register = CashRegister(
  id: 'r1',
  cashierId: 'c1',
  openingAmount: 100000,
  openingBreakdown: const {},
  openingTime: _t,
  status: 'open',
  createdAt: _t,
  updatedAt: _t,
);

/// Sin Supabase: el notifier real se suscribe a la tabla en tiempo real.
class _FakeCatalog extends StateNotifier<PosCatalogState> implements PosCatalogNotifier {
  _FakeCatalog(List<Product> products) : super(PosCatalogState(products: products));

  @override
  Future<void> load() async {}

  @override
  void search(String query) {}

  @override
  Future<void> filterByCategory(String? category) async {}
}

Future<void> _pump(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(ProviderScope(
    overrides: [
      activeRegisterProvider.overrideWith((ref) async => _register),
      posCatalogProvider.overrideWith((ref) => _FakeCatalog([
            _product('p1', 'Arroz Diana 500 g'),
            _product('p2', 'Aceite Premier 1 L'),
            _product('p3', 'Frijol bola roja', stock: 0),
          ])),
    ],
    child: const MaterialApp(home: PosPage()),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  testWidgets('en escritorio el carrito está siempre a la vista', (tester) async {
    await _pump(tester, const Size(1366, 768));

    expect(find.text('Venta actual'), findsOneWidget);
    expect(find.text('El carrito está vacío'), findsOneWidget);
    // Sin botón de carrito en el buscador: el panel ya está al lado.
    expect(find.byTooltip('Carrito'), findsNothing);

    // Dos productos por fila como mínimo: el catálogo es una cuadrícula.
    final arroz = tester.getTopLeft(find.text('Arroz Diana 500 g'));
    final aceite = tester.getTopLeft(find.text('Aceite Premier 1 L'));
    expect(aceite.dy, arroz.dy);
    expect(aceite.dx, greaterThan(arroz.dx));

    // Un clic en la tarjeta agrega el producto y el panel se actualiza.
    await tester.tap(find.text('Arroz Diana 500 g'));
    await tester.pumpAndSettle();
    expect(find.text('× 1'), findsOneWidget);
    expect(find.text('1 ítem'), findsOneWidget);
    expect(find.text('Arroz Diana 500 g'), findsNWidgets(2));
    expect(find.text('Cobrar'), findsOneWidget);
  });

  testWidgets('un producto agotado no se agrega', (tester) async {
    await _pump(tester, const Size(1366, 768));

    await tester.tap(find.text('Frijol bola roja'));
    await tester.pumpAndSettle();
    expect(find.text('El carrito está vacío'), findsOneWidget);
  });

  testWidgets('en compacto el carrito sigue siendo una pantalla aparte', (tester) async {
    await _pump(tester, const Size(400, 800));

    expect(find.text('Venta actual'), findsNothing);
    expect(find.byTooltip('Carrito'), findsOneWidget);

    final arroz = tester.getTopLeft(find.text('Arroz Diana 500 g'));
    final aceite = tester.getTopLeft(find.text('Aceite Premier 1 L'));
    expect(aceite.dy, greaterThan(arroz.dy));
  });
}
