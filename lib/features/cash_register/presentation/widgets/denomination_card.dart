// ============================================================
// lib/features/cash_register/presentation/widgets/denomination_card.dart
// Tarjeta individual para cada billete o moneda con stepper integrado
// US-009
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../../../core/theme/app_theme.dart';

/// Tarjeta para ingresar la cantidad de una denominación específica.
///
/// Muestra: icono de moneda/billete, valor formateado, stepper +/–
/// y un campo de texto para edición directa.
class DenominationCard extends StatefulWidget {
  final String denomKey;
  final int denomValue;
  final bool isCoin;
  final int quantity;
  final ValueChanged<int> onChanged;

  const DenominationCard({
    super.key,
    required this.denomKey,
    required this.denomValue,
    required this.isCoin,
    required this.quantity,
    required this.onChanged,
  });

  @override
  State<DenominationCard> createState() => _DenominationCardState();
}

class _DenominationCardState extends State<DenominationCard>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _ctrl;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;
  final _fmt = NumberFormat('#,###', 'es_CO');

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: widget.quantity > 0 ? widget.quantity.toString() : '',
    );

    // Animación de pulso cuando el valor cambia
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(DenominationCard old) {
    super.didUpdateWidget(old);
    if (old.quantity != widget.quantity) {
      final newText = widget.quantity > 0 ? widget.quantity.toString() : '';
      if (_ctrl.text != newText) {
        _ctrl.text = newText;
        _ctrl.selection =
            TextSelection.collapsed(offset: _ctrl.text.length);
      }
      // Pulso visual al cambiar
      _pulseController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _onDecrement() {
    if (widget.quantity > 0) {
      widget.onChanged(widget.quantity - 1);
    }
  }

  void _onIncrement() => widget.onChanged(widget.quantity + 1);

  void _onTextChanged(String value) {
    final parsed = int.tryParse(value);
    if (parsed != null) {
      widget.onChanged(parsed.clamp(0, 9999));
    } else if (value.isEmpty) {
      widget.onChanged(0);
    }
  }

  /// Subtotal de esta denominación en pesos
  double get _subtotal => widget.denomValue * widget.quantity.toDouble();

  /// Formatea el valor de la denominación: "$50" o "$1.000"
  String get _denomLabel => '\$${_fmt.format(widget.denomValue)}';

  @override
  Widget build(BuildContext context) {
    final isActive = widget.quantity > 0;

    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (context, child) => Transform.scale(
        scale: _pulseAnim.value,
        child: child,
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withValues(alpha: 0.08)
              : AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive ? AppColors.primary : AppColors.border,
            width: isActive ? 1.5 : 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // ── Icono + etiqueta ─────────────────────────────
            _DenomIcon(isCoin: widget.isCoin, isActive: isActive),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _denomLabel,
                    style: TextStyle(
                      color: isActive
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  if (isActive) ...[
                    const SizedBox(height: 2),
                    Text(
                      '= \$${_fmt.format(_subtotal)}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── Stepper ──────────────────────────────────────
            _StepperButton(
              icon: Icons.remove_rounded,
              onTap: _onDecrement,
              enabled: widget.quantity > 0,
            ),
            const SizedBox(width: 6),
            // Campo de cantidad directa
            SizedBox(
              width: 44,
              child: TextField(
                controller: _ctrl,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 8),
                  fillColor: AppColors.surfaceElevated,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  hintText: '0',
                  hintStyle: const TextStyle(
                    color: AppColors.textDisabled,
                    fontSize: 14,
                  ),
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                onChanged: _onTextChanged,
              ),
            ),
            const SizedBox(width: 6),
            _StepperButton(
              icon: Icons.add_rounded,
              onTap: _onIncrement,
              enabled: true,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Subwidgets privados ────────────────────────────────────────

class _DenomIcon extends StatelessWidget {
  final bool isCoin;
  final bool isActive;

  const _DenomIcon({required this.isCoin, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.primary.withValues(alpha: 0.15)
            : AppColors.surfaceElevated,
        shape: isCoin ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isCoin ? null : BorderRadius.circular(8),
      ),
      child: Icon(
        isCoin ? Icons.toll_rounded : Icons.payments_rounded,
        color: isActive ? AppColors.primary : AppColors.textSecondary,
        size: 18,
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  const _StepperButton({
    required this.icon,
    required this.onTap,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.primary.withValues(alpha: 0.15)
              : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 16,
          color: enabled ? AppColors.primary : AppColors.textDisabled,
        ),
      ),
    );
  }
}
