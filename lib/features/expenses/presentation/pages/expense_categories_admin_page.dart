// ============================================================
// lib/features/expenses/presentation/pages/expense_categories_admin_page.dart
// US-036: CRUD de categorías de gasto (AdminMaster)
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/expense_category_icons.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../domain/entities/expense_category.dart';
import '../providers/expense_providers.dart';

class ExpenseCategoriesAdminPage extends ConsumerWidget {
  const ExpenseCategoriesAdminPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(expenseCategoriesProvider);
    final notifier = ref.read(expenseCategoriesProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Categorías de gasto')),
      body: state.isLoading && state.categories.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: notifier.refresh,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: state.categories.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final category = state.categories[i];
                  return _CategoryTile(
                    category: category,
                    onEdit: () => _openForm(context, ref, existing: category),
                    onToggleActive: (value) => _toggleActive(context, ref, category, value),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nueva categoría'),
      ),
    );
  }

  Future<void> _toggleActive(
    BuildContext context,
    WidgetRef ref,
    ExpenseCategory category,
    bool value,
  ) async {
    final result = await ref
        .read(setExpenseCategoryActiveUseCaseProvider)(categoryId: category.id, isActive: value);
    if (!context.mounted) return;
    if (result.failure != null) {
      AppSnackbar.error(context, result.failure!.message);
      return;
    }
    ref.read(expenseCategoriesProvider.notifier).refresh();
  }

  Future<void> _openForm(BuildContext context, WidgetRef ref, {ExpenseCategory? existing}) async {
    final result = await showModalBottomSheet<({String name, String icon})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _CategoryFormSheet(existing: existing),
      ),
    );
    if (result == null || !context.mounted) return;

    final useCase = existing == null
        ? ref.read(createExpenseCategoryUseCaseProvider)(name: result.name, icon: result.icon)
        : ref.read(updateExpenseCategoryUseCaseProvider)(
            categoryId: existing.id, name: result.name, icon: result.icon);

    final catResult = await useCase;
    if (!context.mounted) return;
    if (catResult.failure != null) {
      AppSnackbar.error(context, catResult.failure!.message);
      return;
    }
    ref.read(expenseCategoriesProvider.notifier).refresh();
    AppSnackbar.success(context, existing == null ? 'Categoría creada' : 'Categoría actualizada');
  }
}

class _CategoryTile extends StatelessWidget {
  final ExpenseCategory category;
  final VoidCallback onEdit;
  final ValueChanged<bool> onToggleActive;

  const _CategoryTile({required this.category, required this.onEdit, required this.onToggleActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(expenseCategoryIconFor(category.icon),
              color: category.isActive ? AppColors.primary : AppColors.textDisabled),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              category.name,
              style: TextStyle(
                color: category.isActive ? AppColors.textPrimary : AppColors.textDisabled,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Editar',
            icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.textSecondary),
            onPressed: onEdit,
          ),
          Switch(
            value: category.isActive,
            activeThumbColor: AppColors.primary,
            onChanged: onToggleActive,
          ),
        ],
      ),
    );
  }
}

class _CategoryFormSheet extends StatefulWidget {
  final ExpenseCategory? existing;
  const _CategoryFormSheet({this.existing});

  @override
  State<_CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends State<_CategoryFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late String _selectedIcon;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _selectedIcon = widget.existing?.icon ?? expenseCategoryIconOptions.keys.first;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.existing == null ? 'Nueva categoría' : 'Editar categoría',
              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameCtrl,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(labelText: 'Nombre *', prefixIcon: Icon(Icons.label_outline)),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
            ),
            const SizedBox(height: 16),
            const Text('Ícono', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: expenseCategoryIconOptions.entries.map((entry) {
                final selected = _selectedIcon == entry.key;
                return InkWell(
                  onTap: () => setState(() => _selectedIcon = entry.key),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary.withValues(alpha: 0.15) : AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: selected ? AppColors.primary : AppColors.border),
                    ),
                    child: Icon(entry.value, color: selected ? AppColors.primary : AppColors.textSecondary),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  if (!_formKey.currentState!.validate()) return;
                  Navigator.pop(context, (name: _nameCtrl.text.trim(), icon: _selectedIcon));
                },
                child: const Text('Guardar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
