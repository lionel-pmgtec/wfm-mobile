// Sincronizzazione periodica in background via workmanager.
// Esegue ogni 15 minuti il retry della coda di sincronizzazione offline.
//
// NOTA: il callback di Workmanager gira in un isolato separato — non ha
// accesso ai Provider Riverpod del processo principale. Per ora ci limitiamo
// a un log e a un'eventuale rinegoziazione del token (placeholder). Quando il
// middleware sarà disponibile, qui andrà istanziato un client HTTP minimo che
// rilegge la coda persistente (Hive) e ritenta gli upload.

import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

const _kSyncTaskName = 'wfm.sync.retry';
const _kSyncUniqueName = 'wfm.sync.retry.periodic';

class BackgroundSyncService {
  BackgroundSyncService._();
  static final BackgroundSyncService instance = BackgroundSyncService._();

  bool _initialized = false;

  /// Inizializza Workmanager e registra il task periodico (15 min).
  Future<void> initialize({Duration frequency = const Duration(minutes: 15)}) async {
    if (kIsWeb || _initialized) return;
    _initialized = true;

    await Workmanager().initialize(
      backgroundCallback,
      isInDebugMode: kDebugMode,
    );

    // Android: 15 min è il minimo consentito da WorkManager.
    await Workmanager().registerPeriodicTask(
      _kSyncUniqueName,
      _kSyncTaskName,
      frequency: frequency,
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
      ),
      existingWorkPolicy: ExistingWorkPolicy.keep,
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(minutes: 1),
    );
  }

  /// Annulla il task periodico (es. al logout).
  Future<void> cancel() async {
    if (kIsWeb || !_initialized) return;
    await Workmanager().cancelByUniqueName(_kSyncUniqueName);
  }
}

// ─── Callback eseguito nell'isolato di Workmanager ────────────────────────
//
// Deve essere top-level + annotato per essere registrato da Flutter Engine.
@pragma('vm:entry-point')
void backgroundCallback() {
  Workmanager().executeTask((task, inputData) async {
    if (task != _kSyncTaskName) return Future.value(true);

    // TODO: quando il middleware sarà collegato, eseguire qui:
    //  1. Apertura DB locale (Hive) read-only sulla syncQueue
    //  2. POST/PUT verso il middleware con token salvato in secure storage
    //  3. Rimozione dalla coda in caso di successo
    //
    // Per l'MVP attuale (mock + InMemoryLocalDataSource), il callback non
    // condivide stato con il processo principale — quindi è un no-op.
    if (kDebugMode) {
      // ignore: avoid_print
      print('[wfm-sync] periodic retry tick (no-op in mock mode)');
    }
    return Future.value(true);
  });
}
