import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/enums.dart';
import '../../providers/auth_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/notifications_provider.dart';
import '../../providers/work_orders_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider.notifier).user;
    final stats = ref.watch(dashboardStatsProvider);
    final online = ref.watch(connectivityStatusProvider);
    final pending = ref.watch(pendingSyncCountProvider).valueOrNull ?? 0;
    final unreadNotifs = ref.watch(unreadNotificationsCountProvider);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: kSpacingLg,
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white24,
              child: Text(user?.initials ?? 'WF',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(user?.fullName ?? 'Tecnico',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                  Text(user?.workCenter ?? 'WFM Mobile',
                      style: const TextStyle(fontSize: 11, color: Colors.white70)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Notifiche',
            icon: Badge(
              isLabelVisible: unreadNotifs > 0,
              label: Text('$unreadNotifs'),
              child: const Icon(Icons.notifications_none_rounded),
            ),
            onPressed: () => context.push(AppRoutes.notifications),
          ),
          IconButton(
            tooltip: 'Esci',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => _confirmLogout(context, ref),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(dashboardStatsProvider),
        child: ListView(
          padding: kPagePadding,
          children: [
            if (!online || pending > 0) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: WfmOfflineBadge(offline: !online, pendingCount: pending),
              ),
              const SizedBox(height: kSpacingMd),
            ],
            _WelcomeHeader(
              greeting: _greeting(),
              name: (user?.nome ?? '').trim().isEmpty
                  ? 'Tecnico'
                  : (user?.nome ?? '').trim(),
              subtitle: _headerSubtitle(stats.valueOrNull),
            ),
            const SizedBox(height: kSpacingLg),
            const Text('Riepilogo di oggi', style: AppTextStyles.headingMedium),
            const SizedBox(height: kSpacingMd),
            stats.when(
              loading: () => const SizedBox(
                  height: 88, child: Center(child: CircularProgressIndicator())),
              error: (e, _) => WfmErrorState(
                  message: e.toString(),
                  onRetry: () => ref.invalidate(dashboardStatsProvider)),
              data: (m) => _statsGrid(m),
            ),
            const SizedBox(height: kSpacingXl),
            const Text('Accessi rapidi', style: AppTextStyles.headingMedium),
            const SizedBox(height: kSpacingMd),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: kSpacingMd,
              crossAxisSpacing: kSpacingMd,
              childAspectRatio: 1.05,
              children: [
                _quickAction(context,
                    icon: Icons.add_task_rounded,
                    label: 'Crea OdL',
                    onTap: () => context.push(AppRoutes.createOrder)),
                _quickAction(context,
                    icon: Icons.qr_code_scanner_rounded,
                    label: 'Scanner',
                    onTap: () => context.push(AppRoutes.scanner)),
                _quickAction(context,
                    icon: Icons.widgets_outlined,
                    label: 'Standalone',
                    onTap: () => context.push(AppRoutes.standalone)),
                _quickAction(context,
                    icon: Icons.sync_rounded,
                    label: 'Sincronizza',
                    onTap: () => context.push(AppRoutes.syncCenter)),
                _quickAction(context,
                    icon: Icons.settings_outlined,
                    label: 'Impostazioni',
                    onTap: () => context.push(AppRoutes.settings)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Saluto in base all'ora del dispositivo.
  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Buongiorno';
    if (h < 18) return 'Buon pomeriggio';
    return 'Buonasera';
  }

  /// Riga di sintesi sotto il saluto, ricavata dai contatori.
  String _headerSubtitle(Map<WorkOrderStatus, int>? m) {
    if (m == null) return 'Ecco la tua giornata';
    final inEsec = m[WorkOrderStatus.inEsecuzione] ?? 0;
    final assegnati = m[WorkOrderStatus.ricevuto] ?? 0;
    final daFare = inEsec + assegnati;
    if (inEsec > 0) {
      return '$inEsec ${inEsec == 1 ? 'ordine' : 'ordini'} in esecuzione';
    }
    if (daFare > 0) {
      return '$daFare ${daFare == 1 ? 'ordine' : 'ordini'} da fare oggi';
    }
    return 'Nessun ordine assegnato';
  }

  Widget _statsGrid(Map<WorkOrderStatus, int> m) {
    final items = [
      (WorkOrderStatus.ricevuto, Icons.inbox_rounded),
      (WorkOrderStatus.inEsecuzione, Icons.play_arrow_rounded),
      (WorkOrderStatus.inPausa, Icons.pause_rounded),
      (WorkOrderStatus.sospeso, Icons.stop_rounded),
      (WorkOrderStatus.completato, Icons.check_rounded),
      (WorkOrderStatus.inviatoSAP, Icons.send_rounded),
    ];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: kSpacingMd,
      crossAxisSpacing: kSpacingMd,
      childAspectRatio: 1.15,
      children: items.map((e) {
        final style = getStatusStyle(e.$1.label);
        final count = m[e.$1] ?? 0;
        final active = count > 0;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: active ? style.background : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active
                  ? style.color.withValues(alpha: 0.35)
                  : AppColors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: active ? style.color : style.background,
                  shape: BoxShape.circle,
                ),
                child: Icon(e.$2,
                    size: 20, color: active ? Colors.white : style.color),
              ),
              const Spacer(),
              Text('$count',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      height: 1,
                      color: active ? style.color : AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text(e.$1.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _quickAction(BuildContext context,
      {required IconData icon, required String label, required VoidCallback onTap}) {
    return WfmCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: kSpacingMd, horizontal: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: AppColors.primarySurface,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 24),
          ),
          const SizedBox(height: 8),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelLarge,
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final ok = await showWfmConfirmDialog(
      context: context,
      title: 'Disconnessione',
      message:
          'Vuoi uscire dall\'applicazione? Le modifiche non sincronizzate resteranno in coda.',
      confirmLabel: 'Esci',
      cancelLabel: 'Annulla',
      tone: WfmDialogTone.danger,
      icon: Icons.logout_rounded,
    );
    if (ok == true && context.mounted) {
      await ref.read(authControllerProvider.notifier).logout();
      if (context.mounted) context.go(AppRoutes.login);
    }
  }
}

/// Intestazione di benvenuto con gradiente: saluto + nome + sintesi giornata.
class _WelcomeHeader extends StatelessWidget {
  final String greeting;
  final String name;
  final String subtitle;
  const _WelcomeHeader({
    required this.greeting,
    required this.name,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            Color.lerp(AppColors.primary, Colors.black, 0.28)!,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$greeting, $name',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
                const SizedBox(height: 4),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, color: Colors.white70)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.waving_hand_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }
}
