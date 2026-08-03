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

/// True se l'oggetto è ancora SOLO sul tablet, cioè non è stato inviato.
///
/// Non basta guardare il prefisso "TMP-": dopo l'invio il cruscotto conserva
/// l'id provvisorio finché SAP non assegna il numero definitivo, quindi il
/// codice resta "TMP-…" anche per un oggetto già sincronizzato. L'unica prova
/// attendibile è la presenza nell'elenco locale.
final isPendingCreationProvider =
    FutureProvider.family<bool, String>((ref, id) async {
  final wo = await ref.watch(createdWorkOrdersProvider.future);
  if (wo.any((o) => o.externalCode == id)) return true;
  final av = await ref.watch(createdAvvisiProvider.future);
  return av.any((a) => a.numeroAvviso == id);
});

class CreationSyncResult {
  final int ok;
  final int failed;
  final String? firstError;
  const CreationSyncResult(
      {required this.ok, required this.failed, this.firstError});

  bool get nothingToDo => ok == 0 && failed == 0;
}

/// Dove inviare un oggetto creato sul campo.
///
/// - [cruscotto]: percorso normale, l'oggetto passa dal cruscotto che poi lo
///   propaga a SAP.
/// - [sap]: invio diretto, riservato agli avvisi che non devono passare dal
///   cruscotto. Il canale non è ancora configurato lato backend: l'app lo
///   espone ma non simula l'invio.
enum SyncDestination {
  cruscotto,
  sap;

  String get label => switch (this) {
        SyncDestination.cruscotto => 'Cruscotto',
        SyncDestination.sap => 'SAP',
      };
}

/// Esito dell'invio di un singolo oggetto.
class SendResult {
  final bool ok;
  final String message;
  const SendResult(this.ok, this.message);
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

  /// Messaggio unico per il canale diretto verso SAP, non ancora attivo.
  static const _sapNonConfigurato =
      'Invio diretto a SAP non ancora configurato sul backend. '
      'Per ora usa l\'invio al cruscotto.';

  /// Invia un singolo ordine alla destinazione scelta.
  /// Se l'invio riesce, l'ordine esce dall'elenco locale.
  Future<SendResult> sendWorkOrder(
    WorkOrder order, {
    required SyncDestination destination,
  }) async {
    if (destination == SyncDestination.sap) {
      return const SendResult(false, _sapNonConfigurato);
    }
    final res = await ref.read(workOrderRepositoryProvider).createWorkOrder(order);
    if (res.isSuccess) {
      await _store.removeWorkOrder(order.externalCode);
      ref.invalidate(createdWorkOrdersProvider);
      return const SendResult(true, 'Ordine inviato al cruscotto');
    }
    return SendResult(false, _motivo(res.failureOrNull?.message));
  }

  /// Invia un singolo avviso alla destinazione scelta.
  Future<SendResult> sendAvviso(
    NotificationAvviso avviso, {
    required SyncDestination destination,
  }) async {
    if (destination == SyncDestination.sap) {
      return const SendResult(false, _sapNonConfigurato);
    }
    final res =
        await ref.read(notificationRepositoryProvider).createAvviso(avviso);
    if (res.isSuccess) {
      await _store.removeAvviso(avviso.numeroAvviso);
      ref.invalidate(createdAvvisiProvider);
      return const SendResult(true, 'Avviso inviato al cruscotto');
    }
    return SendResult(false, _motivo(res.failureOrNull?.message));
  }

  /// Traduce l'errore tecnico in un messaggio comprensibile all'operatore.
  String _motivo(String? errore) {
    final e = errore ?? '';
    if (e.contains('501')) {
      return 'Il cruscotto non accetta ancora la creazione dal campo. '
          'L\'elemento resta salvato sul tablet.';
    }
    return 'Invio non riuscito. L\'elemento resta salvato sul tablet.';
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
