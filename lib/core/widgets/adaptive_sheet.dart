import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/breakpoints.dart';

/// Diálogo centrado en escritorio; hoja desde abajo en ventanas compactas.
/// Misma firma de retorno que showModalBottomSheet, así que los llamadores
/// leen el resultado igual. Escape cierra en ambos casos.
Future<T?> showAdaptiveSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double maxWidth = 560,
  bool isScrollControlled = false,
}) {
  if (context.isCompact) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: builder(ctx),
      ),
    );
  }
  return showDialog<T>(
    context: context,
    // El mismo navegador que usaba la hoja: varios llamadores cierran con
    // Navigator.pop(context) de la página, no del diálogo.
    useRootNavigator: false,
    builder: (ctx) => Dialog(
      backgroundColor: AppColors.surfaceCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: maxWidth,
        child: _FocusFirstField(child: Builder(builder: builder)),
      ),
    ),
  );
}

class _FocusFirstField extends StatefulWidget {
  final Widget child;
  const _FocusFirstField({required this.child});

  @override
  State<_FocusFirstField> createState() => _FocusFirstFieldState();
}

class _FocusFirstFieldState extends State<_FocusFirstField> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final node in FocusScope.of(context).traversalDescendants) {
        if (node.context?.findAncestorWidgetOfExactType<EditableText>() != null) {
          node.requestFocus();
          return;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
