import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/error/failures.dart';
import '../../core/network/result.dart';
import '../../core/services/arrival_store.dart';
import '../../core/services/stock_impegnato_store.dart';
import '../../domain/entities/entities.dart';
import '../../domain/repositories/work_order_repository.dart';
import 'connectivity_provider.dart';
import 'core_providers.dart';
import 'avvisi_provider.dart';
import 'creation_provider.dart';
import 'odl_extension_provider.dart';

/// Filtro corrente dell'elenco OdL.
final workOrderFilterProvider =
    StateProvider<WorkOrderFilter>((ref) => const WorkOrderFilter());

/// Elenco OdL filtrato. Si aggiorna quando cambia filtro o connettività.
final workOrdersProvider = FutureProvider<List<WorkOrder>>((ref) async {
  ref.watch(connectivityStatusProvider); // refetch quando cambia rete
  final filter = ref.watch(workOrderFilterProvider);

  // OdL creati sul tablet (local-first), filtrati come i remoti e messi in cima.
  // Se la lettura locale fallisce non si perde l'elenco del cruscotto.
  var locali = <WorkOrder>[];
  try {
    locali = await ref.watch(createdWorkOrdersProvider.future);
  } catch (_) {
    locali = const [];
  }
  if (filter.status != null) {
    locali = locali.where((o) => o.status == filter.status).toList();
  }
  final q = filter.query;
  if (q != null && q.trim().isNotEmpty) {
    final needle = q.toLowerCase();
    locali = locali
        .where((o) =>
            o.externalCode.toLowerCase().contains(needle) ||
            o.displayName.toLowerCase().contains(needle))
        .toList();
  }

  final repo = ref.watch(workOrderRepositoryProvider);
  try {
    final result = await repo.getWorkOrders(filter: filter);
    final remote = switch (result) {
      Success(value: final v) => v,
      Err(failure: final f) => throw Exception(f.message),
    };
    // Si annota quando ogni OdL è arrivato sul tablet e si mostrano i più
    // recenti in cima (il backend li dà dal più vecchio).
    // Solo sull'elenco COMPLETO: da una lista filtrata, gli OdL degli altri stati
    // sembrerebbero poi "nuovi".
    if (filter.status == null && (q == null || q.trim().isEmpty)) {
      await ArrivalStore.seen('odl', remote.map((o) => o.externalCode));
    }
    return ArrivalStore.sortNewestFirst(
        [...locali, ...remote], 'odl', (o) => o.externalCode);
  } catch (_) {
    // Offline o cruscotto irraggiungibile: mostra almeno i creati sul tablet.
    if (locali.isNotEmpty) {
      return ArrivalStore.sortNewestFirst(locali, 'odl', (o) => o.externalCode);
    }
    rethrow;
  }
});

/// Elenco OdL filtrato per un singolo stato — usato dalle card cliccabili
/// del "Riepilogo di oggi" in Home. Non tocca il filtro globale della scheda
/// Ordini: ogni categoria ha il suo provider isolato.
///
/// La fonte è la stessa di [dashboardStatsProvider] (repo → getWorkOrders),
/// quindi il numero mostrato sulla card coincide sempre con la lista aperta.
final workOrdersByStatusProvider =
    FutureProvider.family<List<WorkOrder>, WorkOrderStatus>((ref, status) async {
  ref.watch(connectivityStatusProvider); // refetch quando cambia rete
  final repo = ref.watch(workOrderRepositoryProvider);
  final result = await repo.getWorkOrders(filter: WorkOrderFilter(status: status));
  return switch (result) {
    Success(value: final v) => v,
    Err(failure: final f) => throw Exception(f.message),
  };
});

