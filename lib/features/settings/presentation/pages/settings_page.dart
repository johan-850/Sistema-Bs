import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/providers/scan_feedback_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/confirmation_dialog.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/store_settings_providers.dart';

/// US-005 — Configuración general con logout seguro para AM y Cajero
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateStreamProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Perfil ────────────────────────────────────────
          if (user != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    child: Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                        const SizedBox(height: 2),
                        Text(user.email, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            user.isAdmin ? 'Admin Master' : 'Cajero',
                            style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // ── QR de pago (solo AdminMaster) ──────────────────
          if (user != null && user.isAdmin) ...[
            const SizedBox(height: 20),
            const _QrSettingsCard(),
            const SizedBox(height: 16),
            const _ExpenseSettingsCard(),
            const SizedBox(height: 16),
            const _CashClosingSettingsCard(),
            const SizedBox(height: 16),
            const _WeeklyReportSettingsCard(),
          ],

          // ── Escaneo (US-057) ───────────────────────────────
          // Fuera del bloque de AdminMaster a propósito: es preferencia
          // de este celular y el cajero es quien más escanea.
          const SizedBox(height: 16),
          const _ScanFeedbackSettingsCard(),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 8),

          // ── Cerrar sesión (US-005) ─────────────────────────
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: AppColors.error),
            title: const Text('Cerrar sesión', style: TextStyle(color: AppColors.error)),
            subtitle: const Text('Elimina el token de sesión local'),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            onTap: () => _confirmLogout(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    await ConfirmationDialog.show(
      context,
      title: 'Cerrar sesión',
      message: '¿Seguro que deseas cerrar tu sesión? Serás redirigido al login.',
      confirmLabel: 'Cerrar sesión',
      cancelLabel: 'Cancelar',
      isDangerous: true,
      onConfirm: () async {
        final result = await ref.read(logoutUseCaseProvider).call();
        if (context.mounted) {
          if (result.success) {
            context.go('/login');
          } else {
            AppSnackbar.error(context, result.failure?.message ?? 'Error al cerrar sesión');
          }
        }
      },
    );
  }
}

/// Tarjeta para que el AdminMaster suba el QR real de pago del negocio.
/// El cajero lo verá en la pantalla de cobro cuando elija "Transferencia"
/// o "Mixto" — hasta que se suba, esa pantalla muestra un aviso.
class _QrSettingsCard extends ConsumerStatefulWidget {
  const _QrSettingsCard();

  @override
  ConsumerState<_QrSettingsCard> createState() => _QrSettingsCardState();
}

