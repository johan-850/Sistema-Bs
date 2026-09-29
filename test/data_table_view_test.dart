// Tabla de escritorio compartida (USB-018, reutilizada en USB-020/024/025).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sistema_bs/core/widgets/data_table_view.dart';

enum _Col { name, price }

typedef _Row = ({String name, int price});

const _rows = <_Row>[(name: 'Arroz', price: 2900), (name: 'Aceite', price: 11500)];

Future<void> _pump(
  WidgetTester tester, {
  List<_Row> rows = _rows,
  _Col sortKey = _Col.name,
  bool ascending = true,
  ValueChanged<_Col>? onSort,
  ValueChanged<_Row>? onRowTap,
  Widget? footer,
}) async {
  tester.view.physicalSize = const Size(1200, 700);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: DataTableView<_Row, _Col>(
        columns: const [
          TableColumn('Nombre', flex: 3, sortKey: _Col.name),
          TableColumn('Precio', numeric: true, sortKey: _Col.price),
          TableColumn('Nota', width: 80),
        ],
        rows: rows,
        cells: (r) => [Text(r.name), Text('${r.price}'), const Text('—')],
        sortKey: sortKey,
        ascending: ascending,
        onSort: onSort,
        onRowTap: onRowTap,
        empty: const Text('Sin filas'),
        footer: footer,
      ),
    ),
  ));
}

void main() {
  testWidgets('un clic en el encabezado pide ordenar por esa columna', (tester) async {
    final sorted = <_Col>[];
    await _pump(tester, onSort: sorted.add);

    await tester.tap(find.text('Precio'));
    await tester.tap(find.text('Nombre'));
    expect(sorted, [_Col.price, _Col.name]);
  });

  testWidgets('la columna activa muestra la dirección del orden', (tester) async {
    await _pump(tester, sortKey: _Col.price, ascending: false, onSort: (_) {});
    expect(find.byIcon(Icons.arrow_downward_rounded), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward_rounded), findsNothing);
    // La otra columna ordenable ofrece el orden sin marcarlo.
    expect(find.byIcon(Icons.unfold_more_rounded), findsOneWidget);
  });

  testWidgets('una columna sin clave de orden no es clickeable', (tester) async {
    await _pump(tester, onSort: (_) {});
    expect(find.ancestor(of: find.text('Nota'), matching: find.byType(InkWell)), findsNothing);
  });

  testWidgets('las columnas numéricas se alinean a la derecha', (tester) async {
    await _pump(tester);
    final header = tester.getRect(find.text('Precio'));
    final value = tester.getRect(find.text('11500'));
    expect(value.right, closeTo(header.right, 1));
  });

  testWidgets('un clic en la fila la abre', (tester) async {
    final opened = <String>[];
    await _pump(tester, onRowTap: (r) => opened.add(r.name));
    await tester.tap(find.text('Aceite'));
    expect(opened, ['Aceite']);
  });

  testWidgets('sin filas muestra el estado vacío', (tester) async {
    await _pump(tester, rows: const []);
    expect(find.text('Sin filas'), findsOneWidget);
  });

  testWidgets('el paginador solo avanza si hay otra página', (tester) async {
    final moves = <String>[];
    await _pump(
      tester,
      footer: TablePager(
        page: 0,
        hasNext: false,
        onPrevious: () => moves.add('anterior'),
        onNext: () => moves.add('siguiente'),
      ),
    );
    expect(find.text('Página 1'), findsOneWidget);
    await tester.tap(find.text('Anterior'));
    await tester.tap(find.text('Siguiente'));
    expect(moves, isEmpty);
  });
}
