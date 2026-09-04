// Reemplaza la plantilla default de `flutter create` (widget_test.dart),
// que probaba un MyApp/contador que nunca existió en este proyecto y
// nunca se adaptó — quedaba roto en `flutter analyze`.
//
// Un test que monte la app real no es viable aquí: SistemaBsApp depende
// de appRouterProvider, que observa el stream de auth y de
// Supabase.instance — sin Supabase.initialize() (que necesita
// credenciales reales) explota antes de renderizar nada. Validators es
// lógica pura, así que sí se puede probar de verdad sin esa dependencia.

import 'package:flutter_test/flutter_test.dart';
import 'package:sistema_bs/core/utils/validators.dart';

void main() {
  group('Validators.email', () {
    test('rechaza vacío', () {
      expect(Validators.email(''), isNotNull);
    });

    test('rechaza sin arroba', () {
      expect(Validators.email('correo.sin.arroba.com'), isNotNull);
    });

    test('acepta un correo válido', () {
      expect(Validators.email('admin@sistema-bs.com'), isNull);
    });
  });

  group('Validators.password', () {
    test('rechaza vacío', () {
      expect(Validators.password(''), isNotNull);
    });

    test('rechaza menor al mínimo', () {
      expect(Validators.password('123'), isNotNull);
    });

    test('acepta una contraseña válida', () {
      expect(Validators.password('contraseña123'), isNull);
    });
  });

  group('Validators.requiredText', () {
    test('rechaza vacío', () {
      expect(Validators.requiredText(''), isNotNull);
    });

    test('acepta texto no vacío', () {
      expect(Validators.requiredText('algo'), isNull);
    });
  });

  group('Validators.name', () {
    test('rechaza vacío', () {
      expect(Validators.name(''), isNotNull);
    });

    test('rechaza si excede el máximo', () {
      expect(Validators.name('a' * 200), isNotNull);
    });

    test('acepta un nombre válido', () {
      expect(Validators.name('Juan Pérez'), isNull);
    });
  });
}
