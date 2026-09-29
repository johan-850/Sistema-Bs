// Historial de ventas en tabla (USB-025): orden en el servidor y páginas.

import 'package:flutter_test/flutter_test.dart';
import 'package:sistema_bs/features/pos/domain/entities/sale.dart';
import 'package:sistema_bs/features/pos/domain/repositories/sale_repository.dart';
import 'package:sistema_bs/features/pos/domain/use_cases/sale_use_cases.dart';
import 'package:sistema_bs/features/pos/presentation/providers/sales_history_providers.dart';

typedef _Call = ({int page, int pageSize, SaleSort sortBy, bool ascending, String? cashierId});

class _FakeSales implements SaleRepository {
  _FakeSales(this.total);
  final int total;
  final calls = <_Call>[];

  @override
  Future<SalesHistoryResult> getSalesHistory({
    DateTime? dateFrom,
    DateTime? dateTo,
    String? cashierId,
    String? paymentMethod,
    double? minAmount,
    double? maxAmount,
    String? searchId,
    int page = 0,
    int pageSize = 20,
    SaleSort sortBy = SaleSort.date,
    bool ascending = false,
  }) async {
    calls.add((page: page, pageSize: pageSize, sortBy: sortBy, ascending: ascending, cashierId: cashierId));
    final start = page * pageSize;
    final count = (total - start).clamp(0, pageSize);
    final sales = [
      for (var i = 0; i < count; i++)
        Sale(id: 's${start + i}', total: 1000, paymentMethod: 'efectivo', createdAt: DateTime.utc(2026, 9, 1)),
    ];
    return (sales: sales, failure: null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<(SalesHistoryNotifier, _FakeSales)> _notifier(int total) async {
  final repo = _FakeSales(total);
  final notifier = SalesHistoryNotifier(GetSalesHistoryUseCase(repo));
  await Future<void>.delayed(Duration.zero); // carga inicial del constructor
  return (notifier, repo);
}

void main() {
  test('arranca por lo más reciente, en páginas de 50', () async {
    final (n, repo) = await _notifier(120);
    expect(repo.calls.single.sortBy, SaleSort.date);
    expect(repo.calls.single.ascending, isFalse);
    expect(repo.calls.single.pageSize, SalesHistoryNotifier.pageSize);
    expect(n.state.sales, hasLength(50));
    expect(n.state.hasNextPage, isTrue);
  });

  test('la última página no ofrece una siguiente', () async {
    final (n, _) = await _notifier(120);
    await n.nextPage();
    await n.nextPage();
    expect(n.state.currentPage, 2);
    expect(n.state.sales, hasLength(20));
    expect(n.state.hasNextPage, isFalse);
  });

  test('ordenar por otra columna empieza por el mayor y vuelve a la página 1', () async {
    final (n, repo) = await _notifier(120);
    await n.nextPage();
    await n.sort(SaleSort.total);
    expect(repo.calls.last, (page: 0, pageSize: 50, sortBy: SaleSort.total, ascending: false, cashierId: null));

    await n.sort(SaleSort.total);
    expect(repo.calls.last.ascending, isTrue);
  });

  test('aplicar o limpiar filtros conserva el orden elegido', () async {
    final (n, repo) = await _notifier(10);
    await n.sort(SaleSort.total);
    await n.applyFilters(cashierId: 'c1');
    expect(repo.calls.last.sortBy, SaleSort.total);
    expect(repo.calls.last.cashierId, 'c1');

    await n.clearFilters();
    expect(repo.calls.last.sortBy, SaleSort.total);
    expect(repo.calls.last.cashierId, isNull);
  });
}
