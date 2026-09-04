// ============================================================
// lib/core/widgets/product_thumbnail.dart
// Miniatura de foto de producto, reutilizable en cualquier feature
// (listado admin, catálogo de solo lectura del cajero, etc).
// ============================================================

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ProductThumbnail extends StatelessWidget {
  final String? imageUrl;
  final double size;

  const ProductThumbnail({super.key, required this.imageUrl, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
      ),
      child: hasImage
          ? CachedNetworkImage(
              imageUrl: imageUrl!,
              fit: BoxFit.cover,
              placeholder: (_, _) => Icon(
                Icons.inventory_2_outlined,
                size: size * 0.4,
                color: AppColors.textDisabled,
              ),
              errorWidget: (_, _, _) => Icon(
                Icons.inventory_2_outlined,
                size: size * 0.4,
                color: AppColors.textDisabled,
              ),
            )
          : Icon(
              Icons.inventory_2_outlined,
              size: size * 0.4,
              color: AppColors.textDisabled,
            ),
    );
  }
}
