// ============================================================
// lib/features/expenses/presentation/widgets/register_expense_sheet.dart
// US-034: registrar un gasto — también reutilizado para editar (US-035)
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/expense_category_icons.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/confirmation_dialog.dart';
import '../../../settings/presentation/providers/store_settings_providers.dart';
import '../../domain/entities/expense.dart';
import '../../domain/entities/expense_category.dart';
import '../providers/expense_providers.dart';

class RegisterExpenseSheet extends ConsumerStatefulWidget {
  final String cashRegisterId;

  /// Si no es null, el formulario abre en modo edición (US-035).
  final Expense? existing;

  const RegisterExpenseSheet({super.key, required this.cashRegisterId, this.existing});

  static Future<bool?> show(BuildContext context, {required String cashRegisterId, Expense? existing}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: RegisterExpenseSheet(cashRegisterId: cashRegisterId, existing: existing),
      ),
    );
  }

  @override
  ConsumerState<RegisterExpenseSheet> createState() => _RegisterExpenseSheetState();
}

class _RegisterExpenseSheetState extends ConsumerState<RegisterExpenseSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountCtrl;
  late final TextEditingController _descriptionCtrl;
  String? _categoryId;
  bool _categoryInitialized = false;

  bool get _isEditMode => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
      text: widget.existing != null ? widget.existing!.amount.toStringAsFixed(0) : '',
    );
    _descriptionCtrl = TextEditingController(text: widget.existing?.description ?? '');
    _categoryId = widget.existing?.categoryId;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesState = ref.watch(expenseCategoriesProvider);
    final formState = ref.watch(registerExpenseProvider);
    final currencyFmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

    // Si estamos creando (no editando), preselecciona la primera categoría
    // activa apenas carguen — evita un dropdown sin selección inicial.
    if (!_isEditMode && !_categoryInitialized && categoriesState.active.isNotEmpty) {
      _categoryId = categoriesState.active.first.id;
      _categoryInitialized = true;
    }

    ref.listen<RegisterExpenseState>(registerExpenseProvider, (_, next) {
      if (next.failure != null) AppSnackbar.error(context, next.failure!.message);
      if (next.success) Navigator.pop(context, true);
    });

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.payments_outlined, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  _isEditMode ? 'Editar gasto' : 'Registrar gasto',
                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 20),

            TextFormField(
              controller: _amountCtrl,
              style: const TextStyle(color: AppColors.textPrimary),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Monto *',
                prefixIcon: Icon(Icons.attach_money_rounded),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Obligatorio';
                final val = double.tryParse(v);
                if (val == null || val <= 0) return 'Debe ser mayor a 0';
                return null;
              },
            ),
            const SizedBox(height: 12),

            categoriesState.active.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No hay categorías activas configuradas. Pide al AdminMaster que active al menos una.',
                      style: TextStyle(color: AppColors.error, fontSize: 13),
                    ),
                  )
                : DropdownButtonFormField<String>(
                    initialValue: _categoryId,
                    dropdownColor: AppColors.surfaceElevated,
                    isExpanded: true,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                    decoration: const InputDecoration(
                      labelText: 'Categoría *',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: categoriesState.active
                        .map((c) => DropdownMenuItem(
                              value: c.id,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(expenseCategoryIconFor(c.icon), size: 18, color: AppColors.textSecondary),
                                  const SizedBox(width: 8),
                                  Text(c.name),
                                ],
                              ),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _categoryId = v),
                    validator: (v) => v == null ? 'Obligatorio' : null,
                  ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _descriptionCtrl,
              style: const TextStyle(color: AppColors.textPrimary),
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Descripción (opcional)',
                prefixIcon: Icon(Icons.description_outlined),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: formState.isLoading || categoriesState.active.isEmpty
                    ? null
                    : () => _confirmAndSubmit(currencyFmt, categoriesState.active),
                icon: formState.isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(_isEditMode ? 'Guardar cambios' : 'Confirmar gasto'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmAndSubmit(NumberFormat currencyFmt, List<ExpenseCategory> categories) {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.parse(_amountCtrl.text);
    final category = categories.firstWhere((c) => c.id == _categoryId);
    final description = _descriptionCtrl.text.trim();
    final maxAmount = ref.read(storeSettingsProvider).valueOrNull?.maxExpenseAmount;
    final exceedsMax = maxAmount != null && amount > maxAmount;

    void doSubmit() {
      if (_isEditMode) {
        ref.read(registerExpenseProvider.notifier).update(
              expenseId: widget.existing!.id,
              categoryId: category.id,
              categoryName: category.name,
              amount: amount,
              description: description,
            );
      } else {
        ref.read(registerExpenseProvider.notifier).create(
              cashRegisterId: widget.cashRegisterId,
              categoryId: category.id,
              categoryName: category.name,
              amount: amount,
              description: description,
            );
      }
    }

    final baseMessage =
        '¿Confirmas ${_isEditMode ? 'guardar' : 'registrar'} un gasto de ${currencyFmt.format(amount)} en "${category.name}"?';

    ConfirmationDialog.show(
      context,
      title: exceedsMax ? 'Gasto elevado' : (_isEditMode ? 'Guardar cambios' : 'Registrar gasto'),
      message: exceedsMax
          ? '$baseMessage\n\nEste monto supera el máximo habitual configurado (${currencyFmt.format(maxAmount)}).'
          : baseMessage,
      confirmLabel: exceedsMax ? 'Registrar de todas formas' : 'Confirmar',
      isDangerous: exceedsMax,
      onConfirm: doSubmit,
    );
  }
}
