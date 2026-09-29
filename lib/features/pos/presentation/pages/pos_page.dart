// ============================================================
// lib/features/pos/presentation/pages/pos_page.dart
// Punto de Venta — US-025, US-026, US-033
// (cobro/descuentos/recibo quedan para S-06)
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/breakpoints.dart';
import '../../../../core/widgets/app_page_bar.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/scan_feedback_providers.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/utils/stock_tier.dart';
import '../../../../core/widgets/adaptive_sheet.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/hover_ink_well.dart';
import '../../../../core/widgets/product_thumbnail.dart';
import '../../../../core/widgets/barcode_scanner_page.dart';
import '../../../cash_register/domain/entities/cash_register.dart';
import '../../../cash_register/presentation/providers/cash_register_providers.dart';
import '../../../products/domain/entities/product.dart';
import '../../../products/presentation/providers/product_providers.dart'
    show getProductByBarcodeUseCaseProvider;
import '../providers/cart_providers.dart';
import '../providers/checkout_provider.dart' show logLowStockAlertUseCaseProvider;
import '../providers/pos_catalog_provider.dart';
import '../widgets/cart_panel.dart';

class PosPage extends ConsumerStatefulWidget {
  const PosPage({super.key});

  @override
  ConsumerState<PosPage> createState() => _PosPageState();
}

class _PosPageState extends ConsumerState<PosPage> {
  final _searchController = TextEditingController();
  final _priceFmt = NumberFormat('#,###', 'es_CO');

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeRegisterAsync = ref.watch(activeRegisterProvider);