/// Elenco degli OdL di Pronto Intervento (urgenti), ordinati per priorità.
///
/// Deriva dai campi reali del backend via [WorkOrder.isProntoIntervento];
/// esclude gli ordini chiusi/annullati/inviati a SAP (non più azionabili).
final prontoInterventoWorkOrdersProvider =
    FutureProvider<List<WorkOrder>>((ref) async {
  ref.watch(connectivityStatusProvider);
  final repo = ref.watch(workOrderRepositoryProvider);
  final result = await repo.getWorkOrders();
  final all = switch (result) {
    Success(value: final v) => v,
    Err(failure: final f) => throw Exception(f.message),
  };
  // Solo i PI NON ancora presi in carico: appena l'operatore preme "Avvia"
  // (stato -> IN_ESECUZIONE) il banner sparisce. Ricevuto = ancora da avviare.
  final pi = all
      .where((o) =>
          o.isProntoIntervento && o.status == WorkOrderStatus.ricevuto)
      .toList()
    // I più urgenti in cima: prima priorità alta, poi appuntamento più vicino.
    ..sort((a, b) {
      if (a.isHighPriority != b.isHighPriority) {
        return a.isHighPriority ? -1 : 1;
      }
      final da = a.dataRiferimento ?? DateTime(2100);
      final db = b.dataRiferimento ?? DateTime(2100);
      return da.compareTo(db);
    });
  return pi;
});

/// Statistiche per la dashboard (home).
final dashboardStatsProvider =
    FutureProvider<Map<WorkOrderStatus, int>>((ref) async {
  ref.watch(connectivityStatusProvider);
  final repo = ref.watch(workOrderRepositoryProvider);
  final result = await repo.getStats();
  return result.when(
    success: (m) => m,
    failure: (f) => throw Exception(f.message),
  );
});

/// Dettaglio di un OdL (M3).
final workOrderDetailProvider =
    FutureProvider.family<WorkOrder, String>((ref, code) async {
  // Prima gli OdL creati sul tablet (id TMP): non esistono lato cruscotto.
  try {
    final locali = await ref.watch(createdWorkOrdersProvider.future);
    for (final o in locali) {
      if (o.externalCode == code) return o;
    }
  } catch (_) {
    // Lettura locale non riuscita: si prosegue col cruscotto.
  }
  final repo = ref.watch(workOrderRepositoryProvider);
  final result = await repo.getWorkOrderDetail(code);
  return result.when(
    success: (o) => o,
    // Si lancia la Failure tipizzata (non un Exception generico): la UI può
    // distinguere un OdL revocato da un errore qualunque.
    failure: (f) => throw f,
  );
});

/// Esito di un passaggio a un collega.
enum EsitoRiassegnazione {
  /// Passato subito (OdL già sul cruscotto): non è più su questo tablet.
  passato,

  /// OdL non ancora inviato: passerà al collega appena inviato.
  allInvio,

  /// OdL non ancora inviato, riportato a chi l'ha creato.
  resta,
}

/// Esito dell'eliminazione di un OdL insieme al suo avviso.
class EliminazioneOdl {
  /// Esito dell'eliminazione dell'OdL.
  final Result<void> odl;

  /// Numero dell'avviso associato che andava eliminato (null = nessuno).
  final String? avviso;

  /// Vero se l'avviso associato è stato eliminato.
  final bool avvisoEliminato;

  /// Perché l'avviso non è stato eliminato (l'OdL invece sì).
  final String? erroreAvviso;

  const EliminazioneOdl(this.odl,
      {this.avviso, this.avvisoEliminato = false, this.erroreAvviso});
}

/// Controller per le azioni del ciclo di vita (M4).
class WorkOrderActions {
  final Ref ref;
  WorkOrderActions(this.ref);

  Future<Result<WorkOrder>> changeStatus(
    String code,
    WorkOrderStatus status, {
    String? reason,
    String? note,
    Geolocation? geolocation,
  }) async {
    // "Avvia" (→ in esecuzione): registra l'ora reale di inizio sul campo, così
    // l'esito non parte più da mezzanotte dell'appuntamento. Solo la prima
    // volta (segnaAvvio non sovrascrive un avvio già registrato).
    if (status == WorkOrderStatus.inEsecuzione) {
      await ref.read(odlExtensionProvider(code).notifier).segnaAvvio();
    }
    // OdL creato sul tablet e non ancora sincronizzato: NON esiste lato backend
    // (updateStatus → 404). Offline-first: l'operatore deve poterlo lavorare
    // comunque. Il cambio di stato si applica sull'outbox locale e viaggerà con
    // l'OdL alla sincronizzazione. Nessuna chiamata al backend, nessun 404.
    final pending = await ref.read(isPendingCreationProvider(code).future);
    if (pending) {
      final store = ref.read(localCreationStoreProvider);
      final current = await store.workOrder(code);
      if (current != null) {
        final updated = current.copyWith(status: status);
        await store.saveWorkOrder(updated);
        ref.invalidate(createdWorkOrdersProvider);
        ref.invalidate(workOrdersProvider);
        ref.invalidate(dashboardStatsProvider);
        ref.invalidate(workOrderDetailProvider(code));
        ref.invalidate(prontoInterventoWorkOrdersProvider);
        return Success(updated);
      }
    }
    final repo = ref.read(workOrderRepositoryProvider);
    final res = await repo.updateStatus(code, status,
        reason: reason, note: note, geolocation: geolocation);
    if (res.isSuccess) {
      ref.invalidate(workOrdersProvider);
      ref.invalidate(dashboardStatsProvider);
      ref.invalidate(workOrderDetailProvider(code));
      // Il banner PI deve sparire subito dopo "Avvia" (stato -> IN_ESECUZIONE).
      ref.invalidate(prontoInterventoWorkOrdersProvider);
    }
    return res;
  }