class _QrSettingsCardState extends ConsumerState<_QrSettingsCard> {
  bool _isUploading = false;

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(storeSettingsProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.qr_code_2_rounded, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text('QR de pago (Transferencias)',
                  style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'El cajero lo mostrará al cliente cuando cobre por transferencia.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 14),
          settingsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
            error: (_, _) => const Text(
              'No se pudo cargar la configuración.',
              style: TextStyle(color: AppColors.error, fontSize: 13),
            ),
            data: (settings) => _buildContent(context, settings?.qrImageUrl),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, String? qrImageUrl) {
    final hasQr = qrImageUrl != null && qrImageUrl.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: _isUploading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : hasQr
                    ? Image.network(qrImageUrl, fit: BoxFit.contain)
                    : const Center(
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(
                            'Aún no se ha configurado el QR',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textDisabled, fontSize: 12),
                          ),
                        ),
                      ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isUploading ? null : () => _showImageSourceSheet(hasQr ? qrImageUrl : null),
                icon: const Icon(Icons.upload_rounded, size: 18),
                label: Text(hasQr ? 'Cambiar QR' : 'Subir QR'),
              ),
            ),
            if (hasQr) ...[
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Quitar QR',
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                onPressed: _isUploading ? null : () => _confirmRemove(qrImageUrl),
              ),
            ],
          ],
        ),
      ],
    );
  }

  void _showImageSourceSheet(String? currentUrl) {
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
                _pickAndUpload(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
              title: const Text('Elegir de galería', style: TextStyle(color: AppColors.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUpload(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUpload(ImageSource source) async {
    final XFile? picked;
    try {
      picked = await ImagePicker().pickImage(source: source, maxWidth: 1024, imageQuality: 85);
    } catch (_) {
      if (mounted) AppSnackbar.error(context, 'No se pudo acceder a la cámara/galería.');
      return;
    }
    if (picked == null || !mounted) return;

    setState(() => _isUploading = true);

    final bytes = await picked.readAsBytes();
    final ext = picked.name.contains('.') ? picked.name.split('.').last : 'jpg';
    final result = await ref.read(updateQrImageUseCaseProvider)(bytes, ext);

    if (!mounted) return;
    setState(() => _isUploading = false);

    if (result.failure != null) {
      AppSnackbar.error(context, result.failure!.message);
      return;
    }
    ref.invalidate(storeSettingsProvider);
    AppSnackbar.success(context, 'QR actualizado');
  }

  Future<void> _confirmRemove(String currentUrl) {
    return ConfirmationDialog.show(
      context,
      title: 'Quitar QR',
      message: '¿Seguro que quieres quitar el QR de pago? El cajero dejará de verlo al cobrar.',
      confirmLabel: 'Quitar',
      isDangerous: true,
      onConfirm: () async {
        setState(() => _isUploading = true);
        final result = await ref.read(removeQrImageUseCaseProvider)(currentUrl);
        if (!mounted) return;
        setState(() => _isUploading = false);
        if (result.failure != null) {
          AppSnackbar.error(context, result.failure!.message);
          return;
        }
        ref.invalidate(storeSettingsProvider);
      },
    );
  }
}

/// EP-06 (US-034/US-035): límite de gasto sugerido y ventana de edición.
class _ExpenseSettingsCard extends ConsumerStatefulWidget {
  const _ExpenseSettingsCard();

  @override
  ConsumerState<_ExpenseSettingsCard> createState() => _ExpenseSettingsCardState();
}

class _ExpenseSettingsCardState extends ConsumerState<_ExpenseSettingsCard> {
  final _maxAmountCtrl = TextEditingController();
  final _windowCtrl = TextEditingController();
  bool _isSaving = false;
  bool _initialized = false;

  @override
  void dispose() {
    _maxAmountCtrl.dispose();
    _windowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(storeSettingsProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.payments_outlined, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text('Gastos de caja',
                  style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Configura el límite sugerido por gasto y cuánto tiempo puede editarlo el cajero.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 14),
          settingsAsync.when(
            loading: () => const Center(
              child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: AppColors.primary)),
            ),
            error: (_, _) => const Text('No se pudo cargar la configuración.',
                style: TextStyle(color: AppColors.error, fontSize: 13)),
            data: (settings) {
              if (!_initialized) {
                _maxAmountCtrl.text = settings?.maxExpenseAmount != null
                    ? settings!.maxExpenseAmount!.toStringAsFixed(0)
                    : '';
                _windowCtrl.text = '${settings?.expenseEditWindowMinutes ?? 10}';
                _initialized = true;
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _maxAmountCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Monto máximo sugerido (opcional)',
                      prefixIcon: Icon(Icons.attach_money_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _windowCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Minutos para poder editar un gasto',
                      prefixIcon: Icon(Icons.timer_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                            )
                          : const Text('Guardar'),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final window = int.tryParse(_windowCtrl.text);
    if (window == null || window <= 0) {
      AppSnackbar.error(context, 'La ventana de edición debe ser mayor a 0.');
      return;
    }
    final maxAmount = _maxAmountCtrl.text.isEmpty ? null : double.tryParse(_maxAmountCtrl.text);

    setState(() => _isSaving = true);
    final result = await ref.read(updateExpenseSettingsUseCaseProvider)(
      maxExpenseAmount: maxAmount,
      expenseEditWindowMinutes: window,
    );
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (result.failure != null) {
      AppSnackbar.error(context, result.failure!.message);
      return;
    }
    ref.invalidate(storeSettingsProvider);
    AppSnackbar.success(context, 'Configuración guardada');
  }
}

/// EP-07 (US-041): umbral de diferencia de caja que exige comentario
/// obligatorio al cerrar turno.
class _CashClosingSettingsCard extends ConsumerStatefulWidget {
  const _CashClosingSettingsCard();

  @override
  ConsumerState<_CashClosingSettingsCard> createState() => _CashClosingSettingsCardState();
}

class _CashClosingSettingsCardState extends ConsumerState<_CashClosingSettingsCard> {
  final _thresholdCtrl = TextEditingController();
  bool _isSaving = false;
  bool _initialized = false;

  @override
  void dispose() {
    _thresholdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(storeSettingsProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lock_clock_outlined, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text('Cierre de caja',
                  style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Diferencia de caja (en pesos) a partir de la cual el cajero debe justificar el cierre con un comentario.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 14),
          settingsAsync.when(
            loading: () => const Center(
              child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: AppColors.primary)),
            ),
            error: (_, _) => const Text('No se pudo cargar la configuración.',
                style: TextStyle(color: AppColors.error, fontSize: 13)),
            data: (settings) {
              if (!_initialized) {
                _thresholdCtrl.text = (settings?.cashDiffCommentThreshold ?? 5000).toStringAsFixed(0);
                _initialized = true;
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _thresholdCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Umbral de diferencia',
                      prefixIcon: Icon(Icons.attach_money_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                            )
                          : const Text('Guardar'),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final threshold = double.tryParse(_thresholdCtrl.text);
    if (threshold == null || threshold < 0) {
      AppSnackbar.error(context, 'Ingresa un umbral válido.');
      return;
    }

    setState(() => _isSaving = true);
    final result = await ref.read(updateCashDiffCommentThresholdUseCaseProvider)(threshold);
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (result.failure != null) {
      AppSnackbar.error(context, result.failure!.message);
      return;
    }
    ref.invalidate(storeSettingsProvider);
    AppSnackbar.success(context, 'Configuración guardada');
  }
}

/// EP-09 (US-054): activar/desactivar el reporte semanal automático y
/// probarlo con un envío inmediato antes de confiar en el cron.
class _WeeklyReportSettingsCard extends ConsumerStatefulWidget {
  const _WeeklyReportSettingsCard();

  @override
  ConsumerState<_WeeklyReportSettingsCard> createState() => _WeeklyReportSettingsCardState();
}

class _WeeklyReportSettingsCardState extends ConsumerState<_WeeklyReportSettingsCard> {
  final _emailCtrl = TextEditingController();
  bool _enabled = false;
  bool _isSaving = false;
  bool _isSending = false;
  bool _initialized = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(storeSettingsProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.mail_outline_rounded, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text('Reporte semanal por correo',
                  style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Envía cada lunes 7:00 a.m. un resumen de ventas de la semana, top 5 productos y alertas de stock.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 14),
          settingsAsync.when(
            loading: () => const Center(
              child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: AppColors.primary)),
            ),
            error: (_, _) => const Text('No se pudo cargar la configuración.',
                style: TextStyle(color: AppColors.error, fontSize: 13)),
            data: (settings) {
              if (!_initialized) {
                _enabled = settings?.weeklyReportEnabled ?? false;
                _emailCtrl.text = settings?.weeklyReportEmail ?? '';
                _initialized = true;
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Activar reporte semanal',
                            style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                      ),
                      Switch(
                        value: _enabled,
                        activeThumbColor: AppColors.primary,
                        onChanged: (v) => setState(() => _enabled = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Correo destino',
                      prefixIcon: Icon(Icons.alternate_email_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _save,
                          child: _isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                )
                              : const Text('Guardar'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isSending ? null : _sendNow,
                          child: _isSending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                )
                              : const Text('Enviar de prueba ahora'),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final email = _emailCtrl.text.trim();
    if (_enabled && email.isEmpty) {
      AppSnackbar.error(context, 'Ingresa un correo destino para activar el reporte.');
      return;
    }

    setState(() => _isSaving = true);
    final result = await ref.read(updateWeeklyReportSettingsUseCaseProvider)(
      enabled: _enabled,
      email: email.isEmpty ? null : email,
    );
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (result.failure != null) {
      AppSnackbar.error(context, result.failure!.message);
      return;
    }
    ref.invalidate(storeSettingsProvider);
    AppSnackbar.success(context, 'Configuración guardada');
  }

  Future<void> _sendNow() async {
    if (_emailCtrl.text.trim().isEmpty) {
      AppSnackbar.error(context, 'Guarda un correo destino antes de enviar la prueba.');
      return;
    }

    setState(() => _isSending = true);
    final failure = await ref.read(sendWeeklyReportNowUseCaseProvider)();
    if (!mounted) return;
    setState(() => _isSending = false);

    if (failure != null) {
      AppSnackbar.error(context, failure.message);
      return;
    }
    AppSnackbar.success(context, 'Reporte enviado');
  }
}

/// US-057: sonido y vibración al escanear. Se guarda en el dispositivo,
/// no en Supabase — silenciar este celular no silencia los demás.
class _ScanFeedbackSettingsCard extends ConsumerWidget {
  const _ScanFeedbackSettingsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(scanFeedbackPrefsProvider);
    final notifier = ref.read(scanFeedbackPrefsProvider.notifier);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text('Escaneo',
                  style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Aviso al leer un código de barras. Solo aplica a este dispositivo.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 6),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Sonido', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
            value: prefs.soundEnabled,
            activeThumbColor: AppColors.primary,
            onChanged: notifier.setSoundEnabled,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Vibración', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
            value: prefs.vibrationEnabled,
            activeThumbColor: AppColors.primary,
            onChanged: notifier.setVibrationEnabled,
          ),
        ],
      ),
    );
  }
}
