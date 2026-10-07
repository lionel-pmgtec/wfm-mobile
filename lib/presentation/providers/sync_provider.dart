import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/sync_processor.dart';
import '../../domain/entities/entities.dart';
import 'avvisi_provider.dart';
import 'connectivity_provider.dart';
import 'core_providers.dart';
import 'work_orders_provider.dart';

final syncQueueProvider = FutureProvider<List<SyncOperation>>((ref) async {
  ref.watch(pendingSyncCountProvider); // refetch quando cambia la coda
  return ref.watch(syncRepositoryProvider).getQueue();
});

/// Processore della coda offline. Va "toccato" una volta (ref.read in app.dart)
/// perché il listener sul ritorno della connettività sia attivo.
final syncProcessorProvider = Provider<SyncProcessor>((ref) {
  final proc = SyncProcessor(
    ref.watch(syncRepositoryProvider),
    ref.watch(remoteDataSourceProvider),
    ref.watch(localDataSourceProvider),
  );

  // Al RITORNO della connessione (offline -> online) rigioca la coda e rinfresca
  // le liste: i cambi fatti offline vengono inviati automaticamente.
  ref.listen<bool>(connectivityStatusProvider, (prev, online) async {
    if (online == true && prev == false) {
      final synced = await proc.process(force: true);
      ref.invalidate(syncQueueProvider);
      if (synced > 0) {
        ref.invalidate(workOrdersProvider);
        ref.invalidate(dashboardStatsProvider);
        ref.invalidate(avvisiProvider);
        ref.invalidate(prontoInterventoAvvisiProvider);
      }
    }
  });

  // Al LOGIN (o alla ripresa della sessione salvata) si rigioca ciò che era
  // rimasto in coda o sul tablet: esiti, cambi di stato, allegati. Il
  // listener sulla rete sopra copre solo il passaggio offline → online, non
  // un'app riaperta già online con lavoro ancora da inviare.
  ref.listen<String?>(authTokenProvider, (prev, token) async {
    if (token != null && token.isNotEmpty && (prev == null || prev.isEmpty)) {
      if (ref.read(connectivityStatusProvider) != true) return;
      final synced = await proc.process(force: true);
      ref.invalidate(syncQueueProvider);
      if (synced > 0) {
        ref.invalidate(workOrdersProvider);
        ref.invalidate(dashboardStatsProvider);
        ref.invalidate(avvisiProvider);
        ref.invalidate(prontoInterventoAvvisiProvider);
      }
    }
  });

  return proc;
});

class SyncActions {
  final Ref ref;
  SyncActions(this.ref);

  /// Rigioca subito tutta la coda verso il server e rinfresca le liste.
  Future<int> runQueue() async {
    final synced = await ref.read(syncProcessorProvider).process(force: true);
    ref.invalidate(syncQueueProvider);
    if (synced > 0) {
      ref.invalidate(workOrdersProvider);
      ref.invalidate(dashboardStatsProvider);
      ref.invalidate(avvisiProvider);
      ref.invalidate(prontoInterventoAvvisiProvider);
    }
    return synced;
  }

  /// Pulsante "Riprova": sblocca gli item falliti e li reinvia subito.
  Future<void> retryAll() async {
    await ref.read(syncRepositoryProvider).retryAll();
    await runQueue();
  }

  Future<void> cancel(String id) async {
    await ref.read(syncRepositoryProvider).cancel(id);
    ref.invalidate(syncQueueProvider);
  }
}

final syncActionsProvider = Provider<SyncActions>((ref) => SyncActions(ref));