    return activeRegisterAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      ),
      error: (_, _) => const Scaffold(
        body: Center(
          child: Text('Error al verificar la caja activa', style: TextStyle(color: AppColors.error)),
        ),
      ),
      data: (register) {
        if (register == null || !register.isOpen) {
          return _NoOpenRegisterScaffold(
            onOpenRegister: () => context.go('/cash-register/opening'),
          );
        }
        return _buildPos(context, register);
      },
    );
  }

  Widget _buildPos(BuildContext context, CashRegister register) {
    final catalogState = ref.watch(posCatalogProvider);
    final catalogNotifier = ref.read(posCatalogProvider.notifier);
    final cartState = ref.watch(cartProvider);

    ref.listen<CartState>(cartProvider, (_, next) {
      if (next.warningMessage != null) {
        AppSnackbar.warning(context, next.warningMessage!);
      }
      // US-059: banner de stock bajo — no bloquea la venta, solo avisa.
      final alert = next.lowStockAlert;
      if (alert != null) {
        AppSnackbar.warning(
          context,
          'Stock bajo: "${alert.productName}" solo tiene ${alert.stock} ${alert.stock == 1 ? 'unidad' : 'unidades'}.',
        );
        ref.read(logLowStockAlertUseCaseProvider)(
          productId: alert.productId,
          productName: alert.productName,
          stock: alert.stock,
        );
      }
    });

    // USB-014: en escritorio el carrito queda siempre a la vista, al lado
    // del catálogo; en compacto sigue siendo una pantalla aparte.
    final compact = context.isCompact;
    int inCart(Product p) => cartState.items
        .where((item) => item.productId == p.id)
        .fold(0, (sum, item) => sum + item.quantity);
    void add(Product p) => ref.read(cartProvider.notifier).addProduct(p);

    final chips = [
      _CategoryChip(
        label: 'Todos',
        selected: catalogState.filterCategory == null,
        onTap: () => catalogNotifier.filterByCategory(null),
      ),
      for (final cat in AppConstants.productCategories)
        _CategoryChip(
          label: cat,
          selected: catalogState.filterCategory == cat,
          onTap: () => catalogNotifier.filterByCategory(cat),
        ),
    ];

    final Widget products;
    if (catalogState.isLoading) {
      products = const Center(child: CircularProgressIndicator(color: AppColors.primary));
    } else if (catalogState.products.isEmpty) {
      products = const Center(
        child: Text('Sin resultados', style: TextStyle(color: AppColors.textSecondary)),
      );
    } else if (compact) {
      products = ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        itemCount: catalogState.products.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final p = catalogState.products[i];
          return _VentaProductTile(
            product: p,
            quantityInCart: inCart(p),
            priceFmt: _priceFmt,
            onAdd: () => add(p),
          );
        },
      );
    } else {
      products = GridView.builder(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 210,
          mainAxisExtent: 136,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: catalogState.products.length,
        itemBuilder: (context, i) {
          final p = catalogState.products[i];
          return _ProductGridCard(
            product: p,
            quantityInCart: inCart(p),
            priceFmt: _priceFmt,
            onAdd: () => add(p),
          );
        },
      );
    }

    final catalog = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Buscador ──
        Padding(
          padding: compact
              ? const EdgeInsets.fromLTRB(16, 12, 16, 8)
              : const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: TextField(
            controller: _searchController,
            onChanged: catalogNotifier.search,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Buscar producto o código...',
              hintStyle: const TextStyle(color: AppColors.textDisabled),
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary),
              suffixIcon: compact
                  ? IconButton(
                      tooltip: 'Carrito',
                      icon: Badge(
                        isLabelVisible: cartState.totalItems > 0,
                        label: Text('${cartState.totalItems}'),
                        backgroundColor: AppColors.primary,
                        textColor: Colors.black,
                        child: const Icon(Icons.shopping_cart_outlined, color: AppColors.textSecondary),
                      ),
                      onPressed: () => context.go(AppRoutes.cart),
                    )
                  : null,
              filled: true,
              fillColor: AppColors.surfaceElevated,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
          ),
        ),

        // ── Chips de categoría ──
        // Con mouse una fila horizontal no se puede desplazar con la
        // rueda, así que en escritorio las categorías bajan de línea.
        if (compact)
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: chips.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => Center(child: chips[i]),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(spacing: 8, runSpacing: 8, children: chips),
          ),
        SizedBox(height: compact ? 8 : 16),

        // ── Productos ──
        Expanded(child: products),
      ],
    );

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppPageBar(
        title: 'Punto de venta',
        subtitle: 'Caja principal · turno desde '
            '${DateFormat('h:mm a', 'es').format(register.openingTime.toLocal())}',
        automaticallyImplyLeading: false,
        actions: [
          PageAction(
            icon: Icons.qr_code_scanner_rounded,
            label: 'Escanear',
            onPressed: _scanAndAdd,
          ),
          PageAction(
            icon: Icons.access_time_rounded,
            label: 'Turno',
            onPressed: () => _showShiftInfo(context, register),
          ),
        ],
      ),
      body: compact
          ? catalog
          : Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: catalog),
                Container(
                  width: context.isExpanded ? 400 : 340,
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceCard,
                    border: Border(left: BorderSide(color: AppColors.border)),
                  ),
                  child: const CartPanel(showHeader: true),
                ),
              ],
            ),
    );
  }

  void _showShiftInfo(BuildContext context, CashRegister register) {
    final dateFmt = DateFormat('dd/MM/yyyy hh:mm a', 'es');
    final currencyFmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    showAdaptiveSheet(
      context: context,
      maxWidth: 440,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Turno actual',
                style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 17)),
            const SizedBox(height: 16),
            _ShiftInfoRow(label: 'Apertura', value: dateFmt.format(register.openingTime.toLocal())),
            const SizedBox(height: 8),
            _ShiftInfoRow(label: 'Monto inicial', value: currencyFmt.format(register.openingAmount)),
            if (register.notes != null && register.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              _ShiftInfoRow(label: 'Notas', value: register.notes!),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  _goToClosing(context, register);
                },
                icon: const Icon(Icons.lock_clock_outlined),
                label: const Text('Cerrar caja'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _goToClosing(BuildContext context, CashRegister register) {
    context.push(AppRoutes.cashRegisterClosing, extra: register);
  }

  /// US-025: escanea con la cámara, busca el producto y lo agrega.
  /// US-057: confirma con sonido/vibración y dice qué se agregó.
  Future<void> _scanAndAdd() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerPage()),
    );
    if (code == null || !mounted) return;

    final result = await ref.read(getProductByBarcodeUseCaseProvider)(code);
    if (!mounted) return;

    final feedback = ref.read(scanFeedbackProvider);

    // La búsqueda por código siempre va a Supabase (no hay caché local),
    // así que un fallo de red no es lo mismo que un código sin registrar:
    // decirle "producto no encontrado" al cajero sin internet lo manda a
    // buscar un producto que sí existe.
    if (result.failure != null) {
      await feedback.failure();
      if (!mounted) return;
      AppSnackbar.error(context, 'No se pudo consultar el código: ${result.failure!.message}');
      return;
    }

    final product = result.product;
    if (product == null) {
      await feedback.failure();
      if (!mounted) return;
      AppSnackbar.error(context, 'El código $code no está registrado.');
      return;
    }

    if (!product.isActive) {
      await feedback.failure();
      if (!mounted) return;
      AppSnackbar.warning(context, '"${product.name}" está archivado y no se puede vender.');
      return;
    }

    await feedback.success();
    if (!mounted) return;
    ref.read(cartProvider.notifier).addProduct(product);
    AppSnackbar.success(context, '${product.name} agregado al carrito.');
  }
}

class _ShiftInfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _ShiftInfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
        ),
      ],
    );
  }
}

// ── Pantalla cuando no hay caja abierta ────────────────────────

