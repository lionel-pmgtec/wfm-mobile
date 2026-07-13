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
