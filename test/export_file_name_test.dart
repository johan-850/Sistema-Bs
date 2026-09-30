// Nombres de archivo de las descargas (USB-028): fecha y filtros.

import 'package:flutter_test/flutter_test.dart';
import 'package:sistema_bs/core/utils/export_file_name.dart';

void main() {
  final day = DateTime(2026, 9, 30, 15, 42);

  test('lleva la fecha y omite los filtros vacíos', () {
    expect(exportFileName('cajeros', 'csv', date: day), 'cajeros_2026-09-30.csv');
    expect(exportFileName('ventas', 'pdf', filters: [null, '', '  '], date: day), 'ventas_2026-09-30.pdf');
  });

  test('los filtros quedan en minúsculas, sin tildes ni espacios', () {
    expect(
      exportFileName('ventas', 'csv', filters: ['Andrés Pérez', 'efectivo', 'Bajo mínimo'], date: day),
      'ventas_2026-09-30_andres-perez_efectivo_bajo-minimo.csv',
    );
  });

  test('recibo: fecha de la venta y el comienzo del id', () {
    expect(
      receiptFileName('1a2b3c4d-5e6f-7a8b-9c0d-112233445566', DateTime(2026, 9, 28, 10, 5)),
      'recibo_2026-09-28_1a2b3c4d.pdf',
    );
    expect(receiptFileName('s7', DateTime(2026, 9, 28)), 'recibo_2026-09-28_s7.pdf');
  });

  test('rango de fechas', () {
    final from = DateTime(2026, 9, 1);
    final to = DateTime(2026, 9, 15, 23, 59, 59);
    expect(dateRangeLabel(null, null), isNull);
    expect(dateRangeLabel(from, to), '2026-09-01 a 2026-09-15');
    expect(dateRangeLabel(from, null), 'desde 2026-09-01');
    expect(dateRangeLabel(null, to), 'hasta 2026-09-15');
    expect(
      exportFileName('gastos', 'csv', filters: [dateRangeLabel(from, to)], date: day),
      'gastos_2026-09-30_2026-09-01-a-2026-09-15.csv',
    );
  });
}
