import 'package:intl/intl.dart';

final _day = DateFormat('yyyy-MM-dd');

const _accents = {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n'};

String _slug(String value) {
  final plain = value.toLowerCase().split('').map((c) => _accents[c] ?? c).join();
  return plain.replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
}

/// USB-028: `base_fecha_filtro1_filtro2.ext`, para distinguir descargas
/// del mismo reporte con filtros distintos. Los filtros vacíos se omiten.
String exportFileName(String base, String extension, {List<String?> filters = const [], DateTime? date}) {
  final parts = [
    base,
    _day.format(date ?? DateTime.now()),
    for (final f in filters)
      if (f != null && _slug(f).isNotEmpty) _slug(f),
  ];
  return '${parts.join('_')}.$extension';
}

/// Recibo: fecha de la venta y el comienzo de su id, que basta para ubicarla.
String receiptFileName(String saleId, DateTime createdAt) => exportFileName(
      'recibo',
      'pdf',
      filters: [saleId.length > 8 ? saleId.substring(0, 8) : saleId],
      date: createdAt.toLocal(),
    );

/// Rango de fechas de un filtro para el nombre de archivo; null sin filtro.
String? dateRangeLabel(DateTime? from, DateTime? to) {
  if (from == null && to == null) return null;
  if (from == null) return 'hasta ${_day.format(to!)}';
  if (to == null) return 'desde ${_day.format(from)}';
  return '${_day.format(from)} a ${_day.format(to)}';
}
