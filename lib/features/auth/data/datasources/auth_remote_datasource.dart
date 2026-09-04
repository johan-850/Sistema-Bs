import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_user_model.dart';
import '../../../../core/constants/app_constants.dart';

/// Fuente de datos remota: comunica directamente con Supabase Auth + tabla profiles
class AuthRemoteDatasource {
  final SupabaseClient _client;
  const AuthRemoteDatasource(this._client);

  /// Inicia sesión y retorna el perfil del usuario desde la tabla profiles
  Future<AppUserModel> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    if (response.user == null) {
      throw const AuthException('Credenciales inválidas');
    }

    // Obtener perfil completo desde tabla profiles
    final profile = await _client
        .from(AppConstants.tableProfiles)
        .select()
        .eq('id', response.user!.id)
        .single();

    final user = AppUserModel.fromMap(profile);

    // Verificar cuenta activa (US-002 / US-004)
    if (!user.isActive) {
      await _client.auth.signOut();
      throw const AuthException('Cuenta desactivada. Contacta al administrador.');
    }

    // Actualizar last_login
    await _client
        .from(AppConstants.tableProfiles)
        .update({'last_login': DateTime.now().toUtc().toIso8601String()})
        .eq('id', response.user!.id);

    return user;
  }

  /// Cierra sesión eliminando el token local
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Obtiene el perfil del usuario actualmente autenticado
  Future<AppUserModel?> getCurrentUserProfile() async {
    final session = _client.auth.currentSession;
    if (session == null) return null;

    final profile = await _client
        .from(AppConstants.tableProfiles)
        .select()
        .eq('id', session.user.id)
        .maybeSingle();

    if (profile == null) return null;
    return AppUserModel.fromMap(profile);
  }

  /// Stream de cambios de sesión
  Stream<AppUserModel?> get authStateStream =>
      _client.auth.onAuthStateChange.asyncMap((event) async {
        if (event.session == null) return null;
        return getCurrentUserProfile();
      });
}
