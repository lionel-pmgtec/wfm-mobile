import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/result.dart';
import '../../domain/entities/entities.dart';
import '../../domain/repositories/work_order_repository.dart';
import 'connectivity_provider.dart';
import 'core_providers.dart';
import 'creation_provider.dart';

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
    return [...locali, ...remote];
  } catch (_) {
    // Offline o cruscotto irraggiungibile: mostra almeno i creati sul tablet.
    if (locali.isNotEmpty) return locali;
    rethrow;
  }
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
    failure: (f) => throw Exception(f.message),
  );
});

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
    final repo = ref.read(workOrderRepositoryProvider);
    final res = await repo.updateStatus(code, status,
        reason: reason, note: note, geolocation: geolocation);
    if (res.isSuccess) {
      ref.invalidate(workOrdersProvider);
      ref.invalidate(dashboardStatsProvider);
      ref.invalidate(workOrderDetailProvider(code));
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

  /// Elimina definitivamente un OdL.
  Future<Result<void>> delete(String code) async {
    final repo = ref.read(workOrderRepositoryProvider);
    final res = await repo.deleteWorkOrder(code);
    if (res.isSuccess) {
      ref.invalidate(workOrdersProvider);
      ref.invalidate(dashboardStatsProvider);
    }
    return res;
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
