import 'dart:io';

import 'package:dio/dio.dart';

import '../../core/error/failures.dart';
import '../../core/error/invio_sap.dart';
import '../../core/network/connectivity_service.dart';
import '../../core/network/result.dart';
import '../../core/services/odl_rimossi_store.dart';
import '../../domain/entities/entities.dart';
import '../../domain/repositories/sync_repository.dart';
import '../../domain/repositories/work_order_repository.dart';
import '../datasources/local/local_data_source.dart';
import '../datasources/remote/remote_data_source.dart';

class WorkOrderRepositoryImpl implements WorkOrderRepository {
  final WfmRemoteDataSource remote;
  final WfmLocalDataSource local;
  final ConnectivityService connectivity;
  final SyncRepository sync;

  WorkOrderRepositoryImpl(this.remote, this.local, this.connectivity, this.sync);

  /// Vero se l'errore è dovuto all'assenza di rete (non a un errore del
  /// server): in tal caso l'operazione va accodata invece di fallire.
  bool _isOffline(Object e) {
    if (e is DioException) {
      return e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.error is SocketException;
    }
    return e is SocketException;
  }

  @override
  Future<Result<List<WorkOrder>>> getWorkOrders(
      {WorkOrderFilter filter = const WorkOrderFilter()}) async {
    // Offline-first: se non c'è rete, restituisci la cache locale filtrata.
    // Difensivo: scarta anche qui un eventuale OdL chiuso rimasto da una
    // cache precedente (l'ordine "vive" comunque sul cruscotto).
    if (!connectivity.isOnline) {
      final cached = local
          .cachedWorkOrders()
          .where((o) => !_isTerminalStatus(o.status) && !_eliminato(o));
      return Success(_filterLocal(cached.toList(), filter));
    }
    try {
      // Recuperiamo SEMPRE l'elenco completo dal server, poi applichiamo lo
      // stato di pausa (solo locale) e filtriamo lato client. Il filtro sullo
      // stato NON può essere delegato al server: la "Pausa" è un concetto
      // locale (il server resta IN_ESECUZIONE), quindi filtrare sul server
      // metterebbe gli OdL in pausa nel bucket sbagliato ("In esecuzione") e
      // lascerebbe vuoto il filtro "In pausa".
      //
      // Il server (GET /work-orders) restituisce TUTTO ciò che è assegnato al
      // CID, chiuso compreso: non ha un modo di escluderlo. Un OdL chiuso non
      // serve più all'operatore (è già sul cruscotto), quindi lo si toglie qui
      // — dalla cache e dall'elenco — invece di lasciarlo per sempre sul
      // tablet. `cacheWorkOrders` RIMPIAZZA l'intera cache: non ricompare.
      final orders = await remote.getWorkOrders(const WorkOrderFilter());
      final merged = orders
          .map(_preserveLocalPause)
          .where((o) => !_isTerminalStatus(o.status) && !_eliminato(o))
          .toList();
      await local.cacheWorkOrders(merged);
      return Success(_filterLocal(merged, filter));
    } catch (e) {
      final cached = local
          .cachedWorkOrders()
          .where((o) => !_isTerminalStatus(o.status) && !_eliminato(o))
          .toList();
      if (cached.isNotEmpty) return Success(_filterLocal(cached, filter));
      return const Err(NetworkFailure());
    }
  }

  /// OdL che il tecnico ha eliminato su questo tablet: il backend lo elenca
  /// ancora, il tablet no.
  bool _eliminato(WorkOrder o) => OdlRimossiStore.contiene(o.externalCode);

  /// Se sul tablet l'OdL è "in pausa" (stato locale) ma il server lo riporta
  /// "in esecuzione", mantiene la pausa. Per gli altri stati vince il server.
  WorkOrder _preserveLocalPause(WorkOrder fromServer) {
    if (fromServer.status != WorkOrderStatus.inEsecuzione) return fromServer;
    final cached = local.cachedWorkOrder(fromServer.externalCode);
    return cached?.status == WorkOrderStatus.inPausa
        ? fromServer.copyWith(status: WorkOrderStatus.inPausa)
        : fromServer;
  }

