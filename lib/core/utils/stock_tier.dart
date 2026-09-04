// ============================================================
// lib/core/utils/stock_tier.dart
// Nivel de alerta de stock en vivo (POS / carrito) — US-059
// ============================================================

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Nivel de alerta según qué tan cerca está [remainingStock] del
/// mínimo configurado del producto.
enum StockTier { normal, near, critical }

/// - [critical]: quedaría en el mínimo o por debajo (incluye agotado).
/// - [near]: por encima del mínimo pero dentro de un 50% de margen
///   (ej. mínimo 10 → amarillo entre 11 y 15 unidades).
/// - [normal]: todo lo demás.
///
/// Si [minStock] es 0 (sin umbral configurado) solo puede llegar a
/// [critical] al agotarse; no hay zona "near" que mostrar.
StockTier stockTierFor({required int remainingStock, required int minStock}) {
  if (remainingStock <= minStock) return StockTier.critical;
  if (minStock > 0 && remainingStock <= (minStock * 1.5).ceil()) return StockTier.near;
  return StockTier.normal;
}

extension StockTierColors on StockTier {
  /// Color de acento (borde, ícono, texto destacado).
  Color get accentColor => switch (this) {
        StockTier.critical => AppColors.stockCriticalVivid,
        StockTier.near => AppColors.stockNearVivid,
        StockTier.normal => AppColors.border,
      };

  /// Tinte de fondo sutil sobre AppColors.surfaceCard.
  Color? get backgroundTint => switch (this) {
        StockTier.critical => AppColors.stockCriticalVivid.withValues(alpha: 0.14),
        StockTier.near => AppColors.stockNearVivid.withValues(alpha: 0.14),
        StockTier.normal => null,
      };
}
