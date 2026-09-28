// Densidad de escritorio (USB-013): hover, cursor y foco visibles, y tope
// de ancho que no le quita la rueda del mouse a los márgenes.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sistema_bs/core/widgets/hover_ink_well.dart';
import 'package:sistema_bs/core/widgets/readable_width.dart';

Widget _opaqueTile(String label) => Container(
      width: 200,
      height: 48,
      color: const Color(0xFF161B22),
      child: Text(label),
    );

Decoration _overlay(WidgetTester tester, String label) {
  final box = tester.widget<DecoratedBox>(find.descendant(
    of: find.ancestor(of: find.text(label), matching: find.byType(HoverInkWell)),
    matching: find.byWidgetPredicate(
        (w) => w is DecoratedBox && w.position == DecorationPosition.foreground),
  ));
  return box.decoration;
}

void main() {
  group('HoverInkWell', () {
    // El cursor de mano no se puede afirmar aquí: InkWell usa el cursor
    // adaptativo, que solo es `click` con kIsWeb, y los tests corren en la VM.
    testWidgets('realce de hover visible sobre un hijo opaco', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: HoverInkWell(
              onTap: () {},
              borderRadius: BorderRadius.circular(8),
              child: _opaqueTile('fila'),
            ),
          ),
        ),
      ));
      expect((_overlay(tester, 'fila') as BoxDecoration).color!.a, 0);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse, pointer: 1);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.text('fila')));
      await tester.pumpAndSettle();

      expect((_overlay(tester, 'fila') as BoxDecoration).color!.a, greaterThan(0));
    });

    testWidgets('se enfoca con Tab, muestra el foco y se activa con Enter', (tester) async {
      var taps = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: HoverInkWell(
              onTap: () => taps++,
              borderRadius: BorderRadius.circular(8),
              child: _opaqueTile('fila'),
            ),
          ),
        ),
      ));

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect((_overlay(tester, 'fila') as BoxDecoration).border, isNotNull);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('focusable: false queda fuera del recorrido con Tab', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Column(children: [
            HoverInkWell(
              onTap: () {},
              borderRadius: BorderRadius.circular(8),
              focusable: false,
              child: _opaqueTile('menos'),
            ),
            const TextField(key: Key('cantidad')),
          ]),
        ),
      ));

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      final field = tester.widget<EditableText>(find.descendant(
          of: find.byKey(const Key('cantidad')), matching: find.byType(EditableText)));
      expect(field.focusNode.hasFocus, isTrue);
    });
  });

  group('ReadableListView', () {
    Future<void> pump(WidgetTester tester, double width) async {
      tester.view.physicalSize = Size(width, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ReadableListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (var i = 0; i < 40; i++)
                SizedBox(height: 48, child: Text('item $i')),
            ],
          ),
        ),
      ));
    }

    testWidgets('en un monitor ancho el contenido no pasa del tope', (tester) async {
      await pump(tester, 1920);
      final item = tester.getRect(find.ancestor(
          of: find.text('item 0'), matching: find.byType(SizedBox)).first);
      expect(item.width, lessThanOrEqualTo(720));
      expect(item.center.dx, closeTo(960, 1));
    });

    testWidgets('en una ventana angosta usa todo el ancho menos el padding', (tester) async {
      await pump(tester, 500);
      final item = tester.getRect(find.ancestor(
          of: find.text('item 0'), matching: find.byType(SizedBox)).first);
      expect(item.width, 500 - 32);
    });

    testWidgets('la rueda del mouse funciona sobre el margen vacío', (tester) async {
      await pump(tester, 1920);
      final position = tester.state<ScrollableState>(find.byType(Scrollable)).position;
      expect(position.pixels, 0);

      // x = 40: muy a la izquierda de la columna de 720 px centrada en 960.
      final mouse = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(mouse.hover(const Offset(40, 300)));
      await tester.sendEventToBinding(mouse.scroll(const Offset(0, 300)));
      await tester.pumpAndSettle();

      expect(position.pixels, greaterThan(0));
    });
  });
}
