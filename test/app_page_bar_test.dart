// Encabezado de escritorio (USB-042).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sistema_bs/core/widgets/app_page_bar.dart';

Future<void> _pump(WidgetTester tester, Size size, AppPageBar bar) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(appBar: bar, body: const SizedBox()),
  ));
}

AppPageBar _bar(List<String> taps, {bool highlighted = false}) => AppPageBar(
      title: 'Productos',
      subtitle: '30 productos',
      actions: [
        PageAction(
          icon: Icons.filter_list_rounded,
          label: 'Filtrar',
          highlighted: highlighted,
          onPressed: () => taps.add('filtrar'),
        ),
        PageAction(
          icon: Icons.add_rounded,
          label: 'Nuevo producto',
          primary: true,
          onPressed: () => taps.add('nuevo'),
        ),
      ],
    );

void main() {
  testWidgets('en escritorio las acciones llevan texto y el título va a la izquierda',
      (tester) async {
    final taps = <String>[];
    await _pump(tester, const Size(1366, 768), _bar(taps));

    expect(_button<OutlinedButton>('Filtrar'), findsOneWidget);
    expect(_button<ElevatedButton>('Nuevo producto'), findsOneWidget);
    expect(find.byType(IconButton), findsNothing);
    expect(find.text('30 productos'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Productos')).dx, lessThan(40));

    await tester.tap(find.text('Nuevo producto'));
    expect(taps, ['nuevo']);
  });

  testWidgets('en compacto quedan íconos con la etiqueta como tooltip', (tester) async {
    final taps = <String>[];
    await _pump(tester, const Size(400, 800), _bar(taps));

    expect(find.bySubtype<OutlinedButton>(), findsNothing);
    expect(find.bySubtype<ElevatedButton>(), findsNothing);
    expect(find.byTooltip('Filtrar'), findsOneWidget);
    expect(find.byTooltip('Nuevo producto'), findsOneWidget);

    await tester.tap(find.byTooltip('Filtrar'));
    expect(taps, ['filtrar']);
  });

  testWidgets('una acción marcada muestra el punto en ambos tamaños', (tester) async {
    for (final size in const [Size(1366, 768), Size(400, 800)]) {
      await _pump(tester, size, _bar([], highlighted: true));
      final badges = tester.widgetList<Badge>(find.byType(Badge));
      expect(badges.where((b) => b.isLabelVisible), hasLength(1), reason: '$size');
    }
  });

  testWidgets('una acción sin callback queda deshabilitada', (tester) async {
    await _pump(
      tester,
      const Size(1366, 768),
      const AppPageBar(title: 'Ventas', actions: [
        PageAction(icon: Icons.ios_share_rounded, label: 'Exportar CSV', onPressed: null),
      ]),
    );
    final button = tester.widget<OutlinedButton>(_button<OutlinedButton>('Exportar CSV'));
    expect(button.onPressed, isNull);
  });
}

// `OutlinedButton.icon` y `ElevatedButton.icon` crean subclases privadas.
Finder _button<T extends Widget>(String label) =>
    find.ancestor(of: find.text(label), matching: find.bySubtype<T>());