  List<WorkOrder> _filterLocal(List<WorkOrder> all, WorkOrderFilter f) {
    Iterable<WorkOrder> r = all;
    if (f.status != null) r = r.where((o) => o.status == f.status);
    if (f.query != null && f.query!.isNotEmpty) {
      final q = f.query!.toLowerCase();
      r = r.where((o) =>
          o.externalCode.toLowerCase().contains(q) ||
          o.address.full.toLowerCase().contains(q) ||
          o.customer.fullName.toLowerCase().contains(q));
    }
    if (f.date != null) {
      final d = f.date!;
      r = r.where((o) =>
          o.appointmentDate != null &&
          o.appointmentDate!.year == d.year &&
          o.appointmentDate!.month == d.month &&
          o.appointmentDate!.day == d.day);
    }
    if (f.squadra != null && f.squadra!.isNotEmpty) {
      final sq = f.squadra!.toLowerCase();
      r = r.where((o) => o.squadra.toLowerCase().contains(sq));
    }
    if (f.centroLavoro != null && f.centroLavoro!.isNotEmpty) {
      final cl = f.centroLavoro!.toLowerCase();
      r = r.where((o) => o.centroLavoro.toLowerCase().contains(cl));
    }
    if (f.tecnico != null && f.tecnico!.isNotEmpty) {
      final t = f.tecnico!.toLowerCase();
      r = r.where((o) => (o.cidAssegnato ?? '').toLowerCase().contains(t));
    }
    return r.toList()
      ..sort((a, b) => (a.dataRiferimento ?? DateTime(2100))
          .compareTo(b.dataRiferimento ?? DateTime(2100)));
  }

  @override
  Future<Result<WorkOrder>> getWorkOrderDetail(String externalCode) async {
    if (!connectivity.isOnline) {
      final c = local.cachedWorkOrder(externalCode);
      return c != null ? Success(c) : const Err(NetworkFailure());
    }
    try {
      final o = _preserveLocalPause(await remote.getWorkOrderDetail(externalCode));
      await local.upsertWorkOrder(o);
      return Success(o);
    } catch (e) {
      // Disassegnato dal pianificatore: il backend risponde 404 { revocato:true }.
      // Non è un guasto: si rimuove la copia locale e si segnala come revocato,
      // così l'OdL sparisce dal tablet invece di restare in cache.
      if (e is DioException && e.response?.statusCode == 404) {
        final data = e.response?.data;
        if (data is Map && data['revocato'] == true) {
          await local.deleteWorkOrder(externalCode);
          return Err(RevocatoFailure(
            _serverMessage(e) ?? 'OdL non più assegnato: rimosso dal pianificatore.',
            revocataIl: data['revocataIl']?.toString(),
          ));
        }
        // 404 senza "revocato": l'ordine non esiste più lato backend (es.
        // "Ordine … non più presente in SAP"). Ripiegare sulla copia in cache
        // riaprirebbe un OdL fantasma: la si scarta e si dà il messaggio vero.
        await local.deleteWorkOrder(externalCode);
        return Err(NonTrovatoFailure(_serverMessage(e) ??
            'Questo ordine non è più disponibile.'));
      }
      final c = local.cachedWorkOrder(externalCode);
      // Mai il testo tecnico di Dio all'utente.
      return c != null
          ? Success(c)
          : Err(ServerFailure(e is DioException
              ? (_serverMessage(e) ?? 'Impossibile caricare l\'ordine.')
              : e.toString()));
    }
  }

