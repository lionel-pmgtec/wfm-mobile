// Sorgente dati locale (cache offline-first). Implementazione in memoria,
// pronta a essere sostituita con Hive crittografato (specifiche §9.2 / §11.2).

import '../../../domain/entities/entities.dart';

abstract interface class WfmLocalDataSource {
  // Cache OdL
  Future<void> cacheWorkOrders(List<WorkOrder> orders);
  List<WorkOrder> cachedWorkOrders();
  WorkOrder? cachedWorkOrder(String code);
  Future<void> upsertWorkOrder(WorkOrder order);
  Future<void> deleteWorkOrder(String code);

  // Bozze esito
  Esito? esitoDraft(String workOrderCode);
  Future<void> saveEsitoDraft(Esito esito);

  // Allegati
  List<Attachment> attachments(String workOrderCode);
  Future<void> addAttachment(Attachment attachment);
  Future<void> removeAttachment(String id);

  // Coda di sincronizzazione
  List<SyncOperation> syncQueue();
  Future<void> enqueue(SyncOperation op);
  Future<void> removeFromQueue(String id);
  Future<void> updateQueueItem(SyncOperation op);
}

/// Implementazione volatile in memoria (sufficiente per il front-end / test).
class InMemoryLocalDataSource implements WfmLocalDataSource {
  final Map<String, WorkOrder> _orders = {};
  final Map<String, Esito> _drafts = {};
  final Map<String, List<Attachment>> _attachments = {};
  final List<SyncOperation> _queue = [];

  @override
  Future<void> cacheWorkOrders(List<WorkOrder> orders) async {
    for (final o in orders) {
      _orders[o.externalCode] = o;
    }
  }

  @override
  List<WorkOrder> cachedWorkOrders() => _orders.values.toList();

  @override
  WorkOrder? cachedWorkOrder(String code) => _orders[code];

  @override
  Future<void> upsertWorkOrder(WorkOrder order) async {
    _orders[order.externalCode] = order;
  }

  @override
  Future<void> deleteWorkOrder(String code) async {
    _orders.remove(code);
  }

  @override
  Esito? esitoDraft(String workOrderCode) => _drafts[workOrderCode];

  @override
  Future<void> saveEsitoDraft(Esito esito) async {
    _drafts[esito.workOrderCode] = esito;
  }

  @override
  List<Attachment> attachments(String workOrderCode) =>
      List.of(_attachments[workOrderCode] ?? const []);

  @override
  Future<void> addAttachment(Attachment attachment) async {
    _attachments.putIfAbsent(attachment.workOrderCode, () => []).add(attachment);
  }

  @override
  Future<void> removeAttachment(String id) async {
    for (final list in _attachments.values) {
      list.removeWhere((a) => a.id == id);
    }
  }

  @override
  List<SyncOperation> syncQueue() => List.of(_queue);

  @override
  Future<void> enqueue(SyncOperation op) async => _queue.add(op);

  @override
  Future<void> removeFromQueue(String id) async =>
      _queue.removeWhere((o) => o.id == id);

  @override
  Future<void> updateQueueItem(SyncOperation op) async {
    final i = _queue.indexWhere((o) => o.id == op.id);
    if (i >= 0) _queue[i] = op;
  }
}
