// ============================================================
// lib/core/widgets/filter_dropdown.dart
// Dropdown de filtro reutilizable — extraído de
// expenses_report_admin_page.dart al necesitarse en una segunda
// pantalla (sales_history_page.dart, EP-08)
// ============================================================

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class FilterDropdown<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T> onChanged;

  const FilterDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          dropdownColor: AppColors.surfaceElevated,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
          items: items,
          onChanged: (v) => onChanged(v as T),
        ),
      ),
    );
  }
}
