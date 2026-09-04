// ============================================================
// lib/core/widgets/product_list_card.dart
// Tarjeta de producto reutilizable: foto + nombre + categoría/código
// + precio/stock. Usada en el listado admin, el catálogo de solo
// lectura del cajero y el dashboard de inventario para que las tres
// pantallas se vean consistentes.
// ============================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../features/products/domain/entities/product.dart';
import '../theme/app_theme.dart';
import 'product_thumbnail.dart';

class ProductListCard extends StatelessWidget {
  final Product product;
  final NumberFormat currencyFmt;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool showChevron;
  final bool showInactiveBadge;
  final bool showMinStock;

  const ProductListCard({
    super.key,
    required this.product,
    required this.currencyFmt,
    this.onTap,
    this.trailing,
    this.showChevron = true,
    this.showInactiveBadge = false,
    this.showMinStock = false,
  });

  Color get _stockColor {
    if (product.isOutOfStock) return AppColors.stockCritical;
    if (product.isLowStock) return AppColors.stockWarning;
    return AppColors.stockOk;
  }

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: product.isOutOfStock
              ? AppColors.stockCritical.withValues(alpha: 0.4)
              : product.isLowStock
              ? AppColors.stockWarning.withValues(alpha: 0.3)
              : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          // ── Indicador de stock (barra lateral) ──
          Container(
            width: 4,
            height: 52,
            decoration: BoxDecoration(
              color: _stockColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),

          // ── Miniatura de foto ──
          ProductThumbnail(imageUrl: product.imageUrl),
          const SizedBox(width: 12),

          // ── Info principal ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        product.name,
                        style: TextStyle(
                          color: (showInactiveBadge && !product.isActive)
                              ? AppColors.textDisabled
                              : AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          decoration: (showInactiveBadge && !product.isActive)
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (showInactiveBadge && !product.isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Inactivo',
                          style: TextStyle(
                            color: AppColors.error,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),

                // Categoría y código de barras
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _MiniChip(
                      label: product.category,
                      icon: Icons.category_outlined,
                    ),
                    if (product.barcode != null && product.barcode!.isNotEmpty)
                      _MiniChip(
                        label: product.barcode!,
                        icon: Icons.qr_code_2_rounded,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // ── Precio y stock ──
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                currencyFmt.format(product.price),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 14,
                    color: _stockColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    showMinStock
                        ? '${product.stock} / mín. ${product.minStock}'
                        : '${product.stock} ${product.unit}',
                    style: TextStyle(
                      color: _stockColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),

          if (trailing != null) ...[const SizedBox(width: 4), trailing!],
          if (showChevron) ...[
            const SizedBox(width: 6),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textDisabled,
              size: 20,
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: card,
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _MiniChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
