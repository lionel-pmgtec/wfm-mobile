// Sorgente dati locale (cache offline-first).
//
// [InMemoryLocalDataSource]: volatile (test / cache OdL).
// [PersistentLocalDataSource]: come sopra, ma allegati in attesa, bozze esito e
// coda di sincronizzazione sopravvivono al riavvio dell'app (Hive): ciò che è
// stato fatto offline parte comunque appena torna la connessione.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../../../domain/entities/entities.dart';
import '../../models/local_json.dart';

abstract interface class WfmLocalDataSource {
  // Cache OdL
  Future<void> cacheWorkOrders(List<WorkOrder> orders);
  List<WorkOrder> cachedWorkOrders();
  /// Svuota la cache OdL (cambio tecnico: nessuna eredità tra CID diversi).
  Future<void> clearWorkOrders();
  WorkOrder? cachedWorkOrder(String code);
  Future<void> upsertWorkOrder(WorkOrder order);
  Future<void> deleteWorkOrder(String code);

  // Bozze esito
  Esito? esitoDraft(String workOrderCode);
  Future<void> saveEsitoDraft(Esito esito);

  // Allegati
  List<Attachment> attachments(String workOrderCode);
  /// Allegati salvati solo sul tablet, ancora da inviare al backend.
  List<Attachment> pendingAttachments();
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
    // RIMPIAZZA (non fondere): la lista del server è autoritativa e filtrata
    // per CID. Fondendo soltanto, gli OdL di un tecnico restavano in cache dopo
    // il logout e comparivano al tecnico successivo. Gli OdL creati sul campo
    // (TMP) vivono in un altro store, quindi qui si può azzerare senza perderli.
    _orders
      ..clear()
      ..addEntries(orders.map((o) => MapEntry(o.externalCode, o)));
  }

  @override
  List<WorkOrder> cachedWorkOrders() => _orders.values.toList();

  @override
  Future<void> clearWorkOrders() async => _orders.clear();

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
  List<Attachment> pendingAttachments() => [
        for (final list in _attachments.values)
          ...list.where((a) => a.uploadStatus == UploadStatus.local)
      ];

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

/// Come [InMemoryLocalDataSource], ma con scrittura su Hive di ciò che NON deve
/// andare perso se l'app si chiude prima dell'invio:
///  - allegati ancora locali (foto/documenti): metadati + COPIA del file in una
///    cartella dell'app (la cache temporanea può essere svuotata dal sistema);
///  - bozze di esito;
///  - coda di sincronizzazione.
/// Gli allegati già inviati non si salvano: li rilegge il backend.
class PersistentLocalDataSource extends InMemoryLocalDataSource {
  PersistentLocalDataSource._(
      this._attBox, this._draftBox, this._queueBox, this._filesDir);

  final Box<String> _attBox;
  final Box<String> _draftBox;
  final Box<String> _queueBox;

  /// Cartella dove si conservano i file degli allegati in attesa. Null sul web
  /// (nessun file system: il blob del browser non sopravvive comunque al reload).
  final Directory? _filesDir;

  /// Apre i box e ricarica lo stato salvato. [hivePath]/[filesDir] servono ai
  /// test; in app si usano le cartelle di Flutter.
  static Future<PersistentLocalDataSource> open(
      {String? hivePath, Directory? filesDir}) async {
    if (hivePath == null) {
      await Hive.initFlutter();
    } else {
      Hive.init(hivePath);
    }
    final att = await Hive.openBox<String>('local_attachments');
    final drafts = await Hive.openBox<String>('local_esito_drafts');
    final queue = await Hive.openBox<String>('local_sync_queue');

    Directory? dir = filesDir;
    if (dir == null && !kIsWeb) {
      final docs = await getApplicationDocumentsDirectory();
      dir = Directory('${docs.path}/allegati');
    }
    if (dir != null && !dir.existsSync()) dir.createSync(recursive: true);

    final ds = PersistentLocalDataSource._(att, drafts, queue, dir);
    ds._load();
    return ds;
  }

  void _load() {
    // Un record illeggibile non deve bloccare l'avvio: si salta.
    for (final s in _attBox.values) {
      try {
        final a = attachmentFromLocalJson(jsonDecode(s) as Map<String, dynamic>);
        _attachments.putIfAbsent(a.workOrderCode, () => []).add(a);
      } catch (_) {}
    }
    for (final s in _draftBox.values) {
      try {
        final e = esitoFromLocalJson(jsonDecode(s) as Map<String, dynamic>);
        _drafts[e.workOrderCode] = e;
      } catch (_) {}
    }
    final ops = <SyncOperation>[];
    for (final s in _queueBox.values) {
      try {
        final o = syncOperationFromJson(jsonDecode(s) as Map<String, dynamic>);
        if (o != null) ops.add(o);
      } catch (_) {}
    }
    ops.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    _queue.addAll(ops);
  }

  String _enc(Object o) => jsonEncode(o, toEncodable: (x) => x.toString());

  /// Copia il file dell'allegato nella cartella dell'app e ne restituisce la
  /// versione col nuovo percorso. Se non si può copiare, resta com'è.
  Future<Attachment> _keepFile(Attachment a) async {
    final dir = _filesDir;
    if (dir == null || a.filePath.isEmpty) return a;
    try {
      if (a.filePath.startsWith(dir.path)) return a;
      final src = File(a.filePath);
      if (!src.existsSync()) return a;
      final safe = a.fileName.replaceAll(RegExp(r'[\/:*?"<>|]'), '_');
      final dest = File('${dir.path}/${a.id}_$safe');
      await src.copy(dest.path);
      return a.copyWith(filePath: dest.path);
    } catch (_) {
      return a;
    }
  }

  @override
  Future<void> addAttachment(Attachment attachment) async {
    if (attachment.uploadStatus == UploadStatus.local) {
      final kept = await _keepFile(attachment);
      await super.addAttachment(kept);
      await _attBox.put(kept.id, _enc(attachmentToLocalJson(kept)));
    } else {
      await super.addAttachment(attachment);
      await _attBox.delete(attachment.id);
    }
  }

  @override
  Future<void> removeAttachment(String id) async {
    await super.removeAttachment(id);
    await _attBox.delete(id);
  }

  @override
  Future<void> saveEsitoDraft(Esito esito) async {
    await super.saveEsitoDraft(esito);
    await _draftBox.put(esito.workOrderCode, _enc(esitoToLocalJson(esito)));
  }

  @override
  Future<void> enqueue(SyncOperation op) async {
    await super.enqueue(op);
    await _queueBox.put(op.id, _enc(syncOperationToJson(op)));
  }

  @override
  Future<void> removeFromQueue(String id) async {
    await super.removeFromQueue(id);
    await _queueBox.delete(id);
  }

  @override
  Future<void> updateQueueItem(SyncOperation op) async {
    await super.updateQueueItem(op);
    if (_queueBox.containsKey(op.id)) {
      await _queueBox.put(op.id, _enc(syncOperationToJson(op)));
    }
  }
}
