// ============================================================
// lib/core/providers/scan_feedback_providers.dart
// US-057: preferencias de retroalimentación del escáner.
//
// Viven en el dispositivo (LocalPrefs), no en `store_settings`:
// silenciar el escáner es una decisión de cada celular, no de la
// tienda entera.
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/local_prefs.dart';
import '../utils/scan_feedback.dart';

final localPrefsProvider = Provider((ref) => const LocalPrefs());

class ScanFeedbackPrefs {
  final bool soundEnabled;
  final bool vibrationEnabled;

  const ScanFeedbackPrefs({
    this.soundEnabled = true,
    this.vibrationEnabled = true,
  });

  ScanFeedbackPrefs copyWith({bool? soundEnabled, bool? vibrationEnabled}) =>
      ScanFeedbackPrefs(
        soundEnabled: soundEnabled ?? this.soundEnabled,
        vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      );
}

class ScanFeedbackPrefsNotifier extends StateNotifier<ScanFeedbackPrefs> {
  final LocalPrefs _prefs;

  ScanFeedbackPrefsNotifier(this._prefs) : super(const ScanFeedbackPrefs()) {
    _load();
  }

  Future<void> _load() async {
    final sound = await _prefs.getBool(LocalPrefsKeys.scanSoundEnabled, defaultValue: true);
    final vibration =
        await _prefs.getBool(LocalPrefsKeys.scanVibrationEnabled, defaultValue: true);
    if (!mounted) return;
    state = ScanFeedbackPrefs(soundEnabled: sound, vibrationEnabled: vibration);
  }

  Future<void> setSoundEnabled(bool value) async {
    state = state.copyWith(soundEnabled: value);
    await _prefs.setBool(LocalPrefsKeys.scanSoundEnabled, value);
  }

  Future<void> setVibrationEnabled(bool value) async {
    state = state.copyWith(vibrationEnabled: value);
    await _prefs.setBool(LocalPrefsKeys.scanVibrationEnabled, value);
  }
}

final scanFeedbackPrefsProvider =
    StateNotifierProvider<ScanFeedbackPrefsNotifier, ScanFeedbackPrefs>(
  (ref) => ScanFeedbackPrefsNotifier(ref.read(localPrefsProvider)),
);

/// Lo que consumen las pantallas al escanear.
final scanFeedbackProvider = Provider<ScanFeedback>((ref) {
  final prefs = ref.watch(scanFeedbackPrefsProvider);
  return ScanFeedback(
    soundEnabled: prefs.soundEnabled,
    vibrationEnabled: prefs.vibrationEnabled,
  );
});
