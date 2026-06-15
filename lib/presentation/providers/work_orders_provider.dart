import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/result.dart';
import '../../domain/entities/entities.dart';
import '../../domain/repositories/work_order_repository.dart';
import 'connectivity_provider.dart';
import 'core_providers.dart';

/// Filtro corrente dell'elenco OdL.
final workOrderFilterProvider =
    StateProvider<WorkOrderFilter>((ref) => const WorkOrderFilter());

/// Elenco OdL filtrato (M2). Si aggiorna quando cambia filtro o connettività.
final workOrdersProvider = FutureProvider<List<WorkOrder>>((ref) async {
  ref.watch(connectivityStatusProvider); // refetch quando cambia rete
  final filter = ref.watch(workOrderFilterProvider);
  final repo = ref.watch(workOrderRepositoryProvider);
  final result = await repo.getWorkOrders(filter: filter);
  return switch (result) {
    Success(value: final v) => v,
    Err(failure: final f) => throw Exception(f.message),
  };
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
