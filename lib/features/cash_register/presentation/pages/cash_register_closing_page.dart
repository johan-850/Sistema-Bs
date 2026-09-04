// ============================================================
// lib/features/cash_register/presentation/pages/cash_register_closing_page.dart
// Cierre de caja — US-039, US-040, US-041, US-042
// Mismo patrón wizard que cash_register_opening_page.dart
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../settings/presentation/providers/store_settings_providers.dart';
import '../../domain/entities/cash_register.dart';
import '../providers/cash_register_providers.dart';
import '../widgets/denomination_card.dart';

class CashRegisterClosingPage extends ConsumerStatefulWidget {
  final CashRegister register;
  const CashRegisterClosingPage({super.key, required this.register});

  @override
  ConsumerState<CashRegisterClosingPage> createState() => _CashRegisterClosingPageState();
}

class _CashRegisterClosingPageState extends ConsumerState<CashRegisterClosingPage> {
  final _notesController = TextEditingController();
  final _pageController = PageController();

  static const _steps = ['Resumen', 'Conteo', 'Confirmar'];

  ClosingArgs get _args =>
      (registerId: widget.register.id, openingAmount: widget.register.openingAmount);

  @override
  void dispose() {
    _notesController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _animateToPage(int page) {
    return _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _confirmStart() async {
    final notifier = ref.read(registerClosingProvider(_args).notifier);
    final success = await notifier.confirmStart();
    if (!mounted) return;
    if (success) {
      await _animateToPage(1);
    } else {
      final failure = ref.read(registerClosingProvider(_args)).failure;
      AppSnackbar.error(context, failure?.message ?? 'Error al iniciar el cierre');
    }
  }

  Future<void> _confirmClose(double threshold) async {
    final state = ref.read(registerClosingProvider(_args));
    final diff = state.difference ?? 0;
    if (diff.abs() > threshold && state.notes.trim().isEmpty) {
      AppSnackbar.warning(
        context,
        'La diferencia supera \$${NumberFormat('#,###', 'es_CO').format(threshold)} — agrega un comentario para continuar.',
      );
      return;
    }

    final notifier = ref.read(registerClosingProvider(_args).notifier);
    final success = await notifier.confirmClose();
    if (!mounted) return;
    if (!success) {
      final failure = ref.read(registerClosingProvider(_args)).failure;
      AppSnackbar.error(context, failure?.message ?? 'Error al confirmar el cierre');
      return;
    }
    // La caja ya quedó 'closed' en la BD — activeRegisterProvider tiene
    // en caché la versión vieja ('open'), igual que pasaba con la
    // apertura si no se invalidaba tras confirmOpen().
    ref.invalidate(activeRegisterProvider);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(registerClosingProvider(_args));
    final notifier = ref.read(registerClosingProvider(_args).notifier);
    final settingsAsync = ref.watch(storeSettingsProvider);
    final threshold = settingsAsync.valueOrNull?.cashDiffCommentThreshold ?? 5000;

    return PopScope(
      canPop: !state.started,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || !state.started) return;
        // El cierre ya se inició (caja en 'closing') — salir a medias
        // dejaría la caja bloqueada sin terminar el cuadre.
        AppSnackbar.warning(context, 'Ya iniciaste el cierre — debes completarlo para volver a vender.');
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    if (!state.started)
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                    Expanded(
                      child: Text('Cierre de Caja',
                          style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
                    ),
                    if (!state.started) const SizedBox(width: 48),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: _StepIndicator(steps: _steps, currentStep: state.currentStep),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _Step0Preview(
                      state: state,
                      onConfirmStart: _confirmStart,
                    ),
                    _Step1Count(
                      state: state,
                      notifier: notifier,
                      threshold: threshold,
                      onNext: () {
                        notifier.goToStep(2);
                        _animateToPage(2);
                      },
                    ),
                    _Step2Confirm(
                      state: state,
                      threshold: threshold,
                      notesController: _notesController,
                      onBack: () {
                        notifier.goToStep(1);
                        _animateToPage(1);
                      },
                      onUpdateNotes: notifier.updateNotes,
                      onConfirm: () => _confirmClose(threshold),
                      onFinish: () => context.go('/cash-register/opening'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Step 0: Resumen previo (US-039) ───────────────────────────

class _Step0Preview extends StatelessWidget {
  final RegisterClosingState state;
  final VoidCallback onConfirmStart;

  const _Step0Preview({required this.state, required this.onConfirmStart});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###', 'es_CO');
    final preview = state.preview;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Resumen del turno', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text(
            'Al iniciar el cierre, esta caja deja de aceptar nuevas ventas y gastos.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: state.isLoading && preview == null
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : preview == null
                    ? const Center(
                        child: Text('No se pudo cargar el resumen.',
                            style: TextStyle(color: AppColors.error)))
                    : Column(
                        children: [
                          _SummaryRow(label: 'Ventas del turno', value: '\$${fmt.format(preview.salesTotal)}'),
                          _SummaryRow(label: 'Transacciones', value: '${preview.transactionCount}'),
                          _SummaryRow(label: 'Gastos del turno', value: '\$${fmt.format(preview.expensesTotal)}'),
                          const Divider(color: AppColors.border, height: 32),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [
                                AppColors.primary.withValues(alpha: 0.15),
                                AppColors.secondary.withValues(alpha: 0.08),
                              ]),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                            ),
                            child: Column(
                              children: [
                                const Text('Efectivo esperado',
                                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                                const SizedBox(height: 6),
                                Text('\$${fmt.format(preview.expectedCash)}',
                                    style: const TextStyle(
                                        color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 28)),
                              ],
                            ),
                          ),
                        ],
                      ),
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: state.isLoading || preview == null ? null : onConfirmStart,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: state.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Text('Iniciar cierre'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          Text(value, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
        ],
      ),
    );
  }
}

// ── Step 1: Conteo de denominaciones (US-040) ─────────────────

class _Step1Count extends StatelessWidget {
  final RegisterClosingState state;
  final RegisterClosingNotifier notifier;
  final double threshold;
  final VoidCallback onNext;

  const _Step1Count({
    required this.state,
    required this.notifier,
    required this.threshold,
    required this.onNext,
  });

  Color _diffColor(double diff) {
    if (diff == 0) return AppColors.success;
    if (diff.abs() <= threshold) return AppColors.stockNearVivid;
    return AppColors.stockCriticalVivid;
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###', 'es_CO');
    final diff = state.difference ?? 0;
    final color = _diffColor(diff);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total contado',
                        style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 14)),
                    Text('\$${fmt.format(state.total)}',
                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 22)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color, width: 1.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      diff == 0 ? 'Cuadra exacto' : (diff > 0 ? 'Sobrante' : 'Faltante'),
                      style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    Text('\$${fmt.format(diff.abs())}',
                        style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            children: [
              const _SectionHeader(label: 'Monedas'),
              const SizedBox(height: 8),
              ...AppConstants.coinDenominations.entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: DenominationCard(
                      denomKey: e.key,
                      denomValue: e.value,
                      isCoin: true,
                      quantity: state.breakdown[e.key] ?? 0,
                      onChanged: (qty) => notifier.setQuantity(e.key, qty),
                    ),
                  )),
              const SizedBox(height: 8),
              const _SectionHeader(label: 'Billetes'),
              const SizedBox(height: 8),
              ...AppConstants.billDenominations.entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: DenominationCard(
                      denomKey: e.key,
                      denomValue: e.value,
                      isCoin: false,
                      quantity: state.breakdown[e.key] ?? 0,
                      onChanged: (qty) => notifier.setQuantity(e.key, qty),
                    ),
                  )),
              const SizedBox(height: 24),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onNext,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: const Text('Siguiente'),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.2)),
        const SizedBox(width: 8),
        const Expanded(child: Divider(color: AppColors.border, thickness: 1)),
      ],
    );
  }
}

