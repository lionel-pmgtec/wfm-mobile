// Realtime: aggancia l'SSE del backend del collega e aggiorna le liste in
// tempo reale. Quando SAP spinge nuovi ordini/avvisi, il backend emette un
// evento e qui invalidiamo i provider delle liste così la UI si ricarica sola.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/sse_service.dart';
import 'core_providers.dart';
import 'work_orders_provider.dart';
import 'avvisi_provider.dart';

/// Servizio SSE vivo per tutta la sessione. Va "osservato" (es. dallo shell)
/// perché parta; alla dismissione chiude lo stream.
final realtimeProvider = Provider<SseService>((ref) {
  final client = ref.watch(dioClientProvider);
  final sse = SseService(client.dioRead);

  final sub = sse.events.listen((e) {
    switch (e.event) {
      case 'ordini':
        ref.invalidate(workOrdersProvider);
        ref.invalidate(dashboardStatsProvider);
        break;
      case 'avvisi':
        ref.invalidate(avvisiProvider);
        break;
      case 'snapshot':
      case 'reset':
        // Snapshot iniziale o azzeramento: ricarica tutto.
        ref.invalidate(workOrdersProvider);
        ref.invalidate(dashboardStatsProvider);
        ref.invalidate(avvisiProvider);
        break;
    }
  });

  sse.start();

  // Caricamento iniziale automatico: il cruscotto parte vuoto finché SAP non
  // spinge i dati, quindi all'avvio della sessione chiediamo una volta il pull
  // da SAP, così le liste si popolano da sole senza premere "Aggiorna".
  // (Il pulsante resta per ricontrollare a mano quando serve.)
  Future.microtask(() async {
    try {
      await ref.read(remoteDataSourceProvider).refreshFromCruscotto();
      ref.invalidate(workOrdersProvider);
      ref.invalidate(dashboardStatsProvider);
      ref.invalidate(avvisiProvider);
    } catch (_) {
      // VPN/backend non pronti: resta il pulsante "Aggiorna da SAP" manuale.
    }
  });

  ref.onDispose(() {
    sub.cancel();
    sse.close();
  });
  return sse;
});

/// Azione "Aggiorna da SAP": chiede al cruscotto di ri-estrarre da SAP e
/// ricarica le liste. Il cruscotto parte vuoto finché SAP non spinge i dati,
/// quindi questa è l'azione che li fa comparire.
final refreshFromSapProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    await ref.read(remoteDataSourceProvider).refreshFromCruscotto();
    ref.invalidate(workOrdersProvider);
    ref.invalidate(dashboardStatsProvider);
    ref.invalidate(avvisiProvider);
  };
});
