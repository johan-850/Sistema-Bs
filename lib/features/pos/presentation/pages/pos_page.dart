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
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/scan_feedback_providers.dart';
import '../../../../core/utils/stock_tier.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/product_thumbnail.dart';
import '../../../../core/widgets/barcode_scanner_page.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../cash_register/domain/entities/cash_register.dart';
import '../../../cash_register/presentation/pages/cash_register_closing_page.dart';
import '../../../cash_register/presentation/providers/cash_register_providers.dart';
import '../../../products/domain/entities/product.dart';
import '../../../products/presentation/providers/product_providers.dart'
    show getProductByBarcodeUseCaseProvider;
import '../providers/cart_providers.dart';
import '../providers/checkout_provider.dart' show logLowStockAlertUseCaseProvider;
import '../providers/pos_catalog_provider.dart';

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
    final user = ref.watch(authStateStreamProvider).valueOrNull;
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

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              child: Text(
                _initials(user?.name ?? ''),
                style: const TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('CAJA PRINCIPAL', style: TextStyle(fontSize: 15, letterSpacing: 0.5)),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Info del turno',
            icon: const Icon(Icons.access_time_rounded),
            onPressed: () => _showShiftInfo(context, register),
          ),
          // US-038: oculto si el AdminMaster deshabilitó el módulo para este cajero.
          if (user?.expensesEnabled ?? true)
            IconButton(
              tooltip: 'Gastos',
              icon: const Icon(Icons.payments_outlined),
              onPressed: () => context.push('/pos/expenses'),
            ),
          IconButton(
            tooltip: 'Configuración',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Buscador ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: catalogNotifier.search,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Buscar producto o código...',
                hintStyle: const TextStyle(color: AppColors.textDisabled),
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.shopping_bag_outlined, color: AppColors.textSecondary),
                  onPressed: () => context.push('/pos/cart'),
                ),
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
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _CategoryChip(
                  label: 'Todos',
                  selected: catalogState.filterCategory == null,
                  onTap: () => catalogNotifier.filterByCategory(null),
                ),
                const SizedBox(width: 8),
                ...AppConstants.productCategories.map((cat) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _CategoryChip(
                        label: cat,
                        selected: catalogState.filterCategory == cat,
                        onTap: () => catalogNotifier.filterByCategory(cat),
                      ),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // ── Listado de productos ──
          Expanded(
            child: catalogState.isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : catalogState.products.isEmpty
                    ? const Center(
                        child: Text('Sin resultados', style: TextStyle(color: AppColors.textSecondary)),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: catalogState.products.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final p = catalogState.products[i];
                          final inCart = cartState.items
                              .where((item) => item.productId == p.id)
                              .fold(0, (sum, item) => sum + item.quantity);
                          return _VentaProductTile(
                            product: p,
                            quantityInCart: inCart,
                            priceFmt: _priceFmt,
                            onAdd: () => ref.read(cartProvider.notifier).addProduct(p),
                          );
                        },
                      ),
          ),
        ],
      ),
      bottomNavigationBar: _PosBottomNav(
        cartItemCount: cartState.totalItems,
        onScan: _scanAndAdd,
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  void _showShiftInfo(BuildContext context, CashRegister register) {
    final dateFmt = DateFormat('dd/MM/yyyy hh:mm a', 'es');
    final currencyFmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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

  /// US-039: abre el wizard de cierre — igual patrón de Navigator.push
  /// (no go_router) que BarcodeScannerPage/CheckoutPage, porque el
  /// register no es serializable a una ruta con nombre.
  void _goToClosing(BuildContext context, CashRegister register) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CashRegisterClosingPage(register: register)),
    );
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

// ── Barra de navegación inferior (Ventas / Stock / Escanear / Carrito) ─

class _PosBottomNav extends StatelessWidget {
  final int cartItemCount;
  final VoidCallback onScan;

  const _PosBottomNav({required this.cartItemCount, required this.onScan});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: 0,
      type: BottomNavigationBarType.fixed,
      backgroundColor: AppColors.surfaceCard,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textSecondary,
      onTap: (i) {
        switch (i) {
          case 0:
            break; // Ventas: ya estamos aquí
          case 1:
            context.push('/catalog');
            break;
          case 2:
            onScan();
            break;
          case 3:
            context.push('/pos/cart');
            break;
        }
      },
      items: [
        const BottomNavigationBarItem(icon: Icon(Icons.storefront_rounded), label: 'Ventas'),
        const BottomNavigationBarItem(icon: Icon(Icons.inventory_2_outlined), label: 'Stock'),
        const BottomNavigationBarItem(icon: Icon(Icons.qr_code_scanner_rounded), label: 'Escanear'),
        BottomNavigationBarItem(
          icon: Badge(
            isLabelVisible: cartItemCount > 0,
            label: Text('$cartItemCount'),
            backgroundColor: AppColors.primary,
            textColor: Colors.black,
            child: const Icon(Icons.shopping_cart_outlined),
          ),
          label: 'Carrito',
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
      appBar: AppBar(title: const Text('Punto de Venta')),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.15) : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.primary : AppColors.border),
        ),
        alignment: Alignment.center,
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
                    Text(
                      outOfStock ? 'Agotado' : '$remainingStock ${product.unit} stock',
                      style: TextStyle(
                        color: tier == StockTier.normal ? AppColors.textSecondary : tier.accentColor,
                        fontWeight: tier == StockTier.normal ? FontWeight.normal : FontWeight.bold,
                        fontSize: 12,
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
          InkWell(
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
