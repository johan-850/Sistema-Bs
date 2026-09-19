// ============================================================
// lib/features/cash_register/presentation/pages/cash_register_opening_page.dart
// Pantalla de apertura de caja — Épica 2
// US-008: Detectar si hay caja abierta y redirigir al POS
// US-009: Formulario de desglose por denominaciones (3 pasos)
// US-010: Campo de notas opcional
// US-012: El timestamp es registrado automáticamente en Supabase
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/cash_register_providers.dart';
import '../widgets/denomination_card.dart';
import 'cash_register_closing_page.dart';

class CashRegisterOpeningPage extends ConsumerWidget {
  const CashRegisterOpeningPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // US-008: Verificar si ya hay una caja abierta hoy
    final activeRegisterAsync = ref.watch(activeRegisterProvider);

    return activeRegisterAsync.when(
      loading: () => const _LoadingScaffold(),
      error: (e, _) => _OpeningFormScaffold(error: e.toString()),
      data: (activeRegister) {
        // Cualquier caja sin cerrar cuenta, incluida una en 'closing'
        // (un cierre que quedó a medias). Antes solo se miraba isOpen,
        // así que una caja en ese estado era invisible para el cajero:
        // no la podía retomar ni cerrar, y terminaba abriendo otra.
        if (activeRegister != null && !activeRegister.isClosed) {
          return _ActiveRegisterScaffold(register: activeRegister);
        }
        // No hay caja sin cerrar → mostrar wizard de apertura
        return const _OpeningFormScaffold();
      },
    );
  }
}

// ── Scaffold de carga ─────────────────────────────────────────

class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }
}

// ── Scaffold de caja ya abierta ────────────────────────────────

