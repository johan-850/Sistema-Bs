// ============================================================
// lib/features/pos/presentation/pages/cart_page.dart
// Carrito de venta — US-027, US-028
// Solo se usa en ancho compacto: en escritorio el carrito es un panel
// al lado del catálogo (USB-014).
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_page_bar.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../providers/cart_providers.dart';
import '../widgets/cart_panel.dart';

class CartPage extends ConsumerWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<CartState>(cartProvider, (_, next) {
      if (next.warningMessage != null) {
        AppSnackbar.warning(context, next.warningMessage!);
      }
    });

    return const Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppPageBar(title: 'Carrito'),
      body: CartPanel(),
    );
  }
}