// ── Step 2: Comentario + confirmación (US-041/042) ────────────

class _Step2Confirm extends StatelessWidget {
  final RegisterClosingState state;
  final double threshold;
  final TextEditingController notesController;
  final VoidCallback onBack;
  final ValueChanged<String> onUpdateNotes;
  final VoidCallback onConfirm;
  final VoidCallback onFinish;

  const _Step2Confirm({
    required this.state,
    required this.threshold,
    required this.notesController,
    required this.onBack,
    required this.onUpdateNotes,
    required this.onConfirm,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    if (state.success && state.closedRegister?.closingSummary != null) {
      return _ClosedSummary(summary: state.closedRegister!.closingSummary!, onFinish: onFinish);
    }

    final diff = state.difference ?? 0;
    final requiresComment = diff.abs() > threshold;
    final fmt = NumberFormat('#,###', 'es_CO');

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Comentario de cierre', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            requiresComment
                ? 'La diferencia (\$${fmt.format(diff.abs())}) supera el umbral configurado — el comentario es obligatorio.'
                : 'Opcional. Registra cualquier observación del turno.',
            style: TextStyle(color: requiresComment ? AppColors.stockCriticalVivid : AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: notesController,
            maxLines: 5,
            maxLength: AppConstants.maxNotesLength,
            onChanged: onUpdateNotes,
            style: const TextStyle(color: AppColors.textPrimary, height: 1.5),
            decoration: InputDecoration(
              hintText: 'Ej: Faltaron \$5.000 por vuelto entregado de más...',
              fillColor: AppColors.surfaceCard,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: requiresComment ? AppColors.stockCriticalVivid : AppColors.border),
              ),
            ),
          ),
          const Spacer(),
          if (state.failure != null) ...[
            Text(state.failure!.message, style: const TextStyle(color: AppColors.error, fontSize: 13)),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: state.isLoading ? null : onBack,
                  child: const Text('Atrás'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: state.isLoading ? null : onConfirm,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: state.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Text('Confirmar cierre'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Resumen final de solo lectura tras confirmar el cierre ────

class _ClosedSummary extends StatelessWidget {
  final ClosingSummary summary;
  final VoidCallback onFinish;

  const _ClosedSummary({required this.summary, required this.onFinish});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###', 'es_CO');
    final diffColor = summary.difference == 0
        ? AppColors.success
        : (summary.difference.abs() <= 5000 ? AppColors.stockNearVivid : AppColors.stockCriticalVivid);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: Icon(Icons.check_circle_rounded, color: AppColors.success, size: 56),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text('Caja cerrada correctamente',
                style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              children: [
                _SummaryRow(label: 'Apertura', value: '\$${fmt.format(summary.openingAmount)}'),
                _SummaryRow(label: 'Ventas efectivo', value: '\$${fmt.format(summary.salesEfectivo)}'),
                _SummaryRow(label: 'Ventas mixto (efectivo)', value: '\$${fmt.format(summary.salesMixtoEfectivo)}'),
                _SummaryRow(label: 'Ventas transferencia', value: '\$${fmt.format(summary.salesTransferencia)}'),
                _SummaryRow(label: 'Total ventas', value: '\$${fmt.format(summary.salesTotal)}'),
                _SummaryRow(label: 'Transacciones', value: '${summary.transactionCount}'),
                _SummaryRow(label: 'Gastos', value: '\$${fmt.format(summary.totalExpenses)}'),
                const Divider(color: AppColors.border, height: 24),
                _SummaryRow(label: 'Efectivo esperado', value: '\$${fmt.format(summary.expectedCash)}'),
                _SummaryRow(label: 'Efectivo contado', value: '\$${fmt.format(summary.countedCash)}'),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Diferencia',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w600)),
                      Text('\$${fmt.format(summary.difference)}',
                          style: TextStyle(color: diffColor, fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onFinish,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: const Text('Finalizar'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Indicador de pasos ──────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final List<String> steps;
  final int currentStep;

  const _StepIndicator({required this.steps, required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          final stepIndex = i ~/ 2;
          final isCompleted = stepIndex < currentStep;
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 2,
              color: isCompleted ? AppColors.primary : AppColors.border,
            ),
          );
        }
        final stepIndex = i ~/ 2;
        final isActive = stepIndex == currentStep;
        final isCompleted = stepIndex < currentStep;

        return Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isCompleted
                    ? AppColors.primary
                    : isActive
                        ? AppColors.primary.withValues(alpha: 0.2)
                        : AppColors.surfaceElevated,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isActive || isCompleted ? AppColors.primary : AppColors.border,
                  width: 2,
                ),
              ),
              child: Center(
                child: isCompleted
                    ? const Icon(Icons.check_rounded, size: 14, color: Colors.black)
                    : Text(
                        '${stepIndex + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isActive ? AppColors.primary : AppColors.textDisabled,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              steps[stepIndex],
              style: TextStyle(
                fontSize: 10,
                color: isActive || isCompleted ? AppColors.primary : AppColors.textDisabled,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        );
      }),
    );
  }
}
