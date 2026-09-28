// Hojas emergentes a diálogos (USB-012).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sistema_bs/core/widgets/adaptive_sheet.dart';

Future<void> _pump(WidgetTester tester, Size size, WidgetBuilder sheet,
    {void Function(Object?)? onResult}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () async {
              final r = await showAdaptiveSheet<String>(context: context, builder: sheet);
              onResult?.call(r);
            },
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

Widget _form(BuildContext context) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Formulario'),
        const Checkbox(value: false, onChanged: null),
        const TextField(key: Key('primero')),
        const TextField(key: Key('segundo')),
        TextButton(
          onPressed: () => Navigator.pop(context, 'guardado'),
          child: const Text('guardar'),
        ),
      ],
    );

bool _hasFocus(WidgetTester tester, String key) {
  final editable = find.descendant(of: find.byKey(Key(key)), matching: find.byType(EditableText));
  return tester.widget<EditableText>(editable).focusNode.hasFocus;
}

void main() {
  testWidgets('en escritorio es un diálogo centrado', (tester) async {
    await _pump(tester, const Size(1366, 768), _form);
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);

    final rect = tester.getRect(find.byType(Dialog));
    expect(rect.center.dx, closeTo(683, 1));
    expect(tester.getSize(find.byType(TextField).first).width, lessThanOrEqualTo(560));
  });

  testWidgets('en ventana compacta sigue siendo hoja desde abajo', (tester) async {
    await _pump(tester, const Size(600, 800), _form);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('el foco entra al primer campo de texto', (tester) async {
    await _pump(tester, const Size(1366, 768), _form);
    expect(_hasFocus(tester, 'primero'), isTrue);
    expect(_hasFocus(tester, 'segundo'), isFalse);
  });

  testWidgets('Escape cierra el diálogo y devuelve null', (tester) async {
    Object? result = 'sin cerrar';
    await _pump(tester, const Size(1366, 768), _form, onResult: (r) => result = r);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing);
    expect(result, isNull);
  });

  testWidgets('el resultado llega igual que desde una hoja', (tester) async {
    Object? result;
    await _pump(tester, const Size(1366, 768), _form, onResult: (r) => result = r);

    await tester.tap(find.text('guardar'));
    await tester.pumpAndSettle();

    expect(result, 'guardado');
  });

  testWidgets('dentro del shell, cerrar con el context de la página cierra el diálogo', (tester) async {
    // Navegador anidado, como el del ShellRoute. El POS cierra la info del
    // turno con Navigator.pop(context) de la página, no del diálogo.
    tester.view.physicalSize = const Size(1366, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Navigator(
          onGenerateRoute: (_) => MaterialPageRoute(
            builder: (pageContext) => Scaffold(
              body: Column(children: [
                const Text('página del shell'),
                ElevatedButton(
                  onPressed: () => showAdaptiveSheet(
                    context: pageContext,
                    builder: (_) => TextButton(
                      onPressed: () => Navigator.pop(pageContext),
                      child: const Text('cerrar caja'),
                    ),
                  ),
                  child: const Text('abrir'),
                ),
              ]),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('cerrar caja'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing);
    expect(find.text('página del shell'), findsOneWidget);
  });

  testWidgets('sin campos de texto no falla ni enfoca nada raro', (tester) async {
    await _pump(
      tester,
      const Size(1366, 768),
      (_) => const Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(title: Text('Cámara')),
        ListTile(title: Text('Galería')),
      ]),
    );
    expect(find.text('Galería'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
