// Guscio di navigazione persistente dell'app.
//
// Su tablet (larghezza >= kTabletBreakpoint) mostra una sidebar laterale il cui
// header blu è allineato in altezza alla AppBar dei contenuti (status bar +
// toolbar), così la barra superiore forma un'unica fascia blu e la sidebar non
// "supera" la navbar. Su smartphone una NavigationBar inferiore.
// Le quattro destinazioni primarie V1 (Home, Ordini, Avvisi, Mappa) mantengono
// lo stato di ciascun ramo grazie a StatefulShellRoute.indexedStack.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/realtime_provider.dart';
import '../../providers/settings_provider.dart';

/// Altezza della toolbar (cfr. appBarTheme.toolbarHeight in app_theme.dart).
const double _kToolbarHeight = 60;

/// Larghezza della sidebar tablet.
const double _kSidebarWidth = 98;

/// Descrittore di una destinazione di navigazione primaria.
class _Destination {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  const _Destination(this.icon, this.selectedIcon, this.label);
}

const List<_Destination> _destinations = [
  _Destination(Icons.dashboard_outlined, Icons.dashboard_rounded, 'Home'),
  _Destination(Icons.assignment_outlined, Icons.assignment_rounded, 'Ordini'),
  _Destination(
      Icons.notifications_none_rounded, Icons.notifications_rounded, 'Avvisi'),
  _Destination(Icons.map_outlined, Icons.map_rounded, 'Mappa'),
];

class AppShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;
  const AppShell({super.key, required this.navigationShell});

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Tiene vivo l'SSE del backend collega per tutta la sessione: quando SAP
    // spinge nuovi ordini/avvisi, le liste si ricaricano da sole.
    ref.watch(realtimeProvider);
    final isTablet = MediaQuery.sizeOf(context).width >= kTabletBreakpoint;

    if (isTablet) {
      return Scaffold(
        // Fondo blu come le due fasce superiori: l'antialiasing dei bordi di
        // sidebar e AppBar alla frontiera si fonde col blu (non col chiaro), così
        // non resta alcuna riga chiara nella navbar (anche con DPR frazionari).
        backgroundColor: AppColors.primary,
        // Nessun Row a filo: il contenuto parte 1px sotto la sidebar opaca, così
        // non può mai comparire un giunto chiaro alla frontiera.
        body: Stack(
          children: [
            Positioned.fill(
              left: _kSidebarWidth - 1,
              child: navigationShell,
            ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: _kSidebarWidth,
              child: _WfmSidebar(
                selectedIndex: navigationShell.currentIndex,
                onSelected: _goBranch,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _goBranch,
        destinations: [
          for (final d in _destinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon),
              label: d.label,
            ),
        ],
      ),
    );
  }
}

/// Sidebar tablet: header blu (allineato alla navbar) + destinazioni + stato sync.
class _WfmSidebar extends ConsumerWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  const _WfmSidebar({required this.selectedIndex, required this.onSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(connectivityStatusProvider);
    final pending = ref.watch(pendingSyncCountProvider).valueOrNull ?? 0;
    final topInset = MediaQuery.of(context).padding.top;
    final iconScale = ref.watch(settingsProvider).iconScale;

    return Container(
      width: _kSidebarWidth,
      // Nessun bordo destro: eviterebbe di attraversare le AppBar più alte
      // (es. con TabBar), dove la fascia blu supera l'altezza dell'header.
      color: AppColors.surface,
      child: Column(
        children: [
          // Header blu della stessa altezza della AppBar (status bar + toolbar),
          // col logo Viva Servizi (bianco/arancio, pensato per sfondo blu).
          Container(
            height: topInset + _kToolbarHeight,
            width: double.infinity,
            color: AppColors.primary,
            padding: EdgeInsets.only(top: topInset + 6, bottom: 6, left: 8, right: 8),
            alignment: Alignment.center,
            child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < _destinations.length; i++)
            _SidebarItem(
              dest: _destinations[i],
              selected: i == selectedIndex,
              iconScale: iconScale,
              onTap: () => onSelected(i),
            ),
          const Spacer(),
          // Azioni di utilità (route full-screen, non rami dello shell).
          _SidebarItem(
            dest: const _Destination(
                Icons.sync_rounded, Icons.sync_rounded, 'Sincronizza'),
            selected: false,
            iconScale: iconScale,
            onTap: () => context.push(AppRoutes.syncQueue),
          ),
          _SidebarItem(
            dest: const _Destination(Icons.settings_outlined,
                Icons.settings_rounded, 'Impostazioni'),
            selected: false,
            iconScale: iconScale,
            onTap: () => context.push(AppRoutes.settings),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(bottom: kSpacingLg),
            child: Tooltip(
              message: online
                  ? (pending > 0
                      ? '$pending operazioni in coda'
                      : 'Sincronizzato')
                  : 'Offline',
              child: Icon(
                online
                    ? (pending > 0
                        ? Icons.sync_problem_rounded
                        : Icons.cloud_done_rounded)
                    : Icons.cloud_off_rounded,
                color: online
                    ? (pending > 0
                        ? AppColors.accentOrange
                        : AppColors.accentGreen)
                    : AppColors.textHint,
                size: 22 * iconScale,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final _Destination dest;
  final bool selected;
  final double iconScale;
  final VoidCallback onTap;
  const _SidebarItem({
    required this.dest,
    required this.selected,
    required this.onTap,
    this.iconScale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textSecondary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        child: Column(
          children: [
            // Voce attiva: pill blu piena con icona bianca (evidente); le altre
            // trasparenti con icona grigia.
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 40,
              width: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Icon(selected ? dest.selectedIcon : dest.icon,
                  color: selected ? Colors.white : AppColors.textSecondary,
                  size: 24 * iconScale),
            ),
            const SizedBox(height: 4),
            Text(dest.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 10.5,
                    color: color,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400)),
          ],
        ),
      ),
    );
  }
}
