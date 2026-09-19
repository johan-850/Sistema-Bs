// Estados de la caja y la condición que decide qué ve el cajero al
// entrar (bug del "turno activo", USB-039).
//
// El portón de cash_register_opening_page usa `!register.isClosed` para
// decidir entre mostrar el turno o el formulario de apertura. Antes
// preguntaba `isOpen`, y por eso una caja en 'closing' —un cierre que
// quedó a medias— era invisible: el cajero no la podía retomar ni
// cerrar, y terminaba abriendo otra. Eso es lo que dejaba dos cajas
// abiertas y hacía que al cerrar una siguiera apareciendo "turno
// activo" por la otra.

import 'package:flutter_test/flutter_test.dart';
import 'package:sistema_bs/features/cash_register/domain/entities/cash_register.dart';

CashRegister _caja(String status) => CashRegister(
      id: 'r1',
      cashierId: 'c1',
      openingAmount: 100000,
      openingBreakdown: const {'bill_10000': 10},
      openingTime: DateTime.utc(2026, 9, 9, 15),
      status: status,
      createdAt: DateTime.utc(2026, 9, 9, 15),
      updatedAt: DateTime.utc(2026, 9, 9, 15),
    );

/// La condición del portón, tal cual la usa la pantalla de apertura.
bool muestraTurno(CashRegister r) => !r.isClosed;

void main() {
  group('los tres estados se distinguen entre sí', () {
    test('open', () {
      final r = _caja('open');
      expect(r.isOpen, isTrue);
      expect(r.isClosing, isFalse);
      expect(r.isClosed, isFalse);
    });

    test('closing', () {
      final r = _caja('closing');
      expect(r.isOpen, isFalse);
      expect(r.isClosing, isTrue);
      expect(r.isClosed, isFalse);
    });

    test('closed', () {
      final r = _caja('closed');
      expect(r.isOpen, isFalse);
      expect(r.isClosing, isFalse);
      expect(r.isClosed, isTrue);
    });
  });

  group('qué ve el cajero al entrar', () {
    test('con la caja abierta ve su turno', () {
      expect(muestraTurno(_caja('open')), isTrue);
    });

    test('con un cierre a medias TAMBIÉN ve su turno, para poder retomarlo', () {
      // Este es el caso que estaba roto: con `isOpen` daba false y la
      // app le ofrecía abrir una caja nueva teniendo una sin cerrar.
      expect(muestraTurno(_caja('closing')), isTrue);
    });

    test('con la caja cerrada ve el formulario de apertura', () {
      expect(muestraTurno(_caja('closed')), isFalse);
    });
  });
}
