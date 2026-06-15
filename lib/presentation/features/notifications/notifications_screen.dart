// Centro notifiche (M13): lista dinamica con stato letto/non letto.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/app_notification.dart';
import '../../providers/notifications_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifs = ref.watch(notificationsProvider);
    final unread = ref.watch(unreadNotificationsCountProvider);
    final notifier = ref.read(notificationsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(unread > 0
            ? 'Notifiche ($unread non lette)'
            : 'Notifiche'),
        actions: [
          if (notifs.isNotEmpty) ...[
            if (unread > 0)
              TextButton(
                onPressed: notifier.markAllRead,
                child: const Text('Lette tutte',
                    style: TextStyle(color: Colors.white)),
              ),
            IconButton(
              tooltip: 'Cancella tutte',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () => _confirmClearAll(context, notifier),
            ),
          ],
        ],
      ),
      body: notifs.isEmpty
          ? const EmptyState(
              title: 'Nessuna notifica',
              subtitle: 'Le notifiche di nuovi OdL e avvisi appariranno qui.',
              icon: Icons.notifications_none_rounded,
            )
          : ListView.separated(
              padding: kPagePadding,
              itemCount: notifs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _NotifTile(
                notif: notifs[i],
                onTap: () => _onTap(context, ref, notifs[i]),
                onDismiss: () => notifier.remove(notifs[i].id),
              ),
            ),
    );
  }

  void _onTap(BuildContext context, WidgetRef ref, AppNotification n) {
    ref.read(notificationsProvider.notifier).markRead(n.id);
    if (n.routePath != null && n.routePath!.isNotEmpty) {
      context.push(n.routePath!);
    }
  }

  Future<void> _confirmClearAll(
      BuildContext context, NotificationsNotifier notifier) async {
    final ok = await showWfmConfirmDialog(
      context: context,
      title: 'Cancella notifiche',
      message: 'Eliminare tutte le notifiche? L\'operazione è irreversibile.',
      confirmLabel: 'Cancella tutto',
      cancelLabel: 'Annulla',
      tone: WfmDialogTone.danger,
      icon: Icons.delete_sweep_outlined,
    );
    if (ok == true) notifier.clearAll();
  }
}

// ─── TILE SINGOLA NOTIFICA ────────────────────────────────────────────────

class _NotifTile extends StatelessWidget {
  final AppNotification notif;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _NotifTile({
    required this.notif,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final style = _typeStyle(notif.type);

    return Dismissible(
      key: ValueKey(notif.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.accentRed.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(kRadiusMd),
        ),
        child: const Icon(Icons.delete_outline, color: AppColors.accentRed),
      ),
      onDismissed: (_) => onDismiss(),
      child: WfmCard(
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icona tipo
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: style.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(style.icon, color: style.color, size: 22),
            ),
            const SizedBox(width: 12),
            // Testo
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notif.title,
                          style: AppTextStyles.headingSmall.copyWith(
                            fontWeight: notif.isRead
                                ? FontWeight.w500
                                : FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTime(notif.receivedAt),
                        style: AppTextStyles.labelSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    notif.body,
                    style: AppTextStyles.bodyMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: style.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          notif.type.label,
                          style: TextStyle(
                              fontSize: 10,
                              color: style.color,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      const Spacer(),
                      // Pallino "non letto"
                      if (!notif.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: style.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'ora';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min fa';
    if (diff.inHours < 24) return DateFormat('HH:mm').format(dt);
    if (diff.inDays == 1) return 'ieri ${DateFormat('HH:mm').format(dt)}';
    return DateFormat('dd/MM HH:mm').format(dt);
  }

  ({Color color, IconData icon}) _typeStyle(AppNotificationType type) =>
      switch (type) {
        AppNotificationType.nuovoOdl => (
            color: AppColors.primary,
            icon: Icons.add_task_outlined
          ),
        AppNotificationType.odlModificato => (
            color: AppColors.accentOrange,
            icon: Icons.edit_calendar_outlined
          ),
        AppNotificationType.odlRevocato => (
            color: AppColors.accentRed,
            icon: Icons.assignment_return_outlined
          ),
        AppNotificationType.nuovoAvviso => (
            color: AppColors.statusNew,
            icon: Icons.warning_amber_rounded
          ),
        AppNotificationType.sincronizzazione => (
            color: AppColors.textSecondary,
            icon: Icons.sync_rounded
          ),
        AppNotificationType.promemoria => (
            color: AppColors.accentGreen,
            icon: Icons.alarm_rounded
          ),
      };
}
