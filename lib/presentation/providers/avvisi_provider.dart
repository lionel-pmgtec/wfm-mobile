import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/error/failures.dart';
import '../../core/network/result.dart';
import '../../core/services/arrival_store.dart';
import '../../core/services/avvisi_rimossi_store.dart';
import '../../domain/entities/entities.dart';
import 'core_providers.dart';
import 'creation_provider.dart';
import 'work_orders_provider.dart';

final avvisiQueryProvider = StateProvider<String>((ref) => '');

/// Avvisi di Pronto Intervento (tipo ZH…), per il bandeau della Home: così
/// l'operatore li vede subito senza entrare nella sezione Avvisi. Legge dal
/// repository (non da [avvisiProvider]) per non dipendere dalla ricerca.
final prontoInterventoAvvisiProvider =
    FutureProvider<List<NotificationAvviso>>((ref) async {
  final repo = ref.watch(notificationRepositoryProvider);
  final res = await repo.getAvvisi();
  final all = switch (res) {
    Success(value: final v) => v,
    Err() => const <NotificationAvviso>[],
  };
  // Avvisi da cui è già stato generato un OdL sul campo (avvisoOrigine): sono
  // "presi in carico", quindi NON devono più lampeggiare in Home.
  final creati = await _avvisiConOdlGenerato(ref);
  // Solo i PI non ancora presi in carico (stato RICEVUTO e senza OdL generato).
  return all
      .where((a) =>
          !AvvisiRimossiStore.contiene(a.numeroAvviso) &&
          a.isProntoIntervento &&
          a.stato.trim().toUpperCase() == 'RICEVUTO' &&
          !creati.contains(a.numeroAvviso))
      .toList();
});

/// Numeri degli avvisi da cui è già stato generato un OdL (via `avvisoOrigine`).
Future<Set<String>> _avvisiConOdlGenerato(Ref ref) async {
  try {
    final creati = await ref.watch(createdWorkOrdersProvider.future);
    return creati
        .map((o) => o.avvisoOrigine)
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .toSet();
  } catch (_) {
    return const <String>{};
  }
}

/// Modalità "Elabora" (edit inline) per un singolo avviso (numero).
/// Attivata/disattivata dalla matita nell'AppBar del dettaglio Avviso.
/// autoDispose: si azzera automaticamente quando si lascia il dettaglio.
final avvisoEditModeProvider =
    StateProvider.autoDispose.family<bool, String>((ref, _) => false);

final avvisiProvider = FutureProvider<List<NotificationAvviso>>((ref) async {
  final query = ref.watch(avvisiQueryProvider);

  // Avvisi creati sul tablet (local-first), filtrati come i remoti e in cima.
  // Se la lettura locale fallisce non si perde l'elenco del cruscotto.
  var locali = <NotificationAvviso>[];
  try {
    locali = await ref.watch(createdAvvisiProvider.future);
  } catch (_) {
    locali = const [];
  }
  if (query.trim().isNotEmpty) {
    final needle = query.toLowerCase();
    locali = locali
        .where((a) =>
            a.numeroAvviso.toLowerCase().contains(needle) ||
            a.descrizione.toLowerCase().contains(needle))
        .toList();
  }

  final repo = ref.watch(notificationRepositoryProvider);
  try {
    final res = await repo.getAvvisi(query: query.isEmpty ? null : query);
    final remote = res.when(
      success: (l) => l,
      failure: (f) => throw Exception(f.message),
    );
    // Novità in cima: si annota l'arrivo sul tablet e si ordina dal più recente.
    // Solo sull'elenco completo (senza ricerca), per lo stesso motivo degli OdL.
    if (query.trim().isEmpty) {
      await ArrivalStore.seen('avv', remote.map((a) => a.numeroAvviso));
    }
    return ArrivalStore.sortNewestFirst(
        [...locali, ...remote], 'avv', (a) => a.numeroAvviso);
  } catch (_) {
    if (locali.isNotEmpty) {
      return ArrivalStore.sortNewestFirst(
          locali, 'avv', (a) => a.numeroAvviso);
    }
    rethrow;
  }
});

