import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'hover_ink_well.dart';

/// Columna de [DataTableView].
class TableColumn<K> {
  final String label;
  final int flex;

  /// Ancho fijo en lugar de [flex], para íconos y estados.
  final double? width;

  /// Alinea a la derecha: las cifras se comparan de un vistazo.
  final bool numeric;

  /// Clave de orden; sin ella la columna no se ordena.
  final K? sortKey;

  const TableColumn(
    this.label, {
    this.flex = 1,
    this.width,
    this.numeric = false,
    this.sortKey,
  });
}

/// Tabla de escritorio: encabezado fijo, filas virtualizadas con hover y
/// clic, y orden por columna. No pagina ni ordena por su cuenta: la
/// pantalla decide (el orden va al servidor) y pasa los controles en
/// [footer].
class DataTableView<T, K> extends StatelessWidget {
  final List<TableColumn<K>> columns;
  final List<T> rows;

  /// Una celda por columna, en el mismo orden que [columns].
  final List<Widget> Function(T row) cells;
  final ValueChanged<T>? onRowTap;

  final K? sortKey;
  final bool ascending;
  final ValueChanged<K>? onSort;

  /// Franja de color al inicio de la fila (p. ej. semáforo de stock).
  final Color? Function(T row)? rowAccent;

  /// Se muestra en lugar de las filas cuando no hay ninguna.
  final Widget? empty;
  final Widget? footer;
  final double rowHeight;

  /// Barra de progreso bajo el encabezado. Las filas anteriores quedan a
  /// la vista mientras llega la página nueva, en vez de parpadear.
  final bool loading;

  const DataTableView({
    super.key,
    required this.columns,
    required this.rows,
    required this.cells,
    this.onRowTap,
    this.sortKey,
    this.ascending = true,
    this.onSort,
    this.rowAccent,
    this.empty,
    this.footer,
    this.rowHeight = 56,
    this.loading = false,
  });

  static const _accentWidth = 3.0;

  Widget _cell(TableColumn<K> column, Widget child) {
    final aligned = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Align(
        alignment: column.numeric ? Alignment.centerRight : Alignment.centerLeft,
        child: child,
      ),
    );
    return column.width != null
        ? SizedBox(width: column.width, child: aligned)
        : Expanded(flex: column.flex, child: aligned);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            height: 44,
            color: AppColors.surfaceElevated,
            padding: EdgeInsets.only(left: rowAccent != null ? _accentWidth : 0, right: 8),
            child: Row(
              children: [
                const SizedBox(width: 8),
                for (final c in columns) _cell(c, _HeaderLabel(table: this, column: c)),
              ],
            ),
          ),
          loading
              ? const LinearProgressIndicator(minHeight: 1, color: AppColors.primary)
              : const Divider(height: 1),
          Expanded(
            child: rows.isEmpty
                ? (empty ?? const SizedBox.shrink())
                : ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) => _row(rows[i]),
                  ),
          ),
          if (footer != null) ...[
            const Divider(height: 1),
            footer!,
          ],
        ],
      ),
    );
  }

  Widget _row(T row) {
    final values = cells(row);
    assert(values.length == columns.length, 'una celda por columna');
    final accent = rowAccent?.call(row);
    return HoverInkWell(
      onTap: onRowTap == null ? null : () => onRowTap!(row),
      borderRadius: BorderRadius.zero,
      child: SizedBox(
        height: rowHeight,
        child: Row(
          children: [
            if (rowAccent != null)
              Container(width: _accentWidth, color: accent ?? Colors.transparent),
            const SizedBox(width: 8),
            for (var i = 0; i < columns.length; i++) _cell(columns[i], values[i]),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

class _HeaderLabel<K> extends StatelessWidget {
  final DataTableView<dynamic, K> table;
  final TableColumn<K> column;
  const _HeaderLabel({required this.table, required this.column});

  @override
  Widget build(BuildContext context) {
    final key = column.sortKey;
    final active = key != null && key == table.sortKey;
    final label = Text(
      column.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: active ? AppColors.textPrimary : AppColors.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
    if (key == null || table.onSort == null) return label;

    final arrow = Icon(
      active
          ? (table.ascending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded)
          : Icons.unfold_more_rounded,
      size: 14,
      color: active ? AppColors.primary : AppColors.textDisabled,
    );
    return Tooltip(
      message: 'Ordenar por ${column.label.toLowerCase()}',
      waitDuration: const Duration(milliseconds: 600),
      child: InkWell(
        onTap: () => table.onSort!(key),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: column.numeric
                ? [arrow, const SizedBox(width: 4), Flexible(child: label)]
                : [Flexible(child: label), const SizedBox(width: 4), arrow],
          ),
        ),
      ),
    );
  }
}

/// Controles de página para el pie de una tabla.
class TablePager extends StatelessWidget {
  /// Base cero, como el resto de la paginación del proyecto.
  final int page;
  final bool hasNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const TablePager({
    super.key,
    required this.page,
    required this.hasNext,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            'Página ${page + 1}',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: page > 0 ? onPrevious : null,
            icon: const Icon(Icons.chevron_left_rounded, size: 18),
            label: const Text('Anterior'),
          ),
          const SizedBox(width: 4),
          TextButton.icon(
            onPressed: hasNext ? onNext : null,
            // Ícono a la derecha del texto, como apunta la flecha.
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.chevron_right_rounded, size: 18),
            label: const Text('Siguiente'),
          ),
        ],
      ),
    );
  }
}
