import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/entities.dart';
import 'connectivity_provider.dart';
import 'core_providers.dart';

final syncQueueProvider = FutureProvider<List<SyncOperation>>((ref) async {
  ref.watch(pendingSyncCountProvider); // refetch quando cambia la coda
  return ref.watch(syncRepositoryProvider).getQueue();
});

class SyncActions {
  final Ref ref;
  SyncActions(this.ref);

  Future<void> retryAll() async {
    await ref.read(syncRepositoryProvider).retryAll();
    ref.invalidate(syncQueueProvider);
  }

  Future<void> cancel(String id) async {
    await ref.read(syncRepositoryProvider).cancel(id);
    ref.invalidate(syncQueueProvider);
  }
}

final syncActionsProvider = Provider<SyncActions>((ref) => SyncActions(ref));
