// ============================================================
// lib/core/services/local_prefs.dart
// Preferencias guardadas en el dispositivo (no en Supabase).
//
// A diferencia de `store_settings`, que es configuración de toda la
// tienda, esto es por celular: lo que un cajero ajusta aquí no afecta
// a los demás. Primer uso: sonido/vibración del escáner (EP-10).
// ============================================================

import 'package:shared_preferences/shared_preferences.dart';

abstract class LocalPrefsKeys {
  static const String scanSoundEnabled = 'scan_sound_enabled';
  static const String scanVibrationEnabled = 'scan_vibration_enabled';
}

class LocalPrefs {
  const LocalPrefs();

  Future<bool> getBool(String key, {required bool defaultValue}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? defaultValue;
  }

  Future<void> setBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }
}
