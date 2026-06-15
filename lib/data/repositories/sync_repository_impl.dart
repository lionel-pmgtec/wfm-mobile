import 'dart:async';
import '../../domain/entities/entities.dart';
import '../../domain/repositories/sync_repository.dart';
import '../datasources/local/local_data_source.dart';

class SyncRepositoryImpl implements SyncRepository {
  final WfmLocalDataSource local;
  final _pendingController = StreamController<int>.broadcast();

  SyncRepositoryImpl(this.local);

  void _emit() => _pendingController.add(
      local.syncQueue().where((o) => o.status != SyncStatus.success).length);

  @override
  Future<List<SyncOperation>> getQueue() async => local.syncQueue();

  @override
  Future<int> pendingCount() async =>
      local.syncQueue().where((o) => o.status != SyncStatus.success).length;

  @override
  Future<void> enqueue(SyncOperation operation) async {
    await local.enqueue(operation);
    _emit();
  }

  @override
  Future<void> retryAll() async {
    for (final op in local.syncQueue()) {
      if (op.status == SyncStatus.failed || op.status == SyncStatus.pending) {
        await local.updateQueueItem(op.copyWith(
            status: SyncStatus.pending, retryCount: op.retryCount + 1));
      }
    }
    _emit();
  }

  @override
  Future<void> cancel(String operationId) async {
    await local.removeFromQueue(operationId);
    _emit();
  }

  @override
  Stream<int> watchPendingCount() => _pendingController.stream;
}
