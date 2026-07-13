// Polling dei nuovi OdL/Avvisi dal middleware (Cruscotto).
//
// Il middleware NON invia push: questo servizio interroga periodicamente le
// liste, rileva gli elementi NUOVI rispetto all'ultimo controllo e mostra una
// notifica locale (via PushNotificationService) aggiornando anche le liste.
// È l'alternativa "senza Firebase" al push FCM: funziona subito col backend
// Excel. In produzione può essere sostituito dal push FCM reale.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../presentation/providers/core_providers.dart';
import '../../presentation/providers/work_orders_provider.dart';
import '../../presentation/providers/avvisi_provider.dart';
import '../../presentation/providers/notifications_provider.dart';

/// Intervallo di default tra due controlli.
const _kPollInterval = Duration(seconds: 20);

class NewItemsPollService {
  final Ref ref;
  Timer? _timer;

  final Set<String> _knownOrders = {};
  final Set<String> _knownAvvisi = {};

  /// Al primo giro registriamo lo stato corrente SENZA notificare, così non si
  /// generano notifiche per gli elementi già presenti all'avvio.
  bool _baselineDone = false;

  NewItemsPollService(this.ref);

  bool get isRunning => _timer != null;

  void start({Duration interval = _kPollInterval}) {
    if (_timer != null) return;
    _poll(); // baseline immediata
    _timer = Timer.periodic(interval, (_) => _poll());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _knownOrders.clear();
    _knownAvvisi.clear();
    _baselineDone = false;
  }

  Future<void> _poll() async {
    final token = ref.read(authTokenProvider);
    if (token == null || token.isEmpty) {
      debugPrint('[poll] skip: non autenticato');
      return;
    }
    try {
      final orderRes = await ref.read(workOrderRepositoryProvider).getWorkOrders();
      final avvisoRes = await ref.read(notificationRepositoryProvider).getAvvisi();
      final orders = orderRes.valueOrNull ?? const [];
      final avvisi = avvisoRes.valueOrNull ?? const [];

      if (!_baselineDone) {
        _knownOrders.addAll(orders.map((o) => o.externalCode));
        _knownAvvisi.addAll(avvisi.map((a) => a.numeroAvviso));
        _baselineDone = true;
        debugPrint('[poll] baseline: ${orders.length} OdL, ${avvisi.length} avvisi '
            '(gli elementi già presenti NON generano notifiche)');
        return;
      }

      var newCount = 0;
      for (final o in orders) {
        if (_knownOrders.add(o.externalCode)) {
          newCount++;
          debugPrint('[poll] NUOVO OdL ${o.externalCode} → notifica');
          await sendNotification(notifNuovoOdl(
            workOrderCode: o.externalCode,
            descrizione: o.woTypeDescription,
            luogo: o.address.city.isEmpty ? null : o.address.city,
          ));
        }
      }
      for (final a in avvisi) {
        if (_knownAvvisi.add(a.numeroAvviso)) {
          newCount++;
          debugPrint('[poll] NUOVO Avviso ${a.numeroAvviso} → notifica');
          await sendNotification(notifNuovoAvviso(
            numeroAvviso: a.numeroAvviso,
            descrizione: a.descrizione,
          ));
        }
      }
      if (newCount > 0) {
        ref.invalidate(workOrdersProvider);
        ref.invalidate(dashboardStatsProvider);
        ref.invalidate(avvisiProvider);
      } else {
        debugPrint('[poll] nessuna novità (${orders.length} OdL, ${avvisi.length} avvisi)');
      }
    } catch (e) {
      debugPrint('[poll] errore: $e');
    }
  }
}

/// Servizio attivo per tutta la vita dell'app: parte al login (token presente),
/// si ferma al logout. Va "toccato" una volta (ref.read) perché il listener sia
/// attivo — fatto in app.dart.
final newItemsPollServiceProvider = Provider<NewItemsPollService>((ref) {
  final service = NewItemsPollService(ref);
  ref.onDispose(service.stop);
  ref.listen<String?>(authTokenProvider, (previous, next) {
    if (next != null && next.isNotEmpty) {
      service.start();
    } else {
      service.stop();
    }
  }, fireImmediately: true);
  return service;
});
