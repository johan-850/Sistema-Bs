// ============================================================
// lib/features/pos/presentation/providers/checkout_provider.dart
// Estado del formulario de cobro — US-030, US-031
// ============================================================

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/sale_remote_datasource.dart';
import '../../data/repositories/sale_repository_impl.dart';
import '../../domain/entities/cart_item.dart';
import '../../domain/entities/sale.dart';
import '../../domain/repositories/sale_repository.dart';
import '../../domain/use_cases/sale_use_cases.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../../core/errors/failures.dart';

// ── DI ──────────────────────────────────────────────────────────

final saleDatasourceProvider = Provider(
  (ref) => SaleRemoteDatasource(ref.read(supabaseClientProvider)),
);

final saleRepositoryProvider = Provider<SaleRepository>(
  (ref) => SaleRepositoryImpl(ref.read(saleDatasourceProvider)),
);

final confirmSaleUseCaseProvider = Provider(
  (ref) => ConfirmSaleUseCase(ref.read(saleRepositoryProvider)),
);

final logCancelledSaleUseCaseProvider = Provider(
  (ref) => LogCancelledSaleUseCase(ref.read(saleRepositoryProvider)),
);

final logLowStockAlertUseCaseProvider = Provider(
  (ref) => LogLowStockAlertUseCase(ref.read(saleRepositoryProvider)),
);

final uploadReceiptPhotoUseCaseProvider = Provider(
  (ref) => UploadReceiptPhotoUseCase(ref.read(saleRepositoryProvider)),
);

final deleteReceiptPhotoUseCaseProvider = Provider(
  (ref) => DeleteReceiptPhotoUseCase(ref.read(saleRepositoryProvider)),
);

// ── Estado del checkout ─────────────────────────────────────────

class CheckoutState {
  final String paymentMethod; // 'efectivo' | 'transferencia' | 'mixto'
  final double? cashAmount;
  final double? transferAmount;
  final bool isLoading;
  final Failure? failure;
  final Sale? sale;

  /// Foto del comprobante de transferencia — opcional, solo aplica a
  /// 'transferencia'/'mixto'. Se sube a Storage al tomarla (no al
  /// confirmar) para que el cajero pueda ver la vista previa antes de
  /// cobrar; [isUploadingReceiptPhoto] cubre esa subida en curso.
  final String? receiptPhotoUrl;
  final bool isUploadingReceiptPhoto;

  const CheckoutState({
    this.paymentMethod = 'efectivo',
    this.cashAmount,
    this.transferAmount,
    this.isLoading = false,
    this.failure,
    this.sale,
    this.receiptPhotoUrl,
    this.isUploadingReceiptPhoto = false,
  });

  CheckoutState copyWith({
    String? paymentMethod,
    double? cashAmount,
    double? transferAmount,
    bool? isLoading,
    Failure? failure,
    Sale? sale,
    bool clearFailure = false,
    String? receiptPhotoUrl,
    bool clearReceiptPhoto = false,
    bool? isUploadingReceiptPhoto,
  }) =>
      CheckoutState(
        paymentMethod: paymentMethod ?? this.paymentMethod,
        cashAmount: cashAmount ?? this.cashAmount,
        transferAmount: transferAmount ?? this.transferAmount,
        isLoading: isLoading ?? this.isLoading,
        failure: clearFailure ? null : (failure ?? this.failure),
        sale: sale ?? this.sale,
        receiptPhotoUrl: clearReceiptPhoto ? null : (receiptPhotoUrl ?? this.receiptPhotoUrl),
        isUploadingReceiptPhoto: isUploadingReceiptPhoto ?? this.isUploadingReceiptPhoto,
      );
}

class CheckoutNotifier extends StateNotifier<CheckoutState> {
  final ConfirmSaleUseCase _confirmSale;
  final UploadReceiptPhotoUseCase _uploadReceiptPhoto;
  final DeleteReceiptPhotoUseCase _deleteReceiptPhoto;

  CheckoutNotifier(this._confirmSale, this._uploadReceiptPhoto, this._deleteReceiptPhoto)
      : super(const CheckoutState());

  void setPaymentMethod(String method) {
    state = CheckoutState(paymentMethod: method); // resetea montos/foto al cambiar de método
  }

  void setCashAmount(double? amount) => state = state.copyWith(cashAmount: amount, clearFailure: true);

  void setTransferAmount(double? amount) =>
      state = state.copyWith(transferAmount: amount, clearFailure: true);

  /// Sube (o reemplaza) la foto del comprobante de transferencia.
  Future<void> setReceiptPhoto(Uint8List bytes, String fileExt) async {
    final oldUrl = state.receiptPhotoUrl;
    state = state.copyWith(isUploadingReceiptPhoto: true, clearFailure: true);

    final result = await _uploadReceiptPhoto(bytes, fileExt);

    if (result.failure != null) {
      state = state.copyWith(isUploadingReceiptPhoto: false, failure: result.failure);
      return;
    }

    state = state.copyWith(isUploadingReceiptPhoto: false, receiptPhotoUrl: result.url);
    if (oldUrl != null) {
      unawaited(_deleteReceiptPhoto(oldUrl));
    }
  }

  void removeReceiptPhoto() {
    final oldUrl = state.receiptPhotoUrl;
    state = state.copyWith(clearReceiptPhoto: true);
    if (oldUrl != null) {
      unawaited(_deleteReceiptPhoto(oldUrl));
    }
  }

  Future<bool> confirm({required String cashRegisterId, required List<CartItem> items}) async {
    state = state.copyWith(isLoading: true, clearFailure: true);

    final result = await _confirmSale(
      cashRegisterId: cashRegisterId,
      paymentMethod: state.paymentMethod,
      cashAmount: state.cashAmount,
      transferAmount: state.transferAmount,
      items: items,
      receiptPhotoUrl: state.receiptPhotoUrl,
    );

    if (result.failure != null) {
      state = state.copyWith(isLoading: false, failure: result.failure);
      return false;
    }

    state = state.copyWith(isLoading: false, sale: result.sale);
    return true;
  }
}

final checkoutProvider = StateNotifierProvider.autoDispose<CheckoutNotifier, CheckoutState>(
  (ref) => CheckoutNotifier(
    ref.read(confirmSaleUseCaseProvider),
    ref.read(uploadReceiptPhotoUseCaseProvider),
    ref.read(deleteReceiptPhotoUseCaseProvider),
  ),
);
