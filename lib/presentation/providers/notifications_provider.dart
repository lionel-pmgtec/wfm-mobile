// Stato in-app delle notifiche push ricevute.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/push_notification_service.dart';
import '../../domain/entities/app_notification.dart';

// ─── State notifier ────────────────────────────────────────────────────────

class NotificationsNotifier extends StateNotifier<List<AppNotification>> {
  NotificationsNotifier() : super([]) {
    // Collega il servizio push allo store in-app.
    PushNotificationService.instance.onReceived = _onReceived;
  }

  void _onReceived(AppNotification n) {
    // Evita duplicati (stesso id).
    if (state.any((e) => e.id == n.id)) return;
    state = [n, ...state];
  }

  void add(AppNotification n) => _onReceived(n);

  void markRead(String id) {
    state = [
      for (final n in state)
        if (n.id == id) n.copyWith(isRead: true) else n,
    ];
  }

  void markAllRead() {
    state = [for (final n in state) n.copyWith(isRead: true)];
  }

  void remove(String id) {
    state = state.where((n) => n.id != id).toList();
  }

  void clearAll() => state = [];

  int get unreadCount => state.where((n) => !n.isRead).length;
}

// ─── Provider ─────────────────────────────────────────────────────────────

final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, List<AppNotification>>(
        (ref) => NotificationsNotifier());

final unreadNotificationsCountProvider = Provider<int>((ref) {
  final list = ref.watch(notificationsProvider);
  return list.where((n) => !n.isRead).length;
});

// ─── Helper: manda notifica OS + aggiunge allo store ───────────────────────

/// Il servizio chiama internamente `onReceived` che aggiorna lo store.
Future<void> sendNotification(AppNotification notification) async {
  await PushNotificationService.instance.show(notification);
}

// ─── Factory helpers ───────────────────────────────────────────────────────

AppNotification notifNuovoOdl({
  required String workOrderCode,
  required String descrizione,
  String? luogo,
}) =>
    AppNotification(
      id: 'odl_$workOrderCode',
      type: AppNotificationType.nuovoOdl,
      title: 'Nuovo OdL assegnato',
      body: '$workOrderCode — $descrizione${luogo != null ? '\n$luogo' : ''}',
      relatedId: workOrderCode,
      routePath: '/work-orders/$workOrderCode',
      receivedAt: DateTime.now(),
    );

AppNotification notifOdlRevocato(String workOrderCode) => AppNotification(
      id: 'revoca_$workOrderCode',
      type: AppNotificationType.odlRevocato,
      title: 'OdL revocato',
      body: 'L\'OdL $workOrderCode è stato revocato o riassegnato.',
      relatedId: workOrderCode,
      routePath: null,
      receivedAt: DateTime.now(),
    );

AppNotification notifNuovoAvviso({
  required String numeroAvviso,
  required String descrizione,
}) =>
    AppNotification(
      id: 'avviso_$numeroAvviso',
      type: AppNotificationType.nuovoAvviso,
      title: 'Nuovo avviso di servizio',
      body: '$numeroAvviso — $descrizione',
      relatedId: numeroAvviso,
      routePath: '/avvisi/$numeroAvviso',
      receivedAt: DateTime.now(),
    );

AppNotification notifPromemoria({
  required String workOrderCode,
  required String minutiMancanti,
}) =>
    AppNotification(
      id: 'reminder_${workOrderCode}_${DateTime.now().millisecondsSinceEpoch}',
      type: AppNotificationType.promemoria,
      title: 'Promemoria appuntamento',
      body: 'OdL $workOrderCode tra $minutiMancanti minuti.',
      relatedId: workOrderCode,
      routePath: '/work-orders/$workOrderCode',
      receivedAt: DateTime.now(),
    );

AppNotification notifSincronizzazione(String messaggio) => AppNotification(
      id: 'sync_${DateTime.now().millisecondsSinceEpoch}',
      type: AppNotificationType.sincronizzazione,
      title: 'Sincronizzazione',
      body: messaggio,
      receivedAt: DateTime.now(),
    );