  Future<Result<WorkOrder>> save(WorkOrder order) async {
    final repo = ref.read(workOrderRepositoryProvider);
    final res = await repo.updateWorkOrder(order);
    if (res.isSuccess) {
      ref.invalidate(workOrderDetailProvider(order.externalCode));
      ref.invalidate(workOrdersProvider);
    }
    return res;
  }

  Future<Result<WorkOrder>> create(WorkOrder order) async {
    final repo = ref.read(workOrderRepositoryProvider);
    final res = await repo.createWorkOrder(order);
    if (res.isSuccess) {
      ref.invalidate(workOrdersProvider);
      ref.invalidate(dashboardStatsProvider);
    }
    return res;
  }

  /// Numero dell'avviso a cui l'OdL è associato (`avvisoOrigine`, in
  /// mancanza `notificationNumberSAP`), null se non ne ha.
  Future<String?> _avvisoAssociato(String code) async {
    WorkOrder? o;
    try {
      o = await ref.read(workOrderDetailProvider(code).future);
    } catch (_) {
      try {
        final tutti = await ref.read(workOrdersProvider.future);
        o = tutti.where((x) => x.externalCode == code).firstOrNull;
      } catch (_) {}
    }
    for (final v in [o?.avvisoOrigine, o?.notificationNumberSap]) {
      final n = (v ?? '').trim();
      if (n.isNotEmpty) return n;
    }
    return null;
  }

  /// L'avviso che si elimina insieme all'OdL [code], o null. Se un altro OdL
  /// è ancora associato allo stesso avviso, l'avviso resta: eliminarlo
  /// lascerebbe quell'OdL senza il suo avviso.
  Future<String?> avvisoDaEliminare(String code) async {
    final numero = await _avvisoAssociato(code);
    if (numero == null) return null;
    try {
      final altri = await ref.read(workOrdersProvider.future);
      final condiviso = altri.any((o) =>
          o.externalCode != code &&
          (o.avvisoOrigine == numero || o.notificationNumberSap == numero));
      if (condiviso) return null;
    } catch (_) {}
    return numero;
  }

  /// Un OdL eliminato non ha usato i materiali che gli erano stati assegnati:
  /// tornano ciascuno nel magazzino da cui erano stati prelevati.
  Future<void> _rilasciaMateriali(String code) async {
    try {
      final ext = await ref.read(odlExtensionRepositoryProvider).get(code);
      for (final m in ext.materiali) {
        await StockImpegnatoStore.rilascia(
            m.materialCode, m.warehouseCode, m.usedQuantity);
      }
    } catch (_) {/* nessun materiale da restituire */}
  }

