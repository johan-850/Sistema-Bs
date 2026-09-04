// ============================================================
// lib/features/expenses/presentation/pages/shift_expenses_page.dart
// US-035: gastos del turno activo del cajero
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../cash_register/presentation/providers/cash_register_providers.dart';
import '../../../settings/presentation/providers/store_settings_providers.dart';
import '../../domain/entities/expense.dart';
import '../providers/expense_providers.dart';
import '../widgets/register_expense_sheet.dart';

class ShiftExpensesPage extends ConsumerWidget {
  const ShiftExpensesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registerAsync = ref.watch(activeRegisterProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Gastos del turno')),
      body: registerAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (_, _) => const Center(
          child: Text('Error al cargar la caja', style: TextStyle(color: AppColors.error)),
        ),
        data: (register) {
          if (register == null || !register.isOpen) {
            return const Center(
              child: Text('No hay caja abierta', style: TextStyle(color: AppColors.error)),
            );
          }
          return _ShiftExpensesList(cashRegisterId: register.id);
        },
      ),
      floatingActionButton: registerAsync.valueOrNull?.isOpen == true
          ? FloatingActionButton.extended(
              onPressed: () => RegisterExpenseSheet.show(
                context,
                cashRegisterId: registerAsync.value!.id,
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nuevo gasto'),
            )
          : null,
    );
  }
}

class _ShiftExpensesList extends ConsumerWidget {
  final String cashRegisterId;
  const _ShiftExpensesList({required this.cashRegisterId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(shiftExpensesProvider(cashRegisterId));
    final settingsAsync = ref.watch(storeSettingsProvider);
    final editWindow = Duration(minutes: settingsAsync.valueOrNull?.expenseEditWindowMinutes ?? 10);
    final currencyFmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    final timeFmt = DateFormat('hh:mm a', 'es');

    return Column(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              const Text('Total gastado en el turno',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 4),
              Text(
                currencyFmt.format(state.total),
                style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 26),
              ),
            ],
          ),
        ),
        Expanded(
          child: state.isLoading && state.expenses.isEmpty
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : state.expenses.isEmpty
                  ? const Center(
                      child: Text('Aún no hay gastos registrados en este turno',
                          style: TextStyle(color: AppColors.textSecondary)),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: state.expenses.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final expense = state.expenses[i];
                        final editable = expense.isEditableWithin(editWindow);
                        return _ExpenseTile(
                          expense: expense,
                          editable: editable,
                          currencyFmt: currencyFmt,
                          timeFmt: timeFmt,
                          onTap: editable
                              ? () => RegisterExpenseSheet.show(
                                    context,
                                    cashRegisterId: cashRegisterId,
                                    existing: expense,
                                  )
                              : null,
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  final Expense expense;
  final bool editable;
  final NumberFormat currencyFmt;
  final DateFormat timeFmt;
  final VoidCallback? onTap;

  const _ExpenseTile({
    required this.expense,
    required this.editable,
    required this.currencyFmt,
    required this.timeFmt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.remove_circle_outline_rounded, color: AppColors.error, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(expense.categoryName,
                      style: const TextStyle(
                          color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                  if (expense.description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(expense.description,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 2),
                  Text(timeFmt.format(expense.createdAt.toLocal()),
                      style: const TextStyle(color: AppColors.textDisabled, fontSize: 11)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  currencyFmt.format(expense.amount),
                  style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                if (editable) ...[
                  const SizedBox(height: 2),
                  const Text('Editable', style: TextStyle(color: AppColors.primary, fontSize: 10)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
