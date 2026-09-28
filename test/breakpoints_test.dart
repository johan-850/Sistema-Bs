// Puntos de quiebre (USB-010): compacto < 768, medio 768–1279,
// expandido ≥ 1280. Los bordes son lo que importa.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sistema_bs/core/theme/breakpoints.dart';

void main() {
  group('Breakpoints.of en los bordes', () {
    final casos = {
      0.0: Breakpoint.compact,
      767.9: Breakpoint.compact,
      768.0: Breakpoint.medium,
      1279.9: Breakpoint.medium,
      1280.0: Breakpoint.expanded,
      1920.0: Breakpoint.expanded,
    };
    casos.forEach((ancho, esperado) {
      test('$ancho px → ${esperado.name}', () {
        expect(Breakpoints.of(ancho), esperado);
      });
    });
  });

  testWidgets('la extensión lee el ancho de la ventana', (tester) async {
    late Breakpoint leido;
    late bool compacto, medio, expandido;

    Future<void> conAncho(double ancho) async {
      await tester.pumpWidget(MediaQuery(
        data: MediaQueryData(size: Size(ancho, 800)),
        child: Builder(builder: (context) {
          leido = context.breakpoint;
          compacto = context.isCompact;
          medio = context.isMedium;
          expandido = context.isExpanded;
          return const SizedBox();
        }),
      ));
    }

    await conAncho(400);
    expect(leido, Breakpoint.compact);
    expect([compacto, medio, expandido], [true, false, false]);

    await conAncho(1024);
    expect(leido, Breakpoint.medium);
    expect([compacto, medio, expandido], [false, true, false]);

    await conAncho(1366);
    expect(leido, Breakpoint.expanded);
    expect([compacto, medio, expandido], [false, false, true]);
  });
}
