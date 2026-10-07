// Ciò che è stato fatto offline deve sopravvivere al riavvio dell'app:
// allegati in attesa (con il loro file), bozze esito e coda di sincronizzazione.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:wfm_mobile/data/datasources/local/local_data_source.dart';
import 'package:wfm_mobile/domain/entities/entities.dart';

void main() {
  late Directory tmp;
  late Directory files;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('wfm_persist_');
    files = Directory('${tmp.path}/allegati')..createSync();
  });

  tearDown(() async {
    await Hive.close();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  Future<PersistentLocalDataSource> open() =>
      PersistentLocalDataSource.open(hivePath: '${tmp.path}/hive', filesDir: files);

  /// Simula la chiusura dell'app: si chiude Hive e si riapre da zero.
  Future<PersistentLocalDataSource> restart() async {
    await Hive.close();
    return open();
  }

  Attachment pending(String id, String path,
          {UploadStatus status = UploadStatus.local}) =>
      Attachment(
        id: id,
        workOrderCode: 'TMP-ODL-1',
        type: AttachmentType.fotoDopo,
        filePath: path,
        fileName: 'foto_$id.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 3,
        capturedAt: DateTime(2026, 9, 24, 10, 30),
        author: 'TEC001',
        uploadStatus: status,
      );

  test('un allegato non inviato sopravvive al riavvio, con il suo file', () async {
    // File "scattato" in una cartella temporanea del sistema (può essere pulita).
    final cache = File('${tmp.path}/cache_foto.jpg')..writeAsBytesSync([1, 2, 3]);

    var ds = await open();
    await ds.addAttachment(pending('a1', cache.path));
    cache.deleteSync(); // il sistema svuota la cache: la copia dell'app resta

    ds = await restart();
    final list = ds.attachments('TMP-ODL-1');
    expect(list, hasLength(1));
    expect(list.first.uploadStatus, UploadStatus.local);
    expect(list.first.type, AttachmentType.fotoDopo);
    expect(list.first.author, 'TEC001');
    expect(list.first.filePath.startsWith(files.path), isTrue);
    expect(File(list.first.filePath).readAsBytesSync(), [1, 2, 3]);
    expect(ds.pendingAttachments(), hasLength(1));
  });

  test('un allegato già inviato NON si salva (lo rilegge il backend)', () async {
    var ds = await open();
    await ds.addAttachment(pending('a2', '/x.jpg', status: UploadStatus.uploaded));
    ds = await restart();
    expect(ds.attachments('TMP-ODL-1'), isEmpty);
  });

  test('dopo l\'invio l\'allegato esce dal salvataggio locale', () async {
    final f = File('${tmp.path}/f.jpg')..writeAsBytesSync([9]);
    var ds = await open();
    await ds.addAttachment(pending('a3', f.path));
    // Come fa il repository dopo un upload riuscito.
    await ds.removeAttachment('a3');
    await ds.addAttachment(pending('srv-1', f.path, status: UploadStatus.uploaded));
    ds = await restart();
    expect(ds.pendingAttachments(), isEmpty);
  });

  test('bozza di esito e coda di sync sopravvivono al riavvio', () async {
    var ds = await open();
    await ds.saveEsitoDraft(Esito(
      workOrderCode: 'TMP-ODL-1',
      technicianCid: 'TEC001',
      startDateTime: DateTime(2026, 9, 24, 9),
      endDateTime: DateTime(2026, 9, 24, 9, 45),
      result: EsitoResult.success,
      causeCode: 'C002',
      notes: 'Contatore sostituito',
      meterReadings: [
        MeterReading(
          matricola: '000000000090000004',
          readingValue: 6120,
          readingDateTime: DateTime(2026, 9, 24, 9, 20),
        ),
      ],
      hoursWorked: const [
        HoursWorked(operation: '0020', description: 'Trasferimento', hours: 0.5),
      ],
      objects: const [EsitoObject(equipment: 'CR812EP', description: '159_Fiat')],
      newMeterSerial: '12345678',
      newMeterManufacturer: 'ABB',
      newMeterInstallReading: 0,
      newMeterInstallDate: DateTime(2026, 9, 24),
    ));
    await ds.enqueue(SyncOperation(
      id: 'op-1',
      type: SyncOperationType.submitEsito,
      entityId: 'TMP-ODL-1',
      createdAt: DateTime(2026, 9, 24, 9, 46),
    ));
    await ds.enqueue(SyncOperation(
      id: 'op-2',
      type: SyncOperationType.updateStatus,
      entityId: 'TMP-ODL-1',
      payload: {'status': 'COMPLETATO', 'note': null},
      status: SyncStatus.inProgress,
      retryCount: 2,
      createdAt: DateTime(2026, 9, 24, 9, 47),
    ));

    ds = await restart();

    final e = ds.esitoDraft('TMP-ODL-1')!;
    expect(e.result, EsitoResult.success);
    expect(e.causeCode, 'C002');
    expect(e.notes, 'Contatore sostituito');
    expect(e.meterReadings.single.readingValue, 6120);
    expect(e.hoursWorked.single.operation, '0020');
    expect(e.objects.single.equipment, 'CR812EP');
    expect(e.newMeterSerial, '12345678');
    expect(e.newMeterInstallDate, DateTime(2026, 9, 24));

    final q = ds.syncQueue();
    expect(q.map((o) => o.id), ['op-1', 'op-2']); // ordine di creazione
    expect(q[1].payload['status'], 'COMPLETATO');
    expect(q[1].retryCount, 2);
    // Un'operazione rimasta "in corso" quando l'app si è chiusa va ritentata.
    expect(q[1].status, SyncStatus.pending);
  });

  test('una voce eliminata dalla coda non torna al riavvio', () async {
    var ds = await open();
    await ds.enqueue(SyncOperation(
        id: 'op-x',
        type: SyncOperationType.submitEsito,
        entityId: 'X',
        createdAt: DateTime(2026, 9, 24)));
    await ds.removeFromQueue('op-x');
    ds = await restart();
    expect(ds.syncQueue(), isEmpty);
  });
}
