// Realtime: aggancia l'SSE del backend (GET /api/stream) e aggiorna le liste in
// tempo reale. Il tablet vede solo gli oggetti ASSEGNATI: quando il pianificatore
// assegna/cambia stato dal cruscotto il backend emette l'evento `assegnazioni`,
// e quando arrivano nuovi dati SAP emette `ordini`/`avvisi`/`snapshot`. Qui
// invalidiamo i provider delle liste così la UI si ricarica da sola.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/sse_service.dart';
import 'core_providers.dart';
import 'work_orders_provider.dart';
import 'avvisi_provider.dart';

/// Servizio SSE vivo per tutta la sessione. Va "osservato" (es. dallo shell)
/// perché parta; alla dismissione chiude lo stream.
final realtimeProvider = Provider<SseService>((ref) {
  final client = ref.watch(dioClientProvider);
  // L'SSE sta su base /api (dioRead), NON su /api/v1 (dio): GET /api/stream.
  final sse = SseService(client.dioRead);

  void ricaricaOrdini() {
    ref.invalidate(workOrdersProvider);
    ref.invalidate(dashboardStatsProvider);
  }

  final sub = sse.events.listen((e) {
    switch (e.event) {
      case 'assegnazioni':
        // Il pianificatore ha assegnato/cambiato stato: cambia il lavoro del
        // tecnico (sia ordini che avvisi possono comparire/sparire).
        ricaricaOrdini();
        ref.invalidate(avvisiProvider);
        break;
      case 'ordini':
        ricaricaOrdini();
        break;
      case 'avvisi':
        ref.invalidate(avvisiProvider);
        break;
      case 'snapshot':
      case 'reset':
        ricaricaOrdini();
        ref.invalidate(avvisiProvider);
        break;
    }
  });

  sse.start();
  ref.onDispose(() {
    sub.cancel();
    sse.close();
  });
  return sse;
});

/// Azione "Aggiorna": ri-legge dal backend le liste (nuove assegnazioni, stati
/// aggiornati). NON tocca SAP: il pull da SAP è azione del pianificatore
/// (cruscotto), non del tablet.
final refreshFromSapProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    ref.invalidate(workOrdersProvider);
    ref.invalidate(dashboardStatsProvider);
    ref.invalidate(avvisiProvider);
    // Attende il completamento della ri-lettura ordini, così il pull-to-refresh
    // mostra lo spinner finché i dati non sono pronti.
    await ref.read(workOrdersProvider.future);
  };
});
