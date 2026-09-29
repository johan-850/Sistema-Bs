// Tabla de inventario (USB-020): filtro por alerta y orden en memoria.

import 'package:flutter_test/flutter_test.dart';
import 'package:sistema_bs/features/inventory/presentation/providers/inventory_providers.dart';
import 'package:sistema_bs/features/products/domain/entities/product.dart';
import 'package:sistema_bs/features/products/domain/repositories/product_repository.dart';
import 'package:sistema_bs/features/products/presentation/providers/product_providers.dart'
    show StockAlertFilter;

final _t = DateTime.utc(2026, 9, 29);

Product _p(String name, {int stock = 20, int minStock = 5, double price = 1000, String category = 'Abarrotes'}) =>
    Product(
      id: name,
      name: name,
      category: category,
      price: price,
      costPrice: price * 0.7,
      stock: stock,
      minStock: minStock,
      unit: 'unidad',
      isActive: true,
      createdAt: _t,
      updatedAt: _t,
    );

final _catalog = [
  _p('café', stock: 0, price: 9800),
  _p('Arroz', stock: 48, price: 2900),
  _p('Azúcar', stock: 3, price: 4600),
  _p('aceite', stock: 12, price: 11500, category: 'Aceites'),
];

List<String> _names(List<Product> ps) => [for (final p in ps) p.name];

void main() {
  test('por defecto ordena por nombre sin distinguir mayúsculas', () {
    final view = inventoryView(_catalog,
        filter: StockAlertFilter.all, sortBy: ProductSort.name, ascending: true);
    expect(_names(view), ['aceite', 'Arroz', 'Azúcar', 'café']);
  });

  test('bajo mínimo excluye los agotados, que tienen su propio filtro', () {
    final low = inventoryView(_catalog,
        filter: StockAlertFilter.low, sortBy: ProductSort.name, ascending: true);
    final out = inventoryView(_catalog,
        filter: StockAlertFilter.outOfStock, sortBy: ProductSort.name, ascending: true);
    expect(_names(low), ['Azúcar']);
    expect(_names(out), ['café']);
  });

  test('ordena por stock en ambas direcciones', () {
    final asc = inventoryView(_catalog,
        filter: StockAlertFilter.all, sortBy: ProductSort.stock, ascending: true);
    final desc = inventoryView(_catalog,
        filter: StockAlertFilter.all, sortBy: ProductSort.stock, ascending: false);
    expect(_names(asc), ['café', 'Azúcar', 'aceite', 'Arroz']);
    expect(_names(desc), ['Arroz', 'aceite', 'Azúcar', 'café']);
  });

  test('los empates se resuelven por nombre', () {
    // Descendente por categoría: Aceites antes que Abarrotes, y dentro de
    // Abarrotes los tres quedan por nombre ascendente.
    final view = inventoryView(_catalog,
        filter: StockAlertFilter.all, sortBy: ProductSort.category, ascending: false);
    expect(_names(view), ['aceite', 'Arroz', 'Azúcar', 'café']);
  });

  test('no modifica la lista original', () {
    final copy = [..._catalog];
    inventoryView(_catalog, filter: StockAlertFilter.all, sortBy: ProductSort.price, ascending: true);
    expect(_catalog, copy);
  });
}
