import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'package:share_plus/share_plus.dart';
import 'dart:typed_data';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/confirmation_dialog.dart';
import '../../domain/entities/cashier.dart';
import '../providers/users_providers.dart';

/// US-007 — Lista paginada de cajeros con filtros, toggle y exportación CSV
class UsersListPage extends ConsumerStatefulWidget {
  const UsersListPage({super.key});

  @override
  ConsumerState<UsersListPage> createState() => _UsersListPageState();
}

class _UsersListPageState extends ConsumerState<UsersListPage> {
  bool? _filterActive;

  @override
  Widget build(BuildContext context) {
    final listState = ref.watch(cashierListProvider);

    ref.listen(cashierListProvider, (_, next) {
      if (next.failure != null) AppSnackbar.error(context, next.failure!.message);
      if (next.successMessage != null) AppSnackbar.success(context, next.successMessage!);
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Cajeros'),
        actions: [
          // ── Exportar CSV ────────────────────────────────
          IconButton(
            tooltip: 'Exportar CSV',
            icon: const Icon(Icons.download_rounded),
            onPressed: () => _exportCSV(context),
          ),
          // ── Crear cajero ─────────────────────────────────
          IconButton(
            tooltip: 'Nuevo cajero',
            icon: const Icon(Icons.person_add_rounded),
            onPressed: () async {
              await context.push('/admin/users/create');
              ref.read(cashierListProvider.notifier).load(filterActive: _filterActive);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Filtros ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _FilterBar(
              selected: _filterActive,
              onChanged: (v) {
                setState(() => _filterActive = v);
                ref.read(cashierListProvider.notifier).load(filterActive: v);
              },
            ),
          ),
          // ── Lista ─────────────────────────────────────────
          Expanded(
            child: listState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : listState.cashiers.isEmpty
                    ? const _EmptyState()
                    : RefreshIndicator(
                        onRefresh: () => ref.read(cashierListProvider.notifier).load(filterActive: _filterActive),
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: listState.cashiers.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, i) => _CashierCard(
                            cashier: listState.cashiers[i],
                            onToggle: (isActive) => _confirmToggle(context, listState.cashiers[i], isActive),
                            onReset: () => _confirmReset(context, listState.cashiers[i]),
                            onDetail: () => context.push('/admin/users/${listState.cashiers[i].id}'),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmToggle(BuildContext context, Cashier c, bool newActive) async {
    await ConfirmationDialog.show(
      context,
      title: newActive ? 'Activar cajero' : 'Desactivar cajero',
      message: newActive
          ? '¿Activar la cuenta de ${c.name}?'
          : '¿Desactivar la cuenta de ${c.name}? Su sesión se cerrará inmediatamente.',
      confirmLabel: newActive ? 'Activar' : 'Desactivar',
      isDangerous: !newActive,
      onConfirm: () => ref.read(cashierListProvider.notifier).toggleStatus(c.id, newActive),
    );
  }

  Future<void> _confirmReset(BuildContext context, Cashier c) async {
    await ConfirmationDialog.show(
      context,
      title: 'Restablecer contraseña',
      message: 'Se enviará un correo de restablecimiento a ${c.email}.',
      confirmLabel: 'Enviar correo',
      onConfirm: () => ref.read(cashierListProvider.notifier).resetPassword(c.email),
    );
  }

  Future<void> _exportCSV(BuildContext context) async {
    final result = await ref.read(cashierListProvider.notifier).exportCSV();
    if (result.failure != null) {
      if (context.mounted) AppSnackbar.error(context, result.failure!.message);
      return;
    }
    // Descarga/Compartir (compatible con móvil, web y escritorio)
    final bytes = utf8.encode(result.csv!);
    final fileName = 'cajeros_${DateTime.now().millisecondsSinceEpoch}.csv';
    final xFile = XFile.fromData(
      Uint8List.fromList(bytes),
      name: fileName,
      mimeType: 'text/csv',
    );
    await Share.shareXFiles([xFile], text: 'Exportación de Cajeros');
    
    if (context.mounted) AppSnackbar.success(context, 'CSV exportado correctamente');
  }
}

// ── Componentes internos ──────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final bool? selected;
  final ValueChanged<bool?> onChanged;
  const _FilterBar({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('Filtrar: ', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(width: 8),
        _chip('Todos', null),
        const SizedBox(width: 8),
        _chip('Activos', true),
        const SizedBox(width: 8),
        _chip('Inactivos', false),
      ],
    );
  }

  Widget _chip(String label, bool? value) {
    final isSelected = selected == value;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _CashierCard extends StatelessWidget {
  final Cashier cashier;
  final ValueChanged<bool> onToggle;
  final VoidCallback onReset;
  final VoidCallback onDetail;

  const _CashierCard({
    required this.cashier,
    required this.onToggle,
    required this.onReset,
    required this.onDetail,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy, HH:mm', 'es');
    return GestureDetector(
      onTap: onDetail,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cashier.isActive ? AppColors.border : AppColors.error.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 24,
              backgroundColor: (cashier.isActive ? AppColors.primary : AppColors.textDisabled).withValues(alpha: 0.15),
              child: Text(
                cashier.name.isNotEmpty ? cashier.name[0].toUpperCase() : '?',
                style: TextStyle(
                  color: cashier.isActive ? AppColors.primary : AppColors.textDisabled,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(cashier.name,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      // Badge de estado
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: (cashier.isActive ? AppColors.success : AppColors.error).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          cashier.isActive ? 'Activo' : 'Inactivo',
                          style: TextStyle(
                            color: cashier.isActive ? AppColors.success : AppColors.error,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(cashier.email,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (cashier.lastLogin != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded, size: 12, color: AppColors.textDisabled),
                        const SizedBox(width: 4),
                        Text('Último acceso: ${fmt.format(cashier.lastLogin!)}',
                            style: const TextStyle(color: AppColors.textDisabled, fontSize: 11)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // Acciones
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: AppColors.textSecondary),
              color: AppColors.surfaceElevated,
              onSelected: (v) {
                if (v == 'toggle') onToggle(!cashier.isActive);
                if (v == 'reset') onReset();
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'toggle',
                  child: Row(
                    children: [
                      Icon(
                        cashier.isActive ? Icons.block_rounded : Icons.check_circle_outline_rounded,
                        size: 18,
                        color: cashier.isActive ? AppColors.error : AppColors.success,
                      ),
                      const SizedBox(width: 10),
                      Text(cashier.isActive ? 'Desactivar' : 'Activar'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'reset',
                  child: Row(
                    children: [
                      Icon(Icons.lock_reset_rounded, size: 18, color: AppColors.warning),
                      SizedBox(width: 10),
                      Text('Restablecer contraseña'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_outline_rounded, size: 64, color: AppColors.textDisabled),
          const SizedBox(height: 16),
          Text('No hay cajeros registrados',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          const Text('Crea el primer cajero con el botón +',
              style: TextStyle(color: AppColors.textDisabled, fontSize: 13)),
        ],
      ),
    );
  }
}
