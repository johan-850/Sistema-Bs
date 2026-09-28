import 'package:flutter/widgets.dart';

enum Breakpoint { compact, medium, expanded }

/// Única fuente de verdad de los anchos de la aplicación. Ninguna pantalla
/// compara anchos a mano: pregunta por el punto de quiebre.
abstract class Breakpoints {
  static const double medium = 768;
  static const double expanded = 1280;

  static Breakpoint of(double width) {
    if (width >= expanded) return Breakpoint.expanded;
    if (width >= medium) return Breakpoint.medium;
    return Breakpoint.compact;
  }
}

/// Mide la ventana. Dentro de un panel que no ocupa todo el ancho (p. ej.
/// el carrito del POS) el espacio real es otro: ahí se usa `LayoutBuilder`
/// con `Breakpoints.of(constraints.maxWidth)`.
extension BreakpointContext on BuildContext {
  // sizeOf y no MediaQuery.of: solo reconstruye cuando cambia el tamaño.
  Breakpoint get breakpoint => Breakpoints.of(MediaQuery.sizeOf(this).width);

  bool get isCompact => breakpoint == Breakpoint.compact;
  bool get isMedium => breakpoint == Breakpoint.medium;
  bool get isExpanded => breakpoint == Breakpoint.expanded;
}
