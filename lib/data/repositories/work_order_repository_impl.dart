import 'dart:io';

import 'package:dio/dio.dart';

import '../../core/error/failures.dart';
import '../../core/network/connectivity_service.dart';
import '../../core/network/result.dart';
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
    if (!connectivity.isOnline) {
      return Success(_filterLocal(local.cachedWorkOrders(), filter));
    }
    try {
      // Recuperiamo SEMPRE l'elenco completo dal server, poi applichiamo lo
      // stato di pausa (solo locale) e filtriamo lato client. Il filtro sullo
      // stato NON può essere delegato al server: la "Pausa" è un concetto
      // locale (il server resta IN_ESECUZIONE), quindi filtrare sul server
      // metterebbe gli OdL in pausa nel bucket sbagliato ("In esecuzione") e
      // lascerebbe vuoto il filtro "In pausa".
      final orders = await remote.getWorkOrders(const WorkOrderFilter());
      final merged = orders.map(_preserveLocalPause).toList();
      await local.cacheWorkOrders(merged);
      return Success(_filterLocal(merged, filter));
    } catch (e) {
      final cached = local.cachedWorkOrders();
      if (cached.isNotEmpty) return Success(_filterLocal(cached, filter));
      return const Err(NetworkFailure());
    }
  }

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
      ..sort((a, b) => (a.appointmentDate ?? DateTime(2100))
          .compareTo(b.appointmentDate ?? DateTime(2100)));
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
      final c = local.cachedWorkOrder(externalCode);
      return c != null ? Success(c) : Err(ServerFailure(e.toString()));
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
      // Rimuove l'ODL dalla cache del tablet per stati terminali/sospeso.
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
    // Rimuove l'ODL dalla cache del tablet per stati terminali/sospeso.
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
  bool _isTerminalStatus(WorkOrderStatus s) =>
      s == WorkOrderStatus.sospeso ||
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
      return Err(ServerFailure(e.toString()));
    }
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
    } catch (e) {
      return Err(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> deleteWorkOrder(String externalCode) async {
    try {
      await remote.deleteWorkOrder(externalCode);
      await local.deleteWorkOrder(externalCode);
      return const Success<void>(null);
    } catch (e) {
      return Err(ServerFailure(e.toString()));
    }
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