  /// Elimina definitivamente un OdL **e il suo avviso associato**. L'avviso si
  /// elimina solo se l'OdL è stato eliminato; se è l'avviso a non riuscire,
  /// l'OdL resta eliminato e l'errore dell'avviso è nell'esito.
  Future<EliminazioneOdl> eliminaConAvviso(String code) async {
    final avviso = await avvisoDaEliminare(code);
    final Result<void> res;
    if (await ref.read(isPendingCreationProvider(code).future)) {
      // OdL nato sul tablet e non ancora inviato: si toglie dall'archivio
      // locale, il backend non lo conosce.
      await ref.read(creationControllerProvider).removeWorkOrder(code);
      res = const Success<void>(null);
    } else {
      // Eliminare sul tablet vale solo per il tablet (il dépôt non chiama il
      // backend): l'OdL non compare più in elenco.
      res = await ref.read(workOrderRepositoryProvider).deleteWorkOrder(code);
    }
    if (!res.isSuccess) return EliminazioneOdl(res);
    await _rilasciaMateriali(code);
    ref.invalidate(workOrderDetailProvider(code));
    ref.invalidate(prontoInterventoWorkOrdersProvider);
    ref.invalidate(workOrdersProvider);
    ref.invalidate(dashboardStatsProvider);
    if (avviso == null) return EliminazioneOdl(res);

    try {
      await ref.read(rimuoviAvvisoDalTabletProvider)(avviso);
      return EliminazioneOdl(res, avviso: avviso, avvisoEliminato: true);
    } catch (e) {
      return EliminazioneOdl(res, avviso: avviso, erroreAvviso: '$e');
    }
  }

  /// Dopo la chiusura dell'OdL toglie dal tablet anche il suo avviso
  /// ([avviso] = `avvisoDaEliminare`, calcolato PRIMA della chiusura, quando
  /// l'OdL è ancora leggibile). Non fallisce mai: la chiusura è già andata.
  Future<void> rimuoviAvvisoDopoChiusura(String? avviso) async {
    if (avviso == null) return;
    try {
      await ref.read(rimuoviAvvisoDalTabletProvider)(avviso);
    } catch (_) {/* l'avviso resta in elenco: nessun danno */}
  }

  /// Elimina definitivamente un OdL (e il suo avviso associato).
  Future<Result<void>> delete(String code) async =>
      (await eliminaConAvviso(code)).odl;

  /// Passa l'OdL a un collega (`POST /work-orders/:id/reassign`).
  ///
  /// OdL creato sul tablet e non ancora inviato: il backend non lo conosce
  /// (risponderebbe 404). Si cambia solo il collega a cui passarlo, e il
  /// passaggio vero avviene appena l'OdL viene inviato (CreationController).
  /// Scegliere chi l'ha creato annulla il passaggio.
  Future<Result<EsitoRiassegnazione>> reassign(
      String code, String technicianCid,
      {String? note}) async {
    if (await ref.read(isPendingCreationProvider(code).future)) {
      final store = ref.read(localCreationStoreProvider);
      final current = await store.workOrder(code);
      if (current == null) {
        return const Err(ValidationFailure('OdL non trovato sul tablet.'));
      }
      final perMe = technicianCid == current.cidAssegnato;
      await store.saveWorkOrder(
          current.copyWith(assegnaA: perMe ? '' : technicianCid));
      ref.invalidate(createdWorkOrdersProvider);
      ref.invalidate(workOrdersProvider);
      ref.invalidate(workOrderDetailProvider(code));
      return Success(perMe
          ? EsitoRiassegnazione.resta
          : EsitoRiassegnazione.allInvio);
    }
    final res = await ref
        .read(workOrderRepositoryProvider)
        .reassign(code, technicianCid, note: note);
    if (res.isSuccess) {
      // Il dettaglio non si ricarica: il backend ormai risponde 404, e le
      // schermate tornano alla lista.
      ref.invalidate(workOrdersProvider);
      ref.invalidate(dashboardStatsProvider);
      ref.invalidate(prontoInterventoWorkOrdersProvider);
      return const Success(EsitoRiassegnazione.passato);
    }
    return Err(res.failureOrNull!);
  }

  /// Pausa locale: non invia nulla al server (server vede ancora inEsecuzione).
  Future<Result<WorkOrder>> pauseLocally(String code) async {
    final repo = ref.read(workOrderRepositoryProvider);
    final res = await repo.pauseLocally(code);
    if (res.isSuccess) {
      ref.invalidate(workOrdersProvider);
      ref.invalidate(workOrderDetailProvider(code));
    }
    return res;
  }

  /// Riprende dalla pausa locale: non invia nulla al server.
  Future<Result<WorkOrder>> resumeFromPause(String code) async {
    final repo = ref.read(workOrderRepositoryProvider);
    final res = await repo.resumeFromPause(code);
    if (res.isSuccess) {
      ref.invalidate(workOrdersProvider);
      ref.invalidate(workOrderDetailProvider(code));
    }
    return res;
  }
}

final workOrderActionsProvider =
    Provider<WorkOrderActions>((ref) => WorkOrderActions(ref));
