import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/breakpoints.dart';

/// Acción del encabezado de una pantalla.
class PageAction {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  /// La acción principal de la pantalla (en compacto sigue siendo un FAB,
  /// que la pantalla pone por su cuenta): botón relleno.
  final bool primary;

  /// Marca el ícono con un punto, p. ej. cuando hay un filtro aplicado.
  final bool highlighted;

  const PageAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.primary = false,
    this.highlighted = false,
  });
}

/// Encabezado de las pantallas. En escritorio el título va a la izquierda
/// y las acciones llevan texto: un ícono suelto obliga a pasar el mouse
/// por encima para saber qué hace. En compacto quedan como íconos.
class AppPageBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final List<PageAction> actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;

  const AppPageBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.leading,
    this.automaticallyImplyLeading = true,
  });

  static const double height = 64;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final compact = context.isCompact;
    return AppBar(
      toolbarHeight: height,
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      titleSpacing: compact ? null : 24,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: compact ? 18 : 20),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
      actions: [
        for (final action in actions)
          compact ? _IconAction(action) : _ButtonAction(action),
        SizedBox(width: compact ? 4 : 24),
      ],
    );
  }
}

class _IconAction extends StatelessWidget {
  final PageAction action;
  const _IconAction(this.action);

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: action.label,
        onPressed: action.onPressed,
        icon: _MarkedIcon(action),
      );
}

class _ButtonAction extends StatelessWidget {
  final PageAction action;
  const _ButtonAction(this.action);

  static final _secondaryStyle = OutlinedButton.styleFrom(
    foregroundColor: AppColors.textPrimary,
    side: const BorderSide(color: AppColors.border),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
  );

  static final _primaryStyle = ElevatedButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
  );

  @override
  Widget build(BuildContext context) {
    final icon = _MarkedIcon(action, size: 18);
    final label = Text(action.label);
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: action.primary
          ? ElevatedButton.icon(
              style: _primaryStyle,
              onPressed: action.onPressed,
              icon: icon,
              label: label,
            )
          : OutlinedButton.icon(
              style: _secondaryStyle,
              onPressed: action.onPressed,
              icon: icon,
              label: label,
            ),
    );
  }
}

class _MarkedIcon extends StatelessWidget {
  final PageAction action;
  final double? size;
  const _MarkedIcon(this.action, {this.size});

  @override
  Widget build(BuildContext context) => Badge(
        isLabelVisible: action.highlighted,
        backgroundColor: AppColors.primary,
        smallSize: 8,
        child: Icon(action.icon, size: size),
      );
}
