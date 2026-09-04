// ============================================================
// lib/features/pos/presentation/pages/cart_page.dart
// Carrito de venta — US-027, US-028
// Sin botón de cobro todavía (se agrega en S-06).
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/stock_tier.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/confirmation_dialog.dart';
import '../../../../core/widgets/product_thumbnail.dart';
import '../../../cash_register/presentation/providers/cash_register_providers.dart';
import '../../domain/entities/cart_item.dart';
import '../providers/cart_providers.dart';
import '../providers/checkout_provider.dart' show logCancelledSaleUseCaseProvider;
import 'checkout_page.dart';

class CartPage extends ConsumerWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cartProvider);
    final notifier = ref.read(cartProvider.notifier);
    final currencyFmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    final registerId = ref.watch(activeRegisterProvider).valueOrNull?.id;

    ref.listen<CartState>(cartProvider, (_, next) {
      if (next.warningMessage != null) {
        AppSnackbar.warning(context, next.warningMessage!);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Carrito')),
      body: state.items.isEmpty
          ? const Center(
              child: Text('El carrito está vacío', style: TextStyle(color: AppColors.textSecondary)),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: state.items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final item = state.items[i];
                return _CartItemTile(
                  item: item,
                  currencyFmt: currencyFmt,
                  onIncrement: () => notifier.updateQuantity(item.productId, item.quantity + 1),
                  onDecrement: () {
                    if (item.quantity <= 1) {
                      _confirmRemove(context, notifier, item);
                    } else {
                      notifier.updateQuantity(item.productId, item.quantity - 1);
                    }
                  },
                  onQuantityChanged: (qty) {
                    if (qty <= 0) {
                      _confirmRemove(context, notifier, item);
                    } else {
                      notifier.updateQuantity(item.productId, qty);
                    }
                  },
                  onRemove: () => _confirmRemove(context, notifier, item),
                );
              },
            ),
      bottomNavigationBar: state.items.isEmpty
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceCard,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${state.totalItems} ítem${state.totalItems == 1 ? '' : 's'}',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                        Text(
                          currencyFmt.format(state.totalAmount),
                          style: const TextStyle(
                              color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.error,
                                side: const BorderSide(color: AppColors.error),
                              ),
                              onPressed: () => _confirmCancel(context, ref, notifier, state, registerId),
                              icon: const Icon(Icons.delete_sweep_outlined),
                              label: const Text('Cancelar'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const CheckoutPage()),
                              ),
                              icon: const Icon(Icons.point_of_sale_rounded),
                              label: const Text('Cobrar'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _confirmRemove(BuildContext context, CartNotifier notifier, CartItem item) {
    return ConfirmationDialog.show(
      context,
      title: 'Eliminar producto',
      message: '¿Eliminar "${item.name}" del carrito?',
      confirmLabel: 'Eliminar',
      isDangerous: true,
      onConfirm: () => notifier.removeItem(item.productId),
    );
  }

  /// US-032: "Cancelar venta" — nada se había descontado de stock
  /// todavía (eso solo ocurre al confirmar el cobro), así que cancelar
  /// es simplemente vaciar el carrito. Queda un registro de auditoría
  /// del intento cancelado antes de limpiar el estado.
  Future<void> _confirmCancel(
    BuildContext context,
    WidgetRef ref,
    CartNotifier notifier,
    CartState state,
    String? registerId,
  ) {
    return ConfirmationDialog.show(
      context,
      title: 'Cancelar venta',
      message: '¿Seguro que quieres cancelar esta venta y quitar todos los productos del carrito?',
      confirmLabel: 'Cancelar venta',
      isDangerous: true,
      onConfirm: () {
        if (registerId != null) {
          ref.read(logCancelledSaleUseCaseProvider)(
            cashRegisterId: registerId,
            itemsCount: state.totalItems,
            totalAmount: state.totalAmount,
          );
        }
        notifier.clear();
      },
    );
  }
}

class _CartItemTile extends StatefulWidget {
  final CartItem item;
  final NumberFormat currencyFmt;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback onRemove;

  const _CartItemTile({
    required this.item,
    required this.currencyFmt,
    required this.onIncrement,
    required this.onDecrement,
    required this.onQuantityChanged,
    required this.onRemove,
  });

  @override
  State<_CartItemTile> createState() => _CartItemTileState();
}

class _CartItemTileState extends State<_CartItemTile> {
  late final TextEditingController _qtyController;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _qtyController = TextEditingController(text: '${widget.item.quantity}');
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) _submit();
    });
  }

  @override
  void didUpdateWidget(covariant _CartItemTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.quantity != widget.item.quantity && !_focusNode.hasFocus) {
      _qtyController.text = '${widget.item.quantity}';
    }
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final qty = int.tryParse(_qtyController.text);
    if (qty == null) {
      _qtyController.text = '${widget.item.quantity}';
      return;
    }
    widget.onQuantityChanged(qty);
  }

  @override
  Widget build(BuildContext context) {
    // US-059: se recalcula con cada cambio de cantidad — si el cajero sube
    // la cantidad de este ítem, la tarjeta se va poniendo amarilla/roja en
    // vivo a medida que se acerca (o llega) al stock mínimo del producto.
    final tier = stockTierFor(remainingStock: widget.item.remainingStock, minStock: widget.item.minStock);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tier.backgroundTint ?? AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tier.accentColor, width: tier == StockTier.normal ? 1 : 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProductThumbnail(imageUrl: widget.item.imageUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (tier != StockTier.normal) ...[
                      Icon(Icons.warning_rounded, size: 14, color: tier.accentColor),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: Text(widget.item.name,
                          style: const TextStyle(
                              color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${widget.currencyFmt.format(widget.item.unitPrice)} c/u',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                if (tier != StockTier.normal) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.item.remainingStock <= 0
                        ? 'Quedarían 0 en stock'
                        : 'Quedarían ${widget.item.remainingStock} en stock',
                    style: TextStyle(color: tier.accentColor, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    _StepButton(icon: Icons.remove_rounded, onTap: widget.onDecrement),
                    SizedBox(
                      width: 44,
                      height: 32,
                      child: TextField(
                        controller: _qtyController,
                        focusNode: _focusNode,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 4),
                        ),
                        onSubmitted: (_) => _submit(),
                      ),
                    ),
                    _StepButton(icon: Icons.add_rounded, onTap: widget.onIncrement),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                widget.currencyFmt.format(widget.item.subtotal),
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              IconButton(
                tooltip: 'Eliminar',
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                onPressed: widget.onRemove,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _StepButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, size: 16, color: AppColors.primary),
      ),
    );
  }
}
