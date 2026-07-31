// Creazione local-first di OdL e avvisi dal tablet.
//
// Gli oggetti creati sul campo restano SUL TABLET (persistiti in Hive) con un
// id provvisorio "TMP-…", finché l'operatore non preme "Sincronizza": solo
// allora vengono inviati al cruscotto. Quelli inviati con successo escono dal
// locale; quelli che falliscono restano sul tablet e si ritentano dopo.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/local_creation_store.dart';
import '../../domain/entities/entities.dart';
import 'core_providers.dart';

/// Store persistente degli oggetti creati sul tablet.
final localCreationStoreProvider =
    Provider<LocalCreationStore>((ref) => LocalCreationStore());

/// OdL creati sul tablet e non ancora sincronizzati.
final createdWorkOrdersProvider = FutureProvider<List<WorkOrder>>((ref) async {
  return ref.watch(localCreationStoreProvider).workOrders();
});

/// Avvisi creati sul tablet e non ancora sincronizzati.
final createdAvvisiProvider =
    FutureProvider<List<NotificationAvviso>>((ref) async {
  return ref.watch(localCreationStoreProvider).avvisi();
});

/// Numero di elementi locali in attesa di sincronizzazione (OdL + avvisi).
final pendingCreationCountProvider = FutureProvider<int>((ref) async {
  final wo = await ref.watch(createdWorkOrdersProvider.future);
  final av = await ref.watch(createdAvvisiProvider.future);
  return wo.length + av.length;
});

class CreationSyncResult {
  final int ok;
  final int failed;
  final String? firstError;
  const CreationSyncResult(
      {required this.ok, required this.failed, this.firstError});

  bool get nothingToDo => ok == 0 && failed == 0;
}

class CreationController {
  final Ref ref;
  CreationController(this.ref);

  LocalCreationStore get _store => ref.read(localCreationStoreProvider);

  /// Id provvisori: prefisso "TMP-" così le liste li riconoscono come locali.
  String newWorkOrderId() => 'TMP-ODL-${DateTime.now().millisecondsSinceEpoch}';
  String newAvvisoId() => 'TMP-AVV-${DateTime.now().millisecondsSinceEpoch}';

  Future<void> addWorkOrder(WorkOrder order) async {
    await _store.saveWorkOrder(order);
    ref.invalidate(createdWorkOrdersProvider);
  }

  Future<void> addAvviso(NotificationAvviso avviso) async {
    await _store.saveAvviso(avviso);
    ref.invalidate(createdAvvisiProvider);
  }

  Future<void> removeWorkOrder(String code) async {
    await _store.removeWorkOrder(code);
    ref.invalidate(createdWorkOrdersProvider);
  }

  Future<void> removeAvviso(String numero) async {
    await _store.removeAvviso(numero);
    ref.invalidate(createdAvvisiProvider);
  }

  /// Invia al cruscotto tutti gli oggetti creati sul tablet. Ciò che parte
  /// bene esce dal locale; ciò che fallisce (es. endpoint non ancora pronto)
  /// resta sul tablet per un nuovo tentativo.
  Future<CreationSyncResult> syncAll() async {
    final woRepo = ref.read(workOrderRepositoryProvider);
    final avRepo = ref.read(notificationRepositoryProvider);
    var ok = 0;
    var failed = 0;
    String? firstError;

    for (final order in await _store.workOrders()) {
      final res = await woRepo.createWorkOrder(order);
      if (res.isSuccess) {
        await _store.removeWorkOrder(order.externalCode);
        ok++;
      } else {
        failed++;
        firstError ??= res.failureOrNull?.message;
      }
    }

    for (final avviso in await _store.avvisi()) {
      final res = await avRepo.createAvviso(avviso);
      if (res.isSuccess) {
        await _store.removeAvviso(avviso.numeroAvviso);
        ok++;
      } else {
        failed++;
        firstError ??= res.failureOrNull?.message;
      }
    }

    ref.invalidate(createdWorkOrdersProvider);
    ref.invalidate(createdAvvisiProvider);
    return CreationSyncResult(ok: ok, failed: failed, firstError: firstError);
  }
}

final creationControllerProvider =
    Provider<CreationController>((ref) => CreationController(ref));