  @override
  Future<Result<WorkOrder>> updateStatus(
      String externalCode, WorkOrderStatus newStatus,
      {String? reason, String? note, Geolocation? geolocation}) async {
    // In offline aggiorniamo localmente e accodiamo l'update.
    if (!connectivity.isOnline) {
      return _updateStatusOffline(externalCode, newStatus,
          reason: reason, note: note);
    }
    try {
      final o = await remote.updateStatus(externalCode, newStatus,
          reason: reason, note: note, geolocation: geolocation);
      // Rimuove l'ODL dalla cache del tablet per gli stati terminali.
      if (_isTerminalStatus(newStatus)) {
        await local.deleteWorkOrder(externalCode);
      } else {
        await local.upsertWorkOrder(o);
      }
      return Success(o);
    } catch (e) {
      // Errore di RETE (non del server): accoda invece di fallire.
      if (_isOffline(e)) {
        return _updateStatusOffline(externalCode, newStatus,
            reason: reason, note: note);
      }
      if (e is DioException && eInviatoSap(e)) {
        await _segnaInviatoSap(externalCode);
        return Err(inviatoSapFailure(e));
      }
      // Errore del server: mostra il messaggio vero del backend (es. "Stato
      // non valido" o "non assegnato"), non la stringa tecnica di Dio.
      if (e is DioException) {
        return Err(ServerFailure(
            _serverMessage(e) ?? e.message ?? 'Errore aggiornamento stato.'));
      }
      return Err(ServerFailure(e.toString()));
    }
  }

  /// Applica il cambio di stato solo in locale, marcandolo da sincronizzare, e
  /// accoda l'operazione per il rinvio automatico al ritorno della rete.
  Future<Result<WorkOrder>> _updateStatusOffline(
      String externalCode, WorkOrderStatus newStatus,
      {String? reason, String? note}) async {
    final c = local.cachedWorkOrder(externalCode);
    if (c == null) return const Err(NetworkFailure());
    final updated =
        c.copyWith(status: newStatus, localStatus: LocalSyncStatus.pendingUpload);
    // Rimuove l'ODL dalla cache del tablet per gli stati terminali.
    if (_isTerminalStatus(newStatus)) {
      await local.deleteWorkOrder(externalCode);
    } else {
      await local.upsertWorkOrder(updated);
    }
    await sync.enqueue(SyncOperation(
      id: 'status-$externalCode-${DateTime.now().millisecondsSinceEpoch}',
      type: SyncOperationType.updateStatus,
      entityId: externalCode,
      payload: {
        'status': newStatus.name,
        if (reason != null) 'reason': reason,
        if (note != null) 'note': note,
      },
      createdAt: DateTime.now(),
    ));
    return Success(updated);
  }

  /// Stati che causano la rimozione automatica dell'ODL dal tablet.
  ///
  /// Il SOSPESO NON c'è: un OdL sospeso resta assegnato al tecnico (il backend
  /// lo elenca con stato SOSPESO) e deve restare visibile sul tablet, nel
  /// filtro "Sospeso", per poterlo riprendere ("Riprendi" → in esecuzione).
  bool _isTerminalStatus(WorkOrderStatus s) =>
      s == WorkOrderStatus.completato ||
      s == WorkOrderStatus.annullato ||
      s == WorkOrderStatus.inviatoSAP;

  @override
  Future<Result<WorkOrder>> pauseLocally(String externalCode) async {
    final c = local.cachedWorkOrder(externalCode);
    if (c == null) return const Err(CacheFailure('ODL non trovato nella cache'));
    final paused = c.copyWith(status: WorkOrderStatus.inPausa);
    await local.upsertWorkOrder(paused);
    return Success(paused);
  }

  @override
  Future<Result<WorkOrder>> resumeFromPause(String externalCode) async {
    final c = local.cachedWorkOrder(externalCode);
    if (c == null) return const Err(CacheFailure('ODL non trovato nella cache'));
    // Il server ha ancora inEsecuzione, quindi ripristiniamo solo in locale.
    final resumed = c.copyWith(status: WorkOrderStatus.inEsecuzione);
    await local.upsertWorkOrder(resumed);
    return Success(resumed);
  }

  @override
  Future<Result<WorkOrder>> updateWorkOrder(WorkOrder order) async {
    if (!connectivity.isOnline) return _updateWorkOrderOffline(order);
    try {
      final o = await remote.updateWorkOrder(order);
      await local.upsertWorkOrder(o);
      return Success(o);
    } catch (e) {
      if (_isOffline(e)) return _updateWorkOrderOffline(order);
      if (e is DioException) {
        if (eInviatoSap(e)) {
          await _segnaInviatoSap(order.externalCode);
          return Err(inviatoSapFailure(e));
        }
        return Err(ServerFailure(
            _serverMessage(e) ?? 'Impossibile salvare l\'ordine.'));
      }
      return Err(ServerFailure(e.toString()));
    }
  }

