import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/entities/app_user.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../router/nav_destinations.dart';
import '../theme/app_theme.dart';
import '../theme/breakpoints.dart';
import 'app_page_bar.dart';

/// Barra lateral persistente. Por debajo de `expanded` se colapsa a íconos
/// y no a un Drawer: el AppBar de cada página no alcanza un Drawer exterior.
class AppShell extends ConsumerWidget {
  final String location;
  final Widget child;

  const AppShell({super.key, required this.location, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateStreamProvider).valueOrNull;
    if (user == null) return child;

    final sections = navSectionsFor(user);
    final selected = selectedRoute(location, [
      for (final s in sections) ...s.destinations,
      navSettings,
    ]);

    // Material y no Scaffold, para que los SnackBar salgan sobre el contenido.
    return Material(
      color: AppColors.surface,
      child: Row(
        children: [
          _SideNav(
            user: user,
            sections: sections,
            selected: selected,
            extended: context.isExpanded,
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _SideNav extends StatelessWidget {
  final AppUser user;
  final List<NavSection> sections;
  final String? selected;
  final bool extended;

  const _SideNav({
    required this.user,
    required this.sections,
    required this.selected,
    required this.extended,
  });

  Widget _item(NavDestination d) =>
      _NavItem(destination: d, selected: d.route == selected, extended: extended);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: extended ? 248 : 72,
      color: AppColors.surfaceCard,
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            _Header(user: user, extended: extended),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: [
                  for (final s in sections) ...[
                    if (s.title != null)
                      extended
                          ? _SectionLabel(s.title!)
                          : const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Divider(height: 1),
                            ),
                    for (final d in s.destinations) _item(d),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: _item(navSettings),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final AppUser user;
  final bool extended;
  const _Header({required this.user, required this.extended});

  @override
  Widget build(BuildContext context) {
    const logo = Icon(Icons.storefront_rounded, color: AppColors.primary, size: 28);
    // Misma altura que el encabezado de las páginas: las dos líneas
    // divisorias quedan a la misma altura de lado a lado.
    if (!extended) {
      return const SizedBox(height: AppPageBar.height, child: Center(child: logo));
    }
    return Container(
      height: AppPageBar.height,
      padding: const EdgeInsets.fromLTRB(20, 0, 16, 0),
      child: Row(
        children: [
          logo,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Sistema Bs',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(
                  '${user.name} · ${user.isAdmin ? 'AdminMaster' : 'Cajero'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 6),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: AppColors.textDisabled,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final NavDestination destination;
  final bool selected;
  final bool extended;

  const _NavItem({
    required this.destination,
    required this.selected,
    required this.extended,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textSecondary;
    final icon = Icon(destination.icon, color: color, size: 22);

    Widget tile = Material(
      color: selected ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        // También si ya está marcado: desde una subpantalla vuelve a la raíz.
        onTap: () => context.go(destination.route),
        child: SizedBox(
          height: 44,
          child: extended
              ? Row(
                  children: [
                    const SizedBox(width: 12),
                    icon,
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        destination.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected ? AppColors.primary : AppColors.textPrimary,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                )
              : Center(child: icon),
        ),
      ),
    );

    if (!extended) {
      tile = Tooltip(
        message: destination.label,
        preferBelow: false,
        child: tile,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Semantics(selected: selected, child: tile),
    );
  }
}
