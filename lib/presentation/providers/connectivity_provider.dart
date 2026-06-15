import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core_providers.dart';

/// Stato online/offline osservabile dalla UI. Espone toggle() per testare
/// la modalità offline dall'app (specifiche M11).
class ConnectivityNotifier extends StateNotifier<bool> {
  final Ref ref;
  ConnectivityNotifier(this.ref) : super(true) {
    final service = ref.read(connectivityProvider);
    state = service.isOnline;
    final sub = service.onStatusChange.listen((v) => state = v);
    ref.onDispose(sub.cancel);
  }

  void toggle() {
    ref.read(connectivityProvider).toggle();
  }

  void setOnline(bool value) => ref.read(connectivityProvider).setOnline(value);
}

final connectivityStatusProvider =
    StateNotifierProvider<ConnectivityNotifier, bool>(
        (ref) => ConnectivityNotifier(ref));

/// Conteggio operazioni in coda di sincronizzazione (badge header).
final pendingSyncCountProvider = StreamProvider<int>((ref) async* {
  final repo = ref.watch(syncRepositoryProvider);
  yield await repo.pendingCount();
  yield* repo.watchPendingCount();
});
