import '../../features/auth/domain/entities/app_user.dart';
import 'app_routes.dart';

String homeFor(AppUser user) =>
    user.isAdmin ? AppRoutes.adminDashboard : AppRoutes.cashRegisterOpening;

bool isAdminPath(String path) =>
    path == AppRoutes.adminDashboard ||
    path.startsWith('${AppRoutes.adminDashboard}/');

/// Destino al que redirigir, o null para dejar pasar. Corre en cada
/// navegación, incluida una dirección escrita a mano en la barra del
/// navegador — por eso valida el rol por ruta y no solo al iniciar sesión.
/// RLS sigue siendo la defensa de fondo; esto evita mostrar la pantalla.
String? resolveRedirect({required AppUser? user, required String path}) {
  final isLogin = path == AppRoutes.login;
  if (user == null) return isLogin ? null : AppRoutes.login;
  if (isLogin) return homeFor(user);
  if (isAdminPath(path) && !user.isAdmin) return homeFor(user);
  return null;
}