class _NoOpenRegisterScaffold extends StatelessWidget {
  final VoidCallback onOpenRegister;
  const _NoOpenRegisterScaffold({required this.onOpenRegister});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const AppPageBar(title: 'Punto de venta'),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.point_of_sale_outlined, size: 56, color: AppColors.textDisabled),
              const SizedBox(height: 16),
              const Text(
                'Debes abrir caja antes de vender',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onOpenRegister,
                icon: const Icon(Icons.lock_open_rounded),
                label: const Text('Abrir caja'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Chip de categoría ───────────────────────────────────────────

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return HoverInkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.15) : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.primary : AppColors.border),
        ),
        // Sin alignment: con él, dentro de un Wrap el chip ocupa todo el
        // ancho disponible en vez de medir lo que su texto.
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            color: selected ? AppColors.primary : AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}

// ── Tarjeta de producto en la cuadrícula (escritorio) ───────────

/// Toda la tarjeta agrega el producto: con mouse no hace falta apuntarle
/// a un botón chico, y el semáforo de stock es el mismo de la fila.
class _ProductGridCard extends StatelessWidget {
  final Product product;
  final int quantityInCart;
  final NumberFormat priceFmt;
  final VoidCallback onAdd;

  const _ProductGridCard({
    required this.product,
    required this.quantityInCart,
    required this.priceFmt,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final remainingStock = product.stock - quantityInCart;
    final outOfStock = remainingStock <= 0;
    final tier = stockTierFor(remainingStock: remainingStock, minStock: product.minStock);
    final radius = BorderRadius.circular(12);

    return Tooltip(
      message: outOfStock ? 'Agotado' : 'Agregar al carrito',
      waitDuration: const Duration(milliseconds: 600),
      child: HoverInkWell(
        onTap: outOfStock ? null : onAdd,
        borderRadius: radius,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: tier.backgroundTint ?? AppColors.surfaceCard,
            borderRadius: radius,
            border: Border.all(color: tier.accentColor, width: tier == StockTier.normal ? 1 : 1.5),
          ),
          child: Opacity(
            opacity: outOfStock ? 0.55 : 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ProductThumbnail(imageUrl: product.imageUrl, size: 40),
                    const Spacer(),
                    if (quantityInCart > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '× $quantityInCart',
                          style: const TextStyle(
                              color: Colors.black, fontWeight: FontWeight.w700, fontSize: 12),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                    height: 1.25,
                  ),
                ),
                const Spacer(),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${priceFmt.format(product.price)}\$',
                      style: const TextStyle(
                          color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    const SizedBox(width: 8),
                    // El precio nunca se recorta; el stock cede si no cabe.
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (tier != StockTier.normal && !outOfStock) ...[
                            Icon(Icons.warning_rounded, size: 12, color: tier.accentColor),
                            const SizedBox(width: 3),
                          ],
                          Flexible(
                            child: Text(
                              outOfStock ? 'Agotado' : '$remainingStock ${product.unit}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: tier == StockTier.normal
                                    ? AppColors.textSecondary
                                    : tier.accentColor,
                                fontWeight: tier == StockTier.normal
                                    ? FontWeight.normal
                                    : FontWeight.bold,
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Fila de producto en "Ventas" ────────────────────────────────

class _VentaProductTile extends StatelessWidget {
  final Product product;
  final int quantityInCart;
  final NumberFormat priceFmt;
  final VoidCallback onAdd;

  const _VentaProductTile({
    required this.product,
    required this.quantityInCart,
    required this.priceFmt,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    // US-059: el stock "restante" descuenta lo que el cajero ya agregó al
    // carrito, para que la tarjeta se vaya poniendo amarilla/roja a medida
    // que se acerca (o llega) al mínimo mientras arma la venta — no hay que
    // esperar a confirmar el cobro para verlo.
    final remainingStock = product.stock - quantityInCart;
    final outOfStock = remainingStock <= 0;
    final tier = stockTierFor(remainingStock: remainingStock, minStock: product.minStock);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: tier.backgroundTint ?? AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tier.accentColor, width: tier == StockTier.normal ? 1 : 1.5),
      ),
      child: Row(
        children: [
          ProductThumbnail(imageUrl: product.imageUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name,
                    style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (tier != StockTier.normal && !outOfStock) ...[
                      Icon(Icons.warning_rounded, size: 12, color: tier.accentColor),
                      const SizedBox(width: 3),
                    ],
                    Flexible(
                      child: Text(
                        outOfStock ? 'Agotado' : '$remainingStock ${product.unit} stock',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tier == StockTier.normal ? AppColors.textSecondary : tier.accentColor,
                          fontWeight: tier == StockTier.normal ? FontWeight.normal : FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${priceFmt.format(product.price)}\$',
            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(width: 10),
          HoverInkWell(
            onTap: outOfStock ? null : onAdd,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: outOfStock
                    ? AppColors.surfaceElevated
                    : AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: outOfStock ? AppColors.border : AppColors.primary),
              ),
              child: Icon(Icons.add_rounded,
                  size: 18, color: outOfStock ? AppColors.textDisabled : AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}
