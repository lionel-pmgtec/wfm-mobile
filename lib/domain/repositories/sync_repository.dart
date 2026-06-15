// Coda di sincronizzazione offline-first.
import '../entities/sync_operation.dart';

abstract interface class SyncRepository {
  /// Operazioni attualmente in coda.
  Future<List<SyncOperation>> getQueue();

  /// Numero di elementi non ancora sincronizzati (badge header, EF-M2.4).
  Future<int> pendingCount();

  /// Accoda una nuova operazione in uscita.
  Future<void> enqueue(SyncOperation operation);

  /// Forza un nuovo tentativo manuale di tutta la coda.
  Future<void> retryAll();

  /// Annulla un'operazione non riuscita.
  Future<void> cancel(String operationId);

  /// Stream del conteggio in attesa (per aggiornare l'UI in tempo reale).
  Stream<int> watchPendingCount();
}
