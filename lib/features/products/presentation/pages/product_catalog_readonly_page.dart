// ============================================================
// lib/features/products/presentation/pages/product_catalog_readonly_page.dart
// US-018: Catálogo de solo lectura para Cajero
// Reutiliza productListProvider (mismo que el catálogo del AdminMaster),
// sin FAB de crear ni botones de editar/archivar/importar.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/product_list_card.dart';
import '../providers/product_providers.dart';

class ProductCatalogReadonlyPage extends ConsumerStatefulWidget {
  const ProductCatalogReadonlyPage({super.key});

  @override
  ConsumerState<ProductCatalogReadonlyPage> createState() =>
      _ProductCatalogReadonlyPageState();
}

class _ProductCatalogReadonlyPageState
    extends ConsumerState<ProductCatalogReadonlyPage> {
  final _searchController = TextEditingController();
  final _currencyFmt = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0,
  );

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productListProvider);
    final notifier = ref.read(productListProvider.notifier);

    ref.listen<ProductListState>(productListProvider, (_, next) {
      if (next.failure != null) {
        AppSnackbar.error(context, next.failure!.message);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Catálogo'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: state.filterCategory != null,
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.category_outlined),
            ),
            onPressed: () => _showCategorySheet(context, notifier, state),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (q) => notifier.search(q),
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o código de barras...',
                hintStyle: const TextStyle(color: AppColors.textDisabled),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.textSecondary,
                ),
                filled: true,
                fillColor: AppColors.surfaceElevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
          ),
          Expanded(
            child: state.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : state.products.isEmpty
                ? const Center(
                    child: Text(
                      'No se encontraron productos',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: () => notifier.refresh(),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: state.products.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) => ProductListCard(
                        product: state.products[i],
                        currencyFmt: _currencyFmt,
                        showChevron: false,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _showCategorySheet(
    BuildContext context,
    ProductListNotifier notifier,
    ProductListState state,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.category_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Filtrar por Categoría',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    if (state.filterCategory != null)
                      TextButton(
                        onPressed: () {
                          notifier.filterByCategory(null);
                          Navigator.pop(context);
                        },
                        child: const Text('Limpiar'),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ...AppConstants.productCategories.map(
                (cat) => ListTile(
                  leading: Icon(
                    state.filterCategory == cat
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: state.filterCategory == cat
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    size: 20,
                  ),
                  title: Text(
                    cat,
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                  dense: true,
                  onTap: () {
                    notifier.filterByCategory(cat);
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