/// OdL presente sul tablet generato da questo avviso (`avvisoOrigine`).
///
/// Per gli OdL nati sul tablet il backend NON scrive il numero dell'OdL
/// sull'avviso (`ordineDiLavoro` resta vuoto): il collegamento si legge
/// dall'OdL, che porta il numero dell'avviso. Stesso avviso con o senza zeri
/// davanti.
final ordineCollegatoProvider =
    FutureProvider.family<WorkOrder?, String>((ref, numero) async {
  final k = AvvisiRimossiStore.chiave(numero);
  if (k.isEmpty) return null;
  try {
    final ordini = await ref.watch(workOrdersProvider.future);
    for (final o in ordini) {
      for (final v in [o.avvisoOrigine, o.notificationNumberSap]) {
        if (v != null && AvvisiRimossiStore.chiave(v) == k) return o;
      }
    }
  } catch (_) {/* elenco OdL non disponibile: nessun collegamento */}
  return null;
});

final avvisoDetailProvider =
    FutureProvider.family<NotificationAvviso, String>((ref, numero) async {
  // Eliminato su questo tablet (anche se il backend lo ha ancora): non si apre.
  if (AvvisiRimossiStore.contiene(numero)) {
    throw const NonTrovatoFailure('Questo avviso è stato eliminato.');
  }
  // Prima gli avvisi creati sul tablet (id TMP): non esistono lato cruscotto.
  try {
    final locali = await ref.watch(createdAvvisiProvider.future);
    for (final a in locali) {
      if (a.numeroAvviso == numero) return a;
    }
  } catch (_) {
    // Lettura locale non riuscita: si prosegue col cruscotto.
  }
  final repo = ref.watch(notificationRepositoryProvider);
  final res = await repo.getAvvisoDetail(numero);
  return res.when(
    success: (a) => a,
    failure: (f) => throw Exception(f.message),
  );
});

/// Azione: generazione OdL da avviso (EF-M9.3).
final generateWorkOrderProvider =
    Provider<Future<Result<WorkOrder>> Function(String)>((ref) {
  return (numero) async {
    final repo = ref.read(notificationRepositoryProvider);
    final res = await repo.generateWorkOrder(numero);
    if (res.isSuccess) ref.invalidate(avvisiProvider);
    return res;
  };
});

/// Toglie un avviso dal tablet perché il suo OdL è stato chiuso (o eliminato).
///
/// Avviso nato sul tablet e non ancora inviato: si elimina dall'archivio
/// locale. Avviso del cruscotto: il backend non lo elimina (501), quindi il
/// tablet lo ricorda come rimosso e non lo mostra più (AvvisiRimossiStore).
final rimuoviAvvisoDalTabletProvider =
    Provider<Future<void> Function(String)>((ref) {
  return (numero) async {
    final pending = await ref.read(isPendingCreationProvider(numero).future);
    if (pending) {
      await ref.read(creationControllerProvider).removeAvviso(numero);
    } else {
      await AvvisiRimossiStore.rimuovi(numero);
    }
    ref.invalidate(avvisiProvider);
    // Anche la bannière "Pronto intervento" della Home: legge dal repository
    // e tiene la propria copia dell'elenco.
    ref.invalidate(prontoInterventoAvvisiProvider);
  };
});

/// Azione: eliminazione di un avviso. Vale SOLO per questo tablet: il backend
/// non cancella gli avvisi (501) e non viene chiamato.
final deleteAvvisoProvider =
    Provider<Future<Result<void>> Function(String)>((ref) {
  return (numero) async {
    try {
      await ref.read(rimuoviAvvisoDalTabletProvider)(numero);
      return const Success<void>(null);
    } catch (e) {
      return Err(CacheFailure(e.toString()));
    }
  };
});
