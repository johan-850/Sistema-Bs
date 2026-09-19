// Retomar un cierre que quedó a medias (USB-039).
//
// La pantalla de turno ahora ofrece "Terminar el cierre" cuando la caja
// está en 'closing'. Ese botón abría el asistente en el paso 0, cuyo
// único botón llama a start_register_closing() — y esa función exige
// status='open'. Resultado: el cajero recibía "Esta caja ya no está
// abierta" y no podía pasar del paso 0. Nunca. La caja quedaba
// bloqueada igual que antes, solo que ahora sí la veía.
//
// El repositorio falso de abajo copia esa regla del servidor a
// propósito: si el asistente vuelve a llamar a startClosing() sobre una
// caja en 'closing', falla. Así el test detecta la regresión de verdad
// y no solo mira un número de paso.

import 'package:flutter_test/flutter_test.dart';
import 'package:sistema_bs/core/errors/failures.dart';
import 'package:sistema_bs/features/cash_register/domain/entities/cash_register.dart';
import 'package:sistema_bs/features/cash_register/domain/repositories/cash_register_repository.dart';
import 'package:sistema_bs/features/cash_register/domain/use_cases/cash_register_use_cases.dart';
import 'package:sistema_bs/features/cash_register/presentation/providers/cash_register_providers.dart';

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

/// Repositorio falso con la misma regla que start_register_closing().
class _FakeRepo implements CashRegisterRepository {
  String status;
  int startClosingCalls = 0;

  _FakeRepo(this.status);

  @override
  Future<CashRegisterResult> startClosing(String registerId) async {
    startClosingCalls++;
    if (status != 'open') {
      return (register: null, failure: const ServerFailure('Esta caja ya no está abierta'));
    }
    status = 'closing';
    return (register: _caja('closing'), failure: null);
  }

  @override
  Future<ClosingPreviewResult> getClosingPreview({
    required String registerId,
    required double openingAmount,
  }) async =>
      (
        preview: (
          salesTotal: 50000.0,
          expensesTotal: 10000.0,
          expectedCash: 140000.0,
          transactionCount: 3,
        ),
        failure: null,
      );

  // El resto del contrato no participa en este flujo.
  @override
  Future<CashRegisterResult> getActiveRegister(String cashierId) =>
      throw UnimplementedError();
  @override
  Future<CashRegisterResult> openRegister({
    required String cashierId,
    required Map<String, int> openingBreakdown,
    required double openingAmount,
    String? notes,
  }) =>
      throw UnimplementedError();
  @override
  Future<CashRegisterListResult> getRegisterHistory({
    String? cashierId,
    DateTime? from,
    DateTime? to,
    int page = 0,
    int pageSize = 20,
  }) =>
      throw UnimplementedError();
  @override
  Future<CashRegisterResult> closeRegister({
    required String registerId,
    required Map<String, int> closingBreakdown,
    required double closingAmount,
    String? closingNotes,
  }) async =>
      (register: _caja('closed'), failure: null);
}

RegisterClosingNotifier _notifier(_FakeRepo repo, {required bool alreadyClosing}) =>
    RegisterClosingNotifier(
      GetClosingPreviewUseCase(repo),
      StartRegisterClosingUseCase(repo),
      CloseRegisterUseCase(repo),
      'r1',
      100000,
      alreadyClosing: alreadyClosing,
    );

void main() {
  group('empezar un cierre desde cero', () {
    test('arranca en el resumen, sin haber tocado el servidor', () {
      final repo = _FakeRepo('open');
      final n = _notifier(repo, alreadyClosing: false);

      expect(n.state.currentStep, 0);
      expect(n.state.started, isFalse);
      expect(repo.startClosingCalls, 0);
    });

    test('confirmar el inicio bloquea la caja y pasa al conteo', () async {
      final repo = _FakeRepo('open');
      final n = _notifier(repo, alreadyClosing: false);

      expect(await n.confirmStart(), isTrue);
      expect(n.state.started, isTrue);
      expect(n.state.currentStep, 1);
      expect(repo.status, 'closing');
    });
  });

  group('retomar un cierre a medias', () {
    test('entra directo al conteo, sin pasar por el paso que lo bloqueaba', () {
      final repo = _FakeRepo('closing');
      final n = _notifier(repo, alreadyClosing: true);

      // Esto es lo que fallaba: arrancaba en 0 y el paso 0 no tenía
      // salida, porque su único botón llama a startClosing().
      expect(n.state.currentStep, 1);
      expect(n.state.started, isTrue);
      expect(repo.startClosingCalls, 0);
    });

    test('y si lo llamara, el servidor lo rechazaría y dejaría el paso en 0',
        () async {
      // Este es el comportamiento viejo, reproducido a mano: sirve de
      // prueba de que la regla del servidor es real y de por qué el
      // asistente no puede empezar en el paso 0 al retomar.
      final repo = _FakeRepo('closing');
      final n = _notifier(repo, alreadyClosing: false);

      expect(await n.confirmStart(), isFalse);
      expect(n.state.failure?.message, 'Esta caja ya no está abierta');
      expect(n.state.currentStep, 0);
    });
  });

  test('el cuadre se puede confirmar tras retomar', () async {
    final repo = _FakeRepo('closing');
    final n = _notifier(repo, alreadyClosing: true);

    n.setQuantity('bill_10000', 14);
    expect(await n.confirmClose(), isTrue);
    expect(n.state.success, isTrue);
  });
}
