import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// InkWell cuyo realce de hover y de foco se ve aunque el hijo sea opaco.
/// Un InkWell pinta su tinta en el Material de abajo, así que sobre un
/// Container con color el mouse no produce ningún cambio visible.
class HoverInkWell extends StatefulWidget {
  final VoidCallback? onTap;
  final BorderRadius borderRadius;
  final Widget child;

  /// False para controles secundarios que alargarían el recorrido con Tab
  /// (los +/− junto a un campo que ya se edita con teclado).
  final bool focusable;

  const HoverInkWell({
    super.key,
    required this.onTap,
    required this.borderRadius,
    required this.child,
    this.focusable = true,
  });

  @override
  State<HoverInkWell> createState() => _HoverInkWellState();
}

class _HoverInkWellState extends State<HoverInkWell> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return InkWell(
      onTap: widget.onTap,
      canRequestFocus: widget.focusable,
      borderRadius: widget.borderRadius,
      onHover: (h) => setState(() => _hovered = h),
      onFocusChange: (f) => setState(() => _focused = f),
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          color: enabled && _hovered
              ? AppColors.textPrimary.withValues(alpha: 0.05)
              : Colors.transparent,
          border: enabled && _focused
              ? Border.all(color: AppColors.primary, width: 2)
              : null,
        ),
        child: widget.child,
      ),
    );
  }
}
