import '../../core/error/failures.dart';
import '../../core/network/connectivity_service.dart';
import '../../core/network/result.dart';
import '../../domain/entities/entities.dart';
import '../../domain/repositories/esito_repository.dart';
import '../../domain/repositories/sync_repository.dart';
import '../datasources/local/local_data_source.dart';
import '../datasources/remote/remote_data_source.dart';

class EsitoRepositoryImpl implements EsitoRepository {
  final WfmRemoteDataSource remote;
  final WfmLocalDataSource local;
  final ConnectivityService connectivity;
  final SyncRepository sync;

  EsitoRepositoryImpl(this.remote, this.local, this.connectivity, this.sync);

  @override
  Future<Esito?> getDraft(String workOrderCode) async =>
      local.esitoDraft(workOrderCode);

  @override
  Future<void> saveDraft(Esito esito) async => local.saveEsitoDraft(esito);

  @override
  Future<Result<String>> submitEsito(Esito esito) async {
    // Validazione locale minima (EF-M5.4).
    if (esito.result == null) {
      return const Err(ValidationFailure('Selezionare un esito'));
    }
    // Offline: accodamento con upload differito.
    if (!connectivity.isOnline) {
      await sync.enqueue(SyncOperation(
        id: 'esito-${esito.workOrderCode}-${DateTime.now().millisecondsSinceEpoch}',
        type: SyncOperationType.submitEsito,
        entityId: esito.workOrderCode,
        createdAt: DateTime.now(),
      ));
      await local.saveEsitoDraft(
          esito.copyWith(localStatus: LocalSyncStatus.pendingUpload));
      return const Success('PENDING');
    }
    try {
      final id = await remote.submitEsito(esito);
      await local.saveEsitoDraft(esito.copyWith(localStatus: LocalSyncStatus.synced));
      return Success(id);
    } catch (e) {
      // Errore di rete -> accoda comunque (offline-first).
      await sync.enqueue(SyncOperation(
        id: 'esito-${esito.workOrderCode}-${DateTime.now().millisecondsSinceEpoch}',
        type: SyncOperationType.submitEsito,
        entityId: esito.workOrderCode,
        createdAt: DateTime.now(),
        lastError: e.toString(),
      ));
      return const Success('PENDING');
    }
  }
}
