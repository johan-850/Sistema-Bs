// ============================================================
// tool/preview/main.dart
// Vista previa sin backend: la app real con repositorios en memoria,
// para revisar pantallas con sesión iniciada sin tocar Supabase.
//
//   flutter build web -t tool/preview/main.dart -o build/preview
//
// El rol se elige por URL: `?rol=cajero` (con caja abierta),
// `?rol=cajero-sin-caja` o, por defecto, AdminMaster.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sistema_bs/features/auth/presentation/providers/auth_providers.dart';
import 'package:sistema_bs/features/cash_register/presentation/providers/cash_register_providers.dart';
import 'package:sistema_bs/features/expenses/presentation/providers/expense_providers.dart';
import 'package:sistema_bs/features/inventory/presentation/providers/inventory_providers.dart';
import 'package:sistema_bs/features/pos/presentation/providers/checkout_provider.dart';
import 'package:sistema_bs/features/products/presentation/providers/product_providers.dart';
import 'package:sistema_bs/features/settings/presentation/providers/store_settings_providers.dart';
import 'package:sistema_bs/features/users/presentation/providers/users_providers.dart';
import 'package:sistema_bs/main.dart' show SistemaBsApp;

import 'fake_repositories.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es', null);

  final rol = Uri.base.queryParameters['rol'];
  final user = rol == null ? previewAdmin : previewCashier;

  runApp(
    ProviderScope(
      overrides: [
        // Los listeners de tiempo real fallan contra este host y se ignoran.
        supabaseClientProvider.overrideWithValue(
          SupabaseClient('http://127.0.0.1:9', 'preview'),
        ),
        authRepositoryProvider.overrideWithValue(PreviewAuthRepository(user)),
        productRepositoryProvider.overrideWithValue(PreviewProductRepository()),
        saleRepositoryProvider.overrideWithValue(PreviewSaleRepository()),
        cashRegisterRepositoryProvider.overrideWithValue(
          PreviewCashRegisterRepository(hasOpenRegister: rol != 'cajero-sin-caja'),
        ),
        expenseRepositoryProvider.overrideWithValue(PreviewExpenseRepository()),
        inventoryRepositoryProvider.overrideWithValue(PreviewInventoryRepository()),
        storeSettingsRepositoryProvider.overrideWithValue(PreviewStoreSettingsRepository()),
        userRepositoryProvider.overrideWithValue(PreviewUserRepository()),
      ],
      child: const SistemaBsApp(),
    ),
  );
}
