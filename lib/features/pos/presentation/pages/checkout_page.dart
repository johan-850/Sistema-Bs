// ============================================================
// lib/features/pos/presentation/pages/checkout_page.dart
// Cobro — US-030 (método de pago + cambio)
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../cash_register/presentation/providers/cash_register_providers.dart';
import '../../../settings/presentation/providers/store_settings_providers.dart';
import '../../domain/entities/cart_item.dart';
import '../providers/cart_providers.dart';
import '../providers/checkout_provider.dart';
import 'receipt_page.dart';

class CheckoutPage extends ConsumerStatefulWidget {
  const CheckoutPage({super.key});

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  final _cashController = TextEditingController();
  final _transferController = TextEditingController();
  final _currencyFmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

  @override
  void dispose() {
    _cashController.dispose();
    _transferController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final checkout = ref.watch(checkoutProvider);
    final checkoutNotifier = ref.read(checkoutProvider.notifier);
    final registerAsync = ref.watch(activeRegisterProvider);

    ref.listen<CheckoutState>(checkoutProvider, (previous, next) {
      if (next.failure != null) {
        AppSnackbar.error(context, next.failure!.message);
      }
      if (next.sale != null && previous?.sale == null) {
        final items = List<CartItem>.from(cart.items);
        final sale = next.sale!;
        ref.read(cartProvider.notifier).clear();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => ReceiptPage(sale: sale, items: items)),
        );
      }
    });

    final total = cart.totalAmount;
    final change = (checkout.cashAmount ?? 0) - total;
    final mixedSum = (checkout.cashAmount ?? 0) + (checkout.transferAmount ?? 0);
    final mixedMatches = (mixedSum - total).abs() < 1;

    final canConfirm = switch (checkout.paymentMethod) {
      'efectivo' => (checkout.cashAmount ?? 0) >= total,
      'transferencia' => true,
      'mixto' => mixedMatches,
      _ => false,
    };

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Cobrar')),
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

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    const Text('Total a cobrar',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(
                      _currencyFmt.format(total),
                      style: const TextStyle(
                          color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 32),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text('Método de pago',
                  style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _PaymentMethodButton(
                      label: 'Efectivo',
                      icon: Icons.payments_outlined,
                      selected: checkout.paymentMethod == 'efectivo',
                      onTap: () => checkoutNotifier.setPaymentMethod('efectivo'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _PaymentMethodButton(
                      label: 'Transferencia',
                      icon: Icons.account_balance_outlined,
                      selected: checkout.paymentMethod == 'transferencia',
                      onTap: () => checkoutNotifier.setPaymentMethod('transferencia'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _PaymentMethodButton(
                      label: 'Mixto',
                      icon: Icons.call_split_rounded,
                      selected: checkout.paymentMethod == 'mixto',
                      onTap: () => checkoutNotifier.setPaymentMethod('mixto'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              if (checkout.paymentMethod == 'efectivo') ...[
                TextField(
                  controller: _cashController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Monto recibido *',
                    prefixIcon: Icon(Icons.attach_money_rounded),
                  ),
                  onChanged: (v) => checkoutNotifier.setCashAmount(double.tryParse(v)),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: change >= 0
                        ? AppColors.success.withValues(alpha: 0.1)
                        : AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: change >= 0 ? AppColors.success : AppColors.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Cambio a entregar',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                      Text(
                        _currencyFmt.format(change > 0 ? change : 0),
                        style: TextStyle(
                          color: change >= 0 ? AppColors.success : AppColors.textDisabled,
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (checkout.paymentMethod == 'mixto') ...[
                TextField(
                  controller: _cashController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Efectivo *',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                  onChanged: (v) => checkoutNotifier.setCashAmount(double.tryParse(v)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _transferController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Transferencia *',
                    prefixIcon: Icon(Icons.account_balance_outlined),
                  ),
                  onChanged: (v) => checkoutNotifier.setTransferAmount(double.tryParse(v)),
                ),
                const SizedBox(height: 12),
                Text(
                  mixedMatches
                      ? 'La suma coincide con el total.'
                      : 'Suma actual: ${_currencyFmt.format(mixedSum)} — faltan ${_currencyFmt.format(total - mixedSum)}',
                  style: TextStyle(color: mixedMatches ? AppColors.success : AppColors.warning, fontSize: 13),
                ),
                const SizedBox(height: 16),
                const _TransferProofSection(),
              ] else if (checkout.paymentMethod == 'transferencia') ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Confirma cuando el cliente haya realizado la transferencia.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                const _TransferProofSection(),
              ],

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: (!canConfirm || checkout.isLoading)
                      ? null
                      : () => checkoutNotifier.confirm(cashRegisterId: register.id, items: cart.items),
                  icon: checkout.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Icon(Icons.check_circle_outline_rounded),
                  label: const Text('Confirmar cobro'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PaymentMethodButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _PaymentMethodButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.15) : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? AppColors.primary : AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? AppColors.primary : AppColors.textSecondary, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? AppColors.primary : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// QR de pago del negocio + foto opcional del comprobante — se muestra
/// en 'transferencia' y 'mixto'. El QR lo configura el AdminMaster desde
/// Configuración; si todavía no lo subió, se avisa en vez de bloquear.
class _TransferProofSection extends ConsumerWidget {
  const _TransferProofSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(storeSettingsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              const Text('Escanea para pagar',
                  style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 12),
              settingsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (_, _) => const _QrPlaceholder(),
                data: (settings) => (settings?.qrImageUrl != null && settings!.qrImageUrl!.isNotEmpty)
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(settings.qrImageUrl!, width: 200, height: 200, fit: BoxFit.contain),
                      )
                    : const _QrPlaceholder(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const _ReceiptPhotoPicker(),
      ],
    );
  }
}

class _QrPlaceholder extends StatelessWidget {
  const _QrPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      height: 200,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: const Text(
        'El AdminMaster aún no configuró el QR de pago.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.textDisabled, fontSize: 12),
      ),
    );
  }
}

class _ReceiptPhotoPicker extends ConsumerWidget {
  const _ReceiptPhotoPicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checkout = ref.watch(checkoutProvider);
    final notifier = ref.read(checkoutProvider.notifier);
    final hasPhoto = checkout.receiptPhotoUrl != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Foto del comprobante (opcional)',
              style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 12),
          if (checkout.isUploadingReceiptPhoto)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          else if (hasPhoto) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(checkout.receiptPhotoUrl!, height: 160, width: double.infinity, fit: BoxFit.cover),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pick(context, ref),
                    icon: const Icon(Icons.camera_alt_rounded, size: 18),
                    label: const Text('Retomar'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Quitar foto',
                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                  onPressed: notifier.removeReceiptPhoto,
                ),
              ],
            ),
          ] else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _pick(context, ref),
                icon: const Icon(Icons.camera_alt_outlined, size: 18),
                label: const Text('Tomar foto del comprobante'),
              ),
            ),
        ],
      ),
    );
  }

  void _pick(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
              title: const Text('Tomar foto', style: TextStyle(color: AppColors.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUpload(context, ref, ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
              title: const Text('Elegir de galería', style: TextStyle(color: AppColors.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUpload(context, ref, ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUpload(BuildContext context, WidgetRef ref, ImageSource source) async {
    final XFile? picked;
    try {
      picked = await ImagePicker().pickImage(source: source, maxWidth: 1024, imageQuality: 85);
    } catch (_) {
      if (context.mounted) AppSnackbar.error(context, 'No se pudo acceder a la cámara/galería.');
      return;
    }
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final ext = picked.name.contains('.') ? picked.name.split('.').last : 'jpg';
    await ref.read(checkoutProvider.notifier).setReceiptPhoto(bytes, ext);
  }
}
