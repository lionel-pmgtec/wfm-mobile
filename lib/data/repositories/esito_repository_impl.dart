import 'package:dio/dio.dart';

import '../../core/error/failures.dart';
import '../../core/error/invio_sap.dart';
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
    } on DioException catch (e) {
      // Già inviato a SAP dal pianificatore: il backend non accetterà mai
      // questo esito. Accodarlo lo farebbe ritentare all'infinito.
      if (eInviatoSap(e)) {
        final c = local.cachedWorkOrder(esito.workOrderCode);
        if (c != null) await local.upsertWorkOrder(c.copyWith(inviatoSap: true));
        return Err(inviatoSapFailure(e));
      }
      return _accoda(esito);
    } catch (_) {
      return _accoda(esito);
    }
  }

  /// Errore di rete -> accoda comunque (offline-first). Nessun messaggio
  /// grezzo: l'operazione è semplicemente "in attesa" finché torna la rete.
  Future<Result<String>> _accoda(Esito esito) async {
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
}
