// ============================================================
// lib/features/pos/presentation/providers/pos_catalog_provider.dart
// Búsqueda + catálogo del POS — US-026, US-033
// Provider independiente de productListProvider (admin) para no
// compartir estado de filtros entre pantallas distintas — mismo
// criterio ya aplicado en InventoryListNotifier (EP-04).
// ============================================================

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../products/domain/entities/product.dart';
import '../../../products/domain/use_cases/product_use_cases.dart';
import '../../../products/presentation/providers/product_providers.dart'
    show getProductsUseCaseProvider;
import '../../../../core/errors/failures.dart';

class PosCatalogState {
  final List<Product> products;
  final bool isLoading;
  final Failure? failure;
  final String? searchQuery;
  final String? filterCategory;

  const PosCatalogState({
    this.products = const [],
    this.isLoading = false,
    this.failure,
    this.searchQuery,
    this.filterCategory,
  });

  PosCatalogState copyWith({
    List<Product>? products,
    bool? isLoading,
    Failure? failure,
    String? searchQuery,
    String? filterCategory,
    bool clearFailure = false,
    bool clearCategory = false,
  }) =>
      PosCatalogState(
        products: products ?? this.products,
        isLoading: isLoading ?? this.isLoading,
        failure: clearFailure ? null : (failure ?? this.failure),
        searchQuery: searchQuery ?? this.searchQuery,
        filterCategory: clearCategory ? null : (filterCategory ?? this.filterCategory),
      );
}

class PosCatalogNotifier extends StateNotifier<PosCatalogState> {
  final GetProductsUseCase _getProducts;
  Timer? _debounce;
  StreamSubscription<List<Map<String, dynamic>>>? _realtimeSub;

  PosCatalogNotifier(this._getProducts, SupabaseClient client) : super(const PosCatalogState()) {
    load();
    // Refresco en tiempo real cuando cambia la tabla products (ej. un
    // ajuste de stock, una venta o una edición hecha desde otra sesión)
    // — mismo criterio que InventoryListNotifier (EP-04).
    _realtimeSub = client.from('products').stream(primaryKey: ['id']).listen((_) {
      load();
    });
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearFailure: true);

    final result = await _getProducts(
      query: state.searchQuery,
      category: state.filterCategory,
      activeOnly: true,
      pageSize: 100,
    );

    if (result.failure != null) {
      state = state.copyWith(isLoading: false, failure: result.failure);
    } else {
      state = state.copyWith(isLoading: false, products: result.products);
    }
  }

  /// US-026: búsqueda por nombre/código con debounce de 300ms.
  void search(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      state = state.copyWith(searchQuery: query.isEmpty ? null : query);
      load();
    });
  }

  /// US-033: filtro de categoría del catálogo en grid.
  Future<void> filterByCategory(String? category) async {
    state = state.copyWith(filterCategory: category, clearCategory: category == null);
    await load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _realtimeSub?.cancel();
    super.dispose();
  }
}

final posCatalogProvider =
    StateNotifierProvider.autoDispose<PosCatalogNotifier, PosCatalogState>(
  (ref) => PosCatalogNotifier(ref.read(getProductsUseCaseProvider), ref.read(supabaseClientProvider)),
);
