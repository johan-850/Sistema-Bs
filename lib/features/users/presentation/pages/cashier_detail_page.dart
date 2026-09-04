import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/confirmation_dialog.dart';
import '../../../expenses/presentation/providers/expense_providers.dart';
import '../providers/users_providers.dart';

/// US-004 / US-006 — Detalle del cajero: toggle de estado y reset de contraseña
class CashierDetailPage extends ConsumerWidget {
  final String cashierId;
  const CashierDetailPage({super.key, required this.cashierId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listState = ref.watch(cashierListProvider);
    final cashier = listState.cashiers.where((c) => c.id == cashierId).firstOrNull;
    final fmt = DateFormat('dd MMMM yyyy, HH:mm', 'es');

    if (cashier == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalle Cajero')),
        body: const Center(child: Text('Cajero no encontrado')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(cashier.name)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Avatar y estado ────────────────────────────
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: (cashier.isActive ? AppColors.primary : AppColors.textDisabled).withValues(alpha: 0.15),
                    child: Text(
                      cashier.name[0].toUpperCase(),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: cashier.isActive ? AppColors.primary : AppColors.textDisabled,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(cashier.name, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(cashier.email, style: const TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: (cashier.isActive ? AppColors.success : AppColors.error).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: cashier.isActive ? AppColors.success : AppColors.error,
                      ),
                    ),
                    child: Text(
                      cashier.isActive ? '● Cuenta Activa' : '● Cuenta Inactiva',
                      style: TextStyle(
                        color: cashier.isActive ? AppColors.success : AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ── Info ───────────────────────────────────────
            _infoCard([
              _infoRow(Icons.calendar_today_outlined, 'Creado',
                  fmt.format(cashier.createdAt)),
              _infoRow(Icons.access_time_rounded, 'Último acceso',
                  cashier.lastLogin != null ? fmt.format(cashier.lastLogin!) : 'Nunca'),
            ]),
            const SizedBox(height: 24),

            // ── US-004: Toggle Estado ──────────────────────
            _ActionTile(
              icon: cashier.isActive ? Icons.block_rounded : Icons.check_circle_outline_rounded,
              color: cashier.isActive ? AppColors.error : AppColors.success,
              title: cashier.isActive ? 'Desactivar cuenta' : 'Activar cuenta',
              subtitle: cashier.isActive
                  ? 'Cierra sesión inmediatamente. El cajero no podrá ingresar.'
                  : 'Permite al cajero iniciar sesión nuevamente.',
              onTap: () => _confirmToggle(context, ref, cashier.id, cashier.isActive, cashier.name),
            ),
            const SizedBox(height: 12),

            // ── US-006: Reset Contraseña ───────────────────
            _ActionTile(
              icon: Icons.lock_reset_rounded,
              color: AppColors.warning,
              title: 'Restablecer contraseña',
              subtitle: 'Envía un enlace de restablecimiento al correo del cajero. No verás la nueva contraseña.',
              onTap: () => _confirmReset(context, ref, cashier.email),
            ),
            const SizedBox(height: 12),

            // ── US-038: Módulo de gastos ────────────────────
            _ActionTile(
              icon: cashier.expensesEnabled ? Icons.payments_outlined : Icons.money_off_rounded,
              color: cashier.expensesEnabled ? AppColors.primary : AppColors.textSecondary,
              title: cashier.expensesEnabled ? 'Módulo de gastos habilitado' : 'Módulo de gastos deshabilitado',
              subtitle: cashier.expensesEnabled
                  ? 'El cajero puede registrar gastos de caja durante su turno.'
                  : 'El cajero no ve la opción de registrar gastos en el POS.',
              onTap: () => _confirmToggleExpenses(context, ref, cashier.id, cashier.expensesEnabled, cashier.name),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoCard(List<Widget> children) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(children: children),
      );

  Widget _infoRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 12),
            Text('$label: ', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
          ],
        ),
      );

  Future<void> _confirmToggle(
      BuildContext context, WidgetRef ref, String id, bool isActive, String name) async {
    await ConfirmationDialog.show(
      context,
      title: isActive ? 'Desactivar cajero' : 'Activar cajero',
      message: isActive
          ? '¿Desactivar la cuenta de $name? Su sesión se cerrará inmediatamente.'
          : '¿Activar la cuenta de $name?',
      confirmLabel: isActive ? 'Desactivar' : 'Activar',
      isDangerous: isActive,
      onConfirm: () async {
        final ok = await ref.read(cashierListProvider.notifier).toggleStatus(id, !isActive);
        if (context.mounted) {
          if (ok) AppSnackbar.success(context, isActive ? 'Cuenta desactivada' : 'Cuenta activada');
        }
      },
    );
  }

  Future<void> _confirmToggleExpenses(
      BuildContext context, WidgetRef ref, String id, bool currentlyEnabled, String name) async {
    final newValue = !currentlyEnabled;
    await ConfirmationDialog.show(
      context,
      title: newValue ? 'Habilitar módulo de gastos' : 'Deshabilitar módulo de gastos',
      message: newValue
          ? '¿Permitir que $name registre gastos de caja?'
          : '¿Quitarle a $name el acceso para registrar gastos de caja?',
      confirmLabel: newValue ? 'Habilitar' : 'Deshabilitar',
      isDangerous: !newValue,
      onConfirm: () async {
        final failure = await ref
            .read(setCashierExpensesEnabledUseCaseProvider)(cashierId: id, enabled: newValue);
        if (!context.mounted) return;
        if (failure != null) {
          AppSnackbar.error(context, failure.message);
          return;
        }
        await ref.read(cashierListProvider.notifier).load();
        if (context.mounted) {
          AppSnackbar.success(context, newValue ? 'Módulo de gastos habilitado' : 'Módulo de gastos deshabilitado');
        }
      },
    );
  }

  Future<void> _confirmReset(BuildContext context, WidgetRef ref, String email) async {
    await ConfirmationDialog.show(
      context,
      title: 'Restablecer contraseña',
      message: 'Se enviará un enlace de restablecimiento a $email.',
      confirmLabel: 'Enviar correo',
      onConfirm: () async {
        final ok = await ref.read(cashierListProvider.notifier).resetPassword(email);
        if (context.mounted && ok) {
          AppSnackbar.success(context, 'Correo enviado a $email');
        }
      },
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceCard,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        maxLines: 2),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.textDisabled),
            ],
          ),
        ),
      ),
    );
  }
}
