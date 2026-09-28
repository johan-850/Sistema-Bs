import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Tope de ancho centrado. Va dentro del scroll, no alrededor: así la rueda
/// del mouse funciona en todo el ancho y no solo sobre la columna.
class ReadableWidth extends StatelessWidget {
  final double maxWidth;
  final Widget child;

  const ReadableWidth({super.key, this.maxWidth = 720, required this.child});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// ListView con el contenido centrado en [maxWidth] mediante padding, para
/// que el área de scroll siga ocupando todo el ancho.
class ReadableListView extends StatelessWidget {
  final EdgeInsets padding;
  final List<Widget> children;
  final double maxWidth;

  const ReadableListView({
    super.key,
    this.padding = EdgeInsets.zero,
    required this.children,
    this.maxWidth = 720,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = math.max(0.0, (constraints.maxWidth - maxWidth) / 2);
        return ListView(
          padding: padding + EdgeInsets.symmetric(horizontal: side),
          children: children,
        );
      },
    );
  }
}