class _ActiveRegisterScaffold extends ConsumerWidget {
  final dynamic register;
  const _ActiveRegisterScaffold({required this.register});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateStreamProvider).valueOrNull;
    final fmt = NumberFormat('#,###', 'es_CO');
    final timeFmt = DateFormat('hh:mm a', 'es');

    // Caja en 'closing': el cajero empezó el cierre y no lo terminó.
    // Hay que dejarlo retomarlo, no mandarlo a vender otra vez.
    final bool isClosing = register.isClosing;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bienvenido de vuelta',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        user?.name ?? '',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                  IconButton(
                    tooltip: 'Cerrar sesión',
                    icon: const Icon(Icons.logout_rounded),
                    onPressed: () async =>
                        ref.read(logoutUseCaseProvider).call(),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // ── Card de estado ──────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.15),
                      AppColors.secondary.withValues(alpha: 0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: isClosing ? AppColors.warning : AppColors.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isClosing ? 'Cierre sin terminar' : 'Turno activo',
                          style: TextStyle(
                            color: isClosing ? AppColors.warning : AppColors.success,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '\$${fmt.format(register.openingAmount)}',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Apertura a las ${timeFmt.format(register.openingTime.toLocal())}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                    if (register.notes != null && register.notes!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceCard,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.notes_rounded,
                                size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                register.notes!,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Spacer(),

              // ── Botón principal ─────────────────────────────
              // Con el cierre a medias no tiene sentido mandarlo a
              // vender: la caja ya no acepta ventas (confirm_sale exige
              // status='open'), así que lo único útil es terminar.
              if (isClosing)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 16, color: AppColors.warning),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Empezaste a cerrar esta caja y quedó a medias. Termina el cierre para poder abrir una nueva.',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => isClosing
                      ? Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CashRegisterClosingPage(register: register),
                          ),
                        )
                      : context.go(AppRoutes.pos),
                  icon: Icon(isClosing ? Icons.lock_clock_outlined : Icons.point_of_sale_rounded),
                  label: Text(isClosing ? 'Terminar el cierre' : 'Ir al Punto de Venta'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Wizard de apertura (3 pasos) ──────────────────────────────

class _OpeningFormScaffold extends ConsumerStatefulWidget {
  final String? error;
  const _OpeningFormScaffold({this.error});

  @override
  ConsumerState<_OpeningFormScaffold> createState() =>
      _OpeningFormScaffoldState();
}

class _OpeningFormScaffoldState extends ConsumerState<_OpeningFormScaffold> {
  final _notesController = TextEditingController();
  final _pageController = PageController();

  static const _steps = ['Desglose', 'Notas', 'Confirmar'];

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

  Future<void> _confirmOpen() async {
    final notifier = ref.read(openRegisterProvider.notifier);
    final success = await notifier.confirmOpen();
    if (!mounted) return;

    if (success) {
      // Invalida el provider para que el widget padre detecte la caja abierta
      ref.invalidate(activeRegisterProvider);
      AppSnackbar.success(context, 'Caja abierta correctamente');
    } else {
      final failure = ref.read(openRegisterProvider).failure;
      AppSnackbar.error(context, failure?.message ?? 'Error al abrir la caja');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(openRegisterProvider);
    final notifier = ref.read(openRegisterProvider.notifier);
    final user = ref.watch(authStateStreamProvider).valueOrNull;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ── AppBar personalizado ─────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Apertura de Caja',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          user?.name ?? '',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar sesión',
                    icon: const Icon(Icons.logout_rounded,
                        color: AppColors.textSecondary),
                    onPressed: () async =>
                        ref.read(logoutUseCaseProvider).call(),
                  ),
                ],
              ),
            ),

            // ── Indicador de pasos (US-008) ──────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: _StepIndicator(
                steps: _steps,
                currentStep: state.currentStep,
              ),
            ),
            const SizedBox(height: 24),

            // ── Contenido paginado ───────────────────────────
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  // Paso 1: Desglose de denominaciones
                  _Step1Breakdown(
                    state: state,
                    notifier: notifier,
                    onNext: () {
                      notifier.goToStep(1);
                      _animateToPage(1);
                    },
                  ),
                  // Paso 2: Notas
                  _Step2Notes(
                    controller: _notesController,
                    onBack: () {
                      notifier.goToStep(0);
                      _animateToPage(0);
                    },
                    onNext: () {
                      notifier.updateNotes(_notesController.text);
                      notifier.goToStep(2);
                      _animateToPage(2);
                    },
                  ),
                  // Paso 3: Confirmación
                  _Step3Confirm(
                    state: state,
                    isLoading: state.isLoading,
                    onBack: () {
                      notifier.goToStep(1);
                      _animateToPage(1);
                    },
                    onConfirm: _confirmOpen,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Step 1: Desglose de denominaciones ────────────────────────

class _Step1Breakdown extends StatelessWidget {
  final OpenRegisterState state;
  final OpenRegisterNotifier notifier;
  final VoidCallback onNext;

  const _Step1Breakdown({
    required this.state,
    required this.notifier,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###', 'es_CO');

    return Column(
      children: [
        // Total en tiempo real (sticky en la parte superior)
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total de apertura',
                  style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '\$${fmt.format(state.total)}',
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Lista de denominaciones
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            children: [
              _SectionHeader(label: 'Monedas'),
              const SizedBox(height: 8),
              ...AppConstants.coinDenominations.entries.map((e) =>
                  Padding(
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
              _SectionHeader(label: 'Billetes'),
              const SizedBox(height: 8),
              ...AppConstants.billDenominations.entries.map((e) =>
                  Padding(
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

        // Botón siguiente
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onNext,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Siguiente'),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Step 2: Notas ─────────────────────────────────────────────

class _Step2Notes extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const _Step2Notes({
    required this.controller,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Observaciones del turno',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Registra cualquier situación especial al iniciar tu turno. Es opcional.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 24),

          // Campo de notas
          TextField(
            controller: controller,
            maxLines: 6,
            maxLength: AppConstants.maxNotesLength,
            keyboardType: TextInputType.multiline,
            style: const TextStyle(color: AppColors.textPrimary, height: 1.5),
            decoration: InputDecoration(
              hintText:
                  'Ej: Se inicia con \$20.000 menos por cambio entregado ayer...',
              alignLabelWithHint: true,
              counterStyle: const TextStyle(color: AppColors.textSecondary),
              fillColor: AppColors.surfaceCard,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
          ),
          const Spacer(),

          // Botones navegación
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onBack,
                  child: const Text('Atrás'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onNext,
                  child: const Text('Siguiente'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Step 3: Confirmación y resumen ────────────────────────────

class _Step3Confirm extends StatelessWidget {
  final OpenRegisterState state;
  final bool isLoading;
  final VoidCallback onBack;
  final VoidCallback onConfirm;

  const _Step3Confirm({
    required this.state,
    required this.isLoading,
    required this.onBack,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###', 'es_CO');
    final nonZero = state.nonZeroBreakdown;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Resumen de apertura',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),

          // Monto total destacado
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.15),
                  AppColors.secondary.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                const Text('Total de apertura',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 8),
                Text(
                  '\$${fmt.format(state.total)}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Detalle de denominaciones
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: nonZero.isEmpty
                  ? const Center(
                      child: Text(
                        'No ingresaste ninguna denominación.\n'
                        'El monto de apertura será \$0.',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    )
                  : ListView(
                      children: nonZero.entries.map((e) {
                        final isC = e.key.startsWith('coin_');
                        final denomVal = AppConstants.coinDenominations[e.key] ??
                            AppConstants.billDenominations[e.key] ??
                            0;
                        final subtotal = denomVal * e.value;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            children: [
                              Icon(
                                isC
                                    ? Icons.toll_rounded
                                    : Icons.payments_rounded,
                                size: 16,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '\$${fmt.format(denomVal)}  ×  ${e.value}',
                                style: const TextStyle(
                                    color: AppColors.textPrimary, fontSize: 14),
                              ),
                              const Spacer(),
                              Text(
                                '= \$${fmt.format(subtotal)}',
                                style: const TextStyle(
                                    color: AppColors.textSecondary, fontSize: 13),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),
          ),

          // Notas (si hay)
          if (state.notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.notes_rounded,
                      size: 15, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.notes,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),

          // Botones
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: isLoading ? null : onBack,
                  child: const Text('Atrás'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: isLoading ? null : onConfirm,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Text('Confirmar apertura'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Widgets utilitarios internos ──────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Divider(color: AppColors.border, thickness: 1)),
      ],
    );
  }
}

/// Indicador visual de pasos (US-008)
class _StepIndicator extends StatelessWidget {
  final List<String> steps;
  final int currentStep;

  const _StepIndicator({required this.steps, required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          // Línea conectora
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
                  color: isActive || isCompleted
                      ? AppColors.primary
                      : AppColors.border,
                  width: 2,
                ),
              ),
              child: Center(
                child: isCompleted
                    ? const Icon(Icons.check_rounded,
                        size: 14, color: Colors.black)
                    : Text(
                        '${stepIndex + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isActive
                              ? AppColors.primary
                              : AppColors.textDisabled,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              steps[stepIndex],
              style: TextStyle(
                fontSize: 10,
                color: isActive || isCompleted
                    ? AppColors.primary
                    : AppColors.textDisabled,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        );
      }),
    );
  }
}
