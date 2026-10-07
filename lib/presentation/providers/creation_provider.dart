// Creazione local-first di OdL e avvisi dal tablet.
//
// Gli oggetti creati sul campo restano SUL TABLET (persistiti in Hive) con un
// id provvisorio "TMP-…", finché l'operatore non preme "Sincronizza": solo
// allora vengono inviati al cruscotto. Quelli inviati con successo escono dal
// locale; quelli che falliscono restano sul tablet e si ritentano dopo.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/arrival_store.dart';
import '../../data/local/local_creation_store.dart';
import '../../domain/entities/entities.dart';
import 'core_providers.dart';
import 'sync_provider.dart';
import 'work_orders_provider.dart';

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

  /// OdL inviati ma NON passati al collega scelto (restano a chi li ha
  /// creati: si riassegnano dal dettaglio).
  final int nonPassati;
  final String? primoNonPassato;
  const CreationSyncResult(
      {required this.ok,
      required this.failed,
      this.firstError,
      this.nonPassati = 0,
      this.primoNonPassato});

  bool get nothingToDo => ok == 0 && failed == 0;
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
    // Salvare di nuovo (es. una nota) non deve far "ringiovanire" l'OdL.
    if (ArrivalStore.of('odl', order.externalCode) == null) {
      await ArrivalStore.arrivedNow('odl', order.externalCode);
    }
    ref.invalidate(createdWorkOrdersProvider);
  }

  Future<void> addAvviso(NotificationAvviso avviso) async {
    await _store.saveAvviso(avviso);
    if (ArrivalStore.of('avv', avviso.numeroAvviso) == null) {
      await ArrivalStore.arrivedNow('avv', avviso.numeroAvviso);
    }
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

  /// Invia un singolo ordine al Cruscotto, che lo inoltra a SAP.
  /// Se l'invio riesce, l'ordine esce dall'elenco locale.
  Future<SendResult> sendWorkOrder(WorkOrder order) async {
    final res = await ref.read(workOrderRepositoryProvider).createWorkOrder(order);
    if (res.isSuccess) {
      await _store.removeWorkOrder(order.externalCode);
      ref.invalidate(createdWorkOrdersProvider);
      final collega = order.assegnaA;
      if (collega == null) {
        _rimandaAllegati();
        return const SendResult(true, 'Ordine inviato al cruscotto');
      }
      final errore = await _passaAlCollega(res.valueOrNull ?? order, collega);
      return SendResult(
          true,
          errore == null
              ? 'Ordine inviato al cruscotto e passato a $collega'
              : _nonPassato(collega, errore));
    }
    return SendResult(false, _motivo(res.failureOrNull?.message));
  }

  /// L'OdL appena accettato dal backend è assegnato a chi l'ha creato (regola
  /// del backend). Se in creazione è stato scelto un collega, glielo si passa
  /// con la stessa riassegnazione di "Riassegna OdL". Prima però partono le
  /// foto/firme prese su questo tablet: il backend le accetta solo per un
  /// ordine assegnato a chi le manda. Ritorna null se è andato bene,
  /// altrimenti il motivo (l'OdL resta a chi l'ha creato).
  Future<String?> _passaAlCollega(WorkOrder creato, String collega) async {
    await ref
        .read(syncProcessorProvider)
        .process(force: true)
        .catchError((_) => 0);
    final res = await ref
        .read(workOrderRepositoryProvider)
        .reassign(creato.externalCode, collega);
    if (res.isSuccess) {
      ref.invalidate(workOrdersProvider);
      ref.invalidate(dashboardStatsProvider);
      ref.invalidate(prontoInterventoWorkOrdersProvider);
      return null;
    }
    return res.failureOrNull?.message ?? 'errore sconosciuto';
  }

  String _nonPassato(String collega, String errore) =>
      'Ordine inviato al cruscotto, ma non passato a $collega: $errore '
      'Resta assegnato a te: puoi riassegnarlo dal dettaglio dell\'OdL.';

  /// Invia un singolo avviso al Cruscotto, che lo inoltra a SAP.
  Future<SendResult> sendAvviso(NotificationAvviso avviso) async {
    final res =
        await ref.read(notificationRepositoryProvider).createAvviso(avviso);
    if (res.isSuccess) {
      await _store.removeAvviso(avviso.numeroAvviso);
      ref.invalidate(createdAvvisiProvider);
      return const SendResult(true, 'Avviso inviato al cruscotto');
    }
    return SendResult(false, _motivo(res.failureOrNull?.message));
  }

  /// Ora che l'OdL esiste sul backend, le foto/firme prese quando era ancora
  /// solo sul tablet possono partire. Non blocca il flusso e non fallisce.
  void _rimandaAllegati() {
    ref.read(syncProcessorProvider).process(force: true).catchError((_) => 0);
  }

  /// Traduce l'errore tecnico in un messaggio comprensibile all'operatore.
  String _motivo(String? errore) {
    final e = (errore ?? '').trim();
    if (e.contains('501')) {
      return 'Il cruscotto non accetta ancora la creazione dal campo. '
          'L\'elemento resta salvato sul tablet.';
    }
    // Messaggio chiaro dal backend (es. "Per un ordine SOST serve la
    // matricola…"): mostrarlo, così l'operatore sa cosa correggere.
    if (e.isNotEmpty && !e.startsWith('DioException') && !e.contains('Exception')) {
      return '$e L\'elemento resta salvato sul tablet.';
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
    var nonPassati = 0;
    String? primoNonPassato;

    for (final order in await _store.workOrders()) {
      final res = await woRepo.createWorkOrder(order);
      if (res.isSuccess) {
        await _store.removeWorkOrder(order.externalCode);
        ok++;
        final collega = order.assegnaA;
        if (collega != null) {
          final errore =
              await _passaAlCollega(res.valueOrNull ?? order, collega);
          if (errore != null) {
            nonPassati++;
            primoNonPassato ??= _nonPassato(collega, errore);
          }
        }
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
    if (ok > 0) _rimandaAllegati();
    return CreationSyncResult(
        ok: ok,
        failed: failed,
        firstError: firstError,
        nonPassati: nonPassati,
        primoNonPassato: primoNonPassato);
  }
}

final creationControllerProvider =
    Provider<CreationController>((ref) => CreationController(ref));
