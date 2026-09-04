// ============================================================
// lib/core/utils/expense_category_icons.dart
// Mapeo de nombre de ícono (guardado en expense_categories.icon)
// a IconData de Material — US-036
// ============================================================

import 'package:flutter/material.dart';

/// Opciones fijas de ícono que el AdminMaster puede elegir al crear o
/// editar una categoría de gasto. La clave es lo que se guarda en la
/// columna `icon` de `expense_categories`.
const Map<String, IconData> expenseCategoryIconOptions = {
  'bolt_outlined': Icons.bolt_outlined,
  'shopping_cart_outlined': Icons.shopping_cart_outlined,
  'more_horiz_rounded': Icons.more_horiz_rounded,
  'local_shipping_outlined': Icons.local_shipping_outlined,
  'build_outlined': Icons.build_outlined,
  'cleaning_services_outlined': Icons.cleaning_services_outlined,
  'restaurant_outlined': Icons.restaurant_outlined,
  'local_gas_station_outlined': Icons.local_gas_station_outlined,
  'wifi_outlined': Icons.wifi_outlined,
  'receipt_long_outlined': Icons.receipt_long_outlined,
};

const IconData _defaultExpenseCategoryIcon = Icons.receipt_long_outlined;

/// Resuelve el nombre guardado a un [IconData]; si no se reconoce
/// (ej. quedó de una versión anterior de la lista), usa un ícono
/// genérico en vez de fallar.
IconData expenseCategoryIconFor(String name) =>
    expenseCategoryIconOptions[name] ?? _defaultExpenseCategoryIcon;
