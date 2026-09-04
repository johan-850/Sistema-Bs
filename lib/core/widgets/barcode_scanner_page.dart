// ============================================================
// lib/core/widgets/barcode_scanner_page.dart
// Escáner de código de barras con la cámara del celular.
// Reemplaza el requerimiento original de pistola Bluetooth (EP-10)
// por decisión del negocio: se usa mobile_scanner en su lugar.
// Reutilizable desde cualquier feature (EP-03 hoy, EP-05/POS después).
//
// US-057: destello verde + sonido/vibración al leer un código.
// US-058 (adaptada): si la cámara falla, se muestra el error con
// opción de reintentar o de escribir el código a mano — el flujo de
// venta nunca queda bloqueado.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../providers/scan_feedback_providers.dart';
import '../theme/app_theme.dart';

/// Pantalla completa que abre la cámara y devuelve el código escaneado
/// vía `Navigator.pop(context, code)`. Devuelve `null` si el usuario
/// cancela o no concede el permiso de cámara.
class BarcodeScannerPage extends ConsumerStatefulWidget {
  const BarcodeScannerPage({super.key});

  @override
  ConsumerState<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends ConsumerState<BarcodeScannerPage> {
  MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _handled = false;
  bool _checkingPermission = true;
  bool _permissionDenied = false;

  /// Destello verde de confirmación (US-057): se prende al detectar y
  /// se alcanza a ver antes de cerrar la pantalla.
  bool _detected = false;

  @override
  void initState() {
    super.initState();
    _requestPermission();
  }

  Future<void> _requestPermission() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    setState(() {
      _checkingPermission = false;
      _permissionDenied = !status.isGranted;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Recrea el controlador: reintentar sobre el mismo que ya falló no
  /// siempre lo recupera (ej. la cámara la tenía tomada otra app).
  void _retryCamera() {
    final old = _controller;
    setState(() {
      _controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
      );
    });
    old.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled || capture.barcodes.isEmpty) return;
    final code = capture.barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;
    _handled = true;

    setState(() => _detected = true);
    await ref.read(scanFeedbackProvider).success();

    // El AC pide retroalimentación en < 200 ms; 150 ms alcanza para
    // que el destello se vea sin que se sienta lento.
    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;
    Navigator.pop(context, code);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceCard,
        title: const Text('Escanear código de barras'),
        actions: [
          if (!_checkingPermission && !_permissionDenied)
            ValueListenableBuilder(
              valueListenable: _controller,
              builder: (context, value, child) {
                final torchOn = value.torchState == TorchState.on;
                return IconButton(
                  tooltip: torchOn ? 'Apagar linterna' : 'Encender linterna',
                  icon: Icon(
                    torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                  ),
                  onPressed: _controller.toggleTorch,
                );
              },
            ),
          if (!_checkingPermission && !_permissionDenied)
            IconButton(
              tooltip: 'Cambiar cámara',
              icon: const Icon(Icons.cameraswitch_rounded),
              onPressed: _controller.switchCamera,
            ),
        ],
      ),
      body: _checkingPermission
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _permissionDenied
              ? _PermissionDeniedView(onRetry: _requestPermission)
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    MobileScanner(
                      controller: _controller,
                      onDetect: _onDetect,
                      errorBuilder: (context, error, child) => _CameraErrorView(
                        error: error,
                        onRetry: _retryCamera,
                        onManualEntry: () => Navigator.pop(context),
                      ),
                    ),
                    IgnorePointer(
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          width: 260,
                          height: 160,
                          decoration: BoxDecoration(
                            color: _detected
                                ? AppColors.success.withValues(alpha: 0.35)
                                : Colors.transparent,
                            border: Border.all(
                              color: _detected ? AppColors.success : AppColors.primary,
                              width: _detected ? 4 : 2,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: _detected
                              ? const Icon(Icons.check_rounded, color: Colors.white, size: 56)
                              : null,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 32,
                      left: 24,
                      right: 24,
                      child: Text(
                        'Apunta la cámara al código de barras del producto',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 14,
                          shadows: const [Shadow(blurRadius: 4, color: Colors.black)],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

/// US-058 (adaptada): la cámara puede fallar por estar en uso por otra
/// app, no existir en el dispositivo, o un error de plataforma. Sin
/// este widget, mobile_scanner solo pinta una caja negra con un ícono.
class _CameraErrorView extends StatelessWidget {
  final MobileScannerException error;
  final VoidCallback onRetry;
  final VoidCallback onManualEntry;

  const _CameraErrorView({
    required this.error,
    required this.onRetry,
    required this.onManualEntry,
  });

  String get _message => switch (error.errorCode) {
        MobileScannerErrorCode.permissionDenied =>
          'No hay permiso de cámara para escanear.',
        MobileScannerErrorCode.unsupported =>
          'Este dispositivo no puede escanear con la cámara.',
        _ => error.errorDetails?.message?.isNotEmpty == true
            ? 'No se pudo abrir la cámara: ${error.errorDetails!.message}'
            : 'No se pudo abrir la cámara. Puede estar en uso por otra app.',
      };

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off_rounded, size: 56, color: AppColors.textDisabled),
              const SizedBox(height: 16),
              Text(
                _message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
              ),
              const SizedBox(height: 8),
              // La venta no se detiene porque la cámara falle: se vuelve
              // a la pantalla anterior para digitar el código a mano.
              TextButton(
                onPressed: onManualEntry,
                child: const Text('Escribir el código a mano'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionDeniedView extends StatelessWidget {
  final VoidCallback onRetry;
  const _PermissionDeniedView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography_rounded, size: 56, color: AppColors.textDisabled),
            const SizedBox(height: 16),
            const Text(
              'Se necesita permiso de cámara para escanear códigos de barras.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: openAppSettings,
              child: const Text('Abrir ajustes de la app'),
            ),
          ],
        ),
      ),
    );
  }
}
