import '../constants/app_constants.dart';

/// Validadores reutilizables para formularios Flutter
abstract class Validators {
  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'El correo es requerido';
    final regex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (!regex.hasMatch(value.trim())) return 'Ingresa un correo válido';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'La contraseña es requerida';
    if (value.length < AppConstants.minPasswordLength) {
      return 'Mínimo ${AppConstants.minPasswordLength} caracteres';
    }
    return null;
  }

  static String? requiredText(String? value, {String fieldName = 'Este campo'}) {
    if (value == null || value.trim().isEmpty) return '$fieldName es requerido';
    return null;
  }

  static String? name(String? value) {
    if (value == null || value.trim().isEmpty) return 'El nombre es requerido';
    if (value.trim().length > AppConstants.maxNameLength) {
      return 'Máximo ${AppConstants.maxNameLength} caracteres';
    }
    return null;
  }
}
