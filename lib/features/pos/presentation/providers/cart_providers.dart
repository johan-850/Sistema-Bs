// ============================================================
// lib/features/pos/presentation/providers/cart_providers.dart
// Estado del carrito de venta — US-025 a US-028
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/cart_item.dart';
import '../../../products/domain/entities/product.dart';

/// US-059: info mínima para mostrar el banner de stock bajo y
/// registrar la alerta — se resuelve en la capa de presentación
/// (el notifier no toca la red).
typedef LowStockAlert = ({String productId, String productName, int stock});

class CartState {
  final List<CartItem> items;
  final String? warningMessage;
  final LowStockAlert? lowStockAlert;

  const CartState({this.items = const [], this.warningMessage, this.lowStockAlert});

  int get totalItems => items.fold(0, (sum, i) => sum + i.quantity);
  double get totalAmount => items.fold(0.0, (sum, i) => sum + i.subtotal);
  bool get isEmpty => items.isEmpty;

  CartState copyWith({
    List<CartItem>? items,
    String? warningMessage,
    bool clearWarning = false,
    LowStockAlert? lowStockAlert,
    bool clearLowStockAlert = false,
  }) =>
      CartState(
        items: items ?? this.items,
        warningMessage: clearWarning ? null : (warningMessage ?? this.warningMessage),
        lowStockAlert: clearLowStockAlert ? null : (lowStockAlert ?? this.lowStockAlert),
      );
}

class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(const CartState());

  /// US-025/US-026/US-033: agrega un producto (o incrementa su cantidad si
  /// ya está en el carrito). Nunca deja superar el stock disponible ni
  /// agregar productos agotados — es la única validación de negocio que
  /// tiene sentido hacer client-side hasta que exista el cobro (S-06).
  void addProduct(Product product, {int quantity = 1}) {
    if (product.isOutOfStock) {
      state = state.copyWith(warningMessage: '"${product.name}" está agotado.');
      return;
    }

    final lowStockAlert = product.isLowStock
        ? (productId: product.id, productName: product.name, stock: product.stock)
        : null;

    final index = state.items.indexWhere((i) => i.productId == product.id);

    if (index == -1) {
      final qty = quantity > product.stock ? product.stock : quantity;
      final item = CartItem(
        productId: product.id,
        name: product.name,
        barcode: product.barcode,
        imageUrl: product.imageUrl,
        unitPrice: product.price,
        unit: product.unit,
        quantity: qty,
        availableStock: product.stock,
        minStock: product.minStock,
      );
      state = state.copyWith(
        items: [...state.items, item],
        clearWarning: true,
        lowStockAlert: lowStockAlert,
        clearLowStockAlert: lowStockAlert == null,
      );
      return;
    }

    final existing = state.items[index];
    final desiredQty = existing.quantity + quantity;

    if (desiredQty > existing.availableStock) {
      state = state.copyWith(
        items: _replaceQuantity(existing.productId, existing.availableStock),
        warningMessage:
            'Solo hay ${existing.availableStock} ${existing.unit} disponibles de "${existing.name}".',
      );
      return;
    }

    state = state.copyWith(
      items: _replaceQuantity(existing.productId, desiredQty),
      clearWarning: true,
      lowStockAlert: lowStockAlert,
      clearLowStockAlert: lowStockAlert == null,
    );
  }

  /// US-028: ajusta la cantidad de un ítem ya en el carrito.
  /// [quantity] debe ser > 0 — bajar a 0 se maneja en la UI (confirmación
  /// antes de llamar [removeItem]), no en el notifier.
  void updateQuantity(String productId, int quantity) {
    if (quantity <= 0) return;

    final index = state.items.indexWhere((i) => i.productId == productId);
    if (index == -1) return;
    final item = state.items[index];

    if (quantity > item.availableStock) {
      state = state.copyWith(
        items: _replaceQuantity(productId, item.availableStock),
        warningMessage:
            'Solo hay ${item.availableStock} ${item.unit} disponibles de "${item.name}".',
      );
      return;
    }

    state = state.copyWith(items: _replaceQuantity(productId, quantity), clearWarning: true);
  }

  void removeItem(String productId) {
    state = state.copyWith(
      items: state.items.where((i) => i.productId != productId).toList(),
      clearWarning: true,
    );
  }

  void clear() => state = const CartState();

  List<CartItem> _replaceQuantity(String productId, int quantity) => [
        for (final i in state.items)
          i.productId == productId ? i.copyWith(quantity: quantity) : i,
      ];
}

final cartProvider = StateNotifierProvider<CartNotifier, CartState>(
  (ref) => CartNotifier(),
);
