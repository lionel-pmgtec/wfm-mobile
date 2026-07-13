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
                    onTap: () => context.push(AppRoutes.syncQueue)),
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

  Widget _statsGrid(Map<WorkOrderStatus, int> m) {
    final items = [
      (WorkOrderStatus.ricevuto, Icons.inbox_outlined),
      (WorkOrderStatus.inEsecuzione, Icons.play_circle_outline),
      (WorkOrderStatus.inPausa, Icons.pause_circle_outline),
      (WorkOrderStatus.sospeso, Icons.stop_circle_outlined),
      (WorkOrderStatus.completato, Icons.check_circle_outline),
      (WorkOrderStatus.inviatoSAP, Icons.send_outlined),
    ];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: kSpacingMd,
      crossAxisSpacing: kSpacingMd,
      childAspectRatio: 1.6,
      children: items.map((e) {
        final style = getStatusStyle(e.$1.label);
        return WfmCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration:
                    BoxDecoration(color: style.background, shape: BoxShape.circle),
                child: Icon(e.$2, size: 30, color: style.color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('${m[e.$1] ?? 0}',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800)),
                    Text(e.$1.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
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
          Icon(icon, color: AppColors.primary, size: 26),
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
