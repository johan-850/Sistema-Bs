// ============================================================
// lib/core/utils/scan_feedback.dart
// US-057: retroalimentación sonora y háptica al escanear.
//
// Se usa `SystemSound` (parte de flutter/services) en vez de un
// archivo de audio propio: no necesita assets ni permisos y suena de
// inmediato. Si algún día se quiere un beep personalizado, se cambia
// solo aquí adentro usando `audioplayers` (ya está en pubspec) —
// ningún llamador se entera.
//
// La parte visual (destello verde del escáner, snackbars) vive en
// cada pantalla; esto es solo lo no visual.
// ============================================================

import 'package:flutter/services.dart';

class ScanFeedback {
  final bool soundEnabled;
  final bool vibrationEnabled;

  const ScanFeedback({
    required this.soundEnabled,
    required this.vibrationEnabled,
  });

  /// Código leído y reconocido.
  Future<void> success() async {
    if (soundEnabled) await SystemSound.play(SystemSoundType.click);
    if (vibrationEnabled) await HapticFeedback.mediumImpact();
  }

  /// Código ilegible, no registrado, o error al buscarlo.
  Future<void> failure() async {
    if (soundEnabled) await SystemSound.play(SystemSoundType.alert);
    if (vibrationEnabled) await HapticFeedback.heavyImpact();
  }
}
