// Historial de cajas en tabla (USB-024): filtros reemplazables y páginas.

import 'package:flutter_test/flutter_test.dart';
import 'package:sistema_bs/features/cash_register/domain/entities/cash_register.dart';
import 'package:sistema_bs/features/cash_register/domain/repositories/cash_register_repository.dart';
import 'package:sistema_bs/features/cash_register/domain/use_cases/cash_register_use_cases.dart';
import 'package:sistema_bs/features/cash_register/presentation/providers/cash_register_providers.dart';

typedef _Call = ({String? cashierId, DateTime? from, int page, int pageSize});

class _FakeRegisters implements CashRegisterRepository {
  _FakeRegisters(this.total);
  final int total;
  final calls = <_Call>[];

  @override
  Future<CashRegisterListResult> getRegisterHistory({
    String? cashierId,
    DateTime? from,
    DateTime? to,
    int page = 0,
    int pageSize = 20,
  }) async {
    calls.add((cashierId: cashierId, from: from, page: page, pageSize: pageSize));
    final start = page * pageSize;
    final count = (total - start).clamp(0, pageSize);
    final t = DateTime.utc(2026, 9, 1);
    return (
      registers: [
        for (var i = 0; i < count; i++)
          CashRegister(
            id: 'r${start + i}',
            cashierId: 'c1',
            openingAmount: 100000,
            openingBreakdown: const {},
            openingTime: t,
            status: 'closed',
            createdAt: t,
            updatedAt: t,
          ),
      ],
      failure: null,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<(RegisterHistoryNotifier, _FakeRegisters)> _notifier(int total) async {
  final repo = _FakeRegisters(total);
  final notifier = RegisterHistoryNotifier(GetRegisterHistoryUseCase(repo));
  await Future<void>.delayed(Duration.zero); // carga inicial del constructor
  return (notifier, repo);
}

void main() {
  test('pide páginas de 50 y sabe cuándo hay otra', () async {
    final (n, repo) = await _notifier(60);
    expect(repo.calls.single.pageSize, RegisterHistoryNotifier.pageSize);
    expect(n.state.hasNextPage, isTrue);

    await n.nextPage();
    expect(repo.calls.last.page, 1);
    expect(n.state.registers, hasLength(10));
    expect(n.state.hasNextPage, isFalse);
  });

  test('setFilters puede volver el cajero a "todos"', () async {
    final (n, repo) = await _notifier(5);
    final from = DateTime(2026, 9, 1);

    await n.setFilters(cashierId: 'c1', from: from);
    expect(repo.calls.last.cashierId, 'c1');
    expect(n.state.hasActiveFilters, isTrue);

    // applyFilters(cashierId: null) conservaría 'c1'; setFilters no.
    await n.setFilters(cashierId: null, from: from);
    expect(repo.calls.last.cashierId, isNull);
    expect(repo.calls.last.from, from);
    expect(repo.calls.last.page, 0);
  });
}