  /// Il backend ha risposto 409 "già inviato a SAP": la copia locale diventa
  /// in sola lettura subito, senza aspettare il prossimo aggiornamento.
  Future<void> _segnaInviatoSap(String externalCode) async {
    final c = local.cachedWorkOrder(externalCode);
    if (c != null) await local.upsertWorkOrder(c.copyWith(inviatoSap: true));
  }

  Future<Result<WorkOrder>> _updateWorkOrderOffline(WorkOrder order) async {
    final updated = order.copyWith(localStatus: LocalSyncStatus.pendingUpload);
    await local.upsertWorkOrder(updated);
    await sync.enqueue(SyncOperation(
      id: 'save-${order.externalCode}-${DateTime.now().millisecondsSinceEpoch}',
      type: SyncOperationType.updateWorkOrder,
      entityId: order.externalCode,
      createdAt: DateTime.now(),
    ));
    return Success(updated);
  }

  @override
  Future<Result<WorkOrder>> createWorkOrder(WorkOrder order) async {
    try {
      final o = await remote.createWorkOrder(order);
      await local.upsertWorkOrder(o);
      return Success(o);
    } on DioException catch (e) {
      // Messaggio chiaro dal backend (es. 422 "serve la matricola…"), non la
      // stringa tecnica di Dio: così l'operatore sa perché non si sincronizza.
      return Err(ServerFailure(
          _serverMessage(e) ?? e.message ?? 'Errore creazione ordine.'));
    } catch (e) {
      return Err(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> deleteWorkOrder(String externalCode) async {
    // Eliminare sul tablet vale SOLO per il tablet: il backend non cancella
    // gli ordini (501) e non serve chiamarlo. L'OdL esce dalla cache e non
    // ricompare agli aggiornamenti (OdlRimossiStore); sul cruscotto resta.
    try {
      await OdlRimossiStore.rimuovi(externalCode);
      await local.deleteWorkOrder(externalCode);
      return const Success<void>(null);
    } catch (e) {
      return Err(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> reassign(String externalCode, String technicianCid,
      {String? note}) async {
    // Niente coda offline: se il collega esiste, se il lavoro si può ancora
    // cedere, lo decide il backend. Accodarlo mostrerebbe un passaggio che
    // magari verrà rifiutato quando il collega l'ha già in mano.
    if (!connectivity.isOnline) {
      return const Err(NetworkFailure(
          'Serve la connessione per passare l\'OdL a un collega.'));
    }
    try {
      await remote.reassignWorkOrder(externalCode, technicianCid, note: note);
      // Dopo il 200 il lavoro non torna più in GET /work-orders: lo si toglie
      // subito dal tablet.
      await local.deleteWorkOrder(externalCode);
      return const Success<void>(null);
    } on DioException catch (e) {
      if (_isOffline(e)) {
        return const Err(NetworkFailure(
            'Serve la connessione per passare l\'OdL a un collega.'));
      }
      if (eInviatoSap(e)) {
        await _segnaInviatoSap(externalCode);
        return Err(inviatoSapFailure(e));
      }
      return Err(ServerFailure(
          _serverMessage(e) ?? 'Impossibile passare l\'OdL al collega.'));
    } catch (e) {
      return Err(ServerFailure(e.toString()));
    }
  }

  /// Estrae il messaggio leggibile dal corpo dell'errore del backend
  /// (`{ error: "…" }`), evitando di mostrare la stringa tecnica di Dio.
  String? _serverMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['error'] != null) {
      return data['error'].toString();
    }
    return null;
  }

  @override
  Future<Result<Map<WorkOrderStatus, int>>> getStats() async {
    final res = await getWorkOrders();
    return res.when(
      success: (orders) {
        final map = <WorkOrderStatus, int>{};
        for (final s in WorkOrderStatus.values) {
          map[s] = orders.where((o) => o.status == s).length;
        }
        return Success(map);
      },
      failure: (f) => Err(f),
    );
  }
}
