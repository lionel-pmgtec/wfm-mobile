// Allegati offline: restano sul tablet finché manca la connessione (o finché
// l'OdL non esiste sul backend) e partono appena si può, insieme al resto.

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wfm_mobile/core/services/sync_processor.dart';
import 'package:wfm_mobile/data/datasources/local/local_data_source.dart';
import 'package:wfm_mobile/data/datasources/remote/remote_data_source.dart';
import 'package:wfm_mobile/domain/entities/entities.dart';
import 'package:wfm_mobile/domain/repositories/sync_repository.dart';

/// Backend simulato: risponde solo a `uploadAttachment`, con esito comandato.
class _FakeRemote implements WfmRemoteDataSource {
  Object? failWith; // se valorizzato, l'upload lancia questo errore
  final uploaded = <String>[];

  @override
  Future<Attachment> uploadAttachment(Attachment a) async {
    if (failWith != null) throw failWith!;
    uploaded.add('${a.workOrderCode}/${a.type.sapCode}/${a.fileName}');
    return a.copyWith(id: 'srv-${a.id}', uploadStatus: UploadStatus.uploaded);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

/// Coda vuota: qui interessano solo gli allegati.
class _EmptySync implements SyncRepository {
  @override
  Future<List<SyncOperation>> getQueue() async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

DioException _noNetwork() => DioException(
      requestOptions: RequestOptions(path: '/esiti/attachments'),
      type: DioExceptionType.connectionError,
      error: const SocketException('offline'),
    );

DioException _http404() => DioException(
      requestOptions: RequestOptions(path: '/esiti/attachments'),
      response: Response(
          requestOptions: RequestOptions(path: '/esiti/attachments'),
          statusCode: 404),
      type: DioExceptionType.badResponse,
    );

void main() {
  late InMemoryLocalDataSource local;
  late _FakeRemote remote;
  late SyncProcessor proc;

  Attachment att(String id, String type) => Attachment(
        id: id,
        workOrderCode: 'TMP-ODL-1',
        type: type == 'firma' ? AttachmentType.firma : AttachmentType.fotoDopo,
        filePath: '/x/$id.jpg',
        fileName: '$id.jpg',
        capturedAt: DateTime(2026, 9, 24),
        author: 'TEC001',
      );

  setUp(() async {
    local = InMemoryLocalDataSource();
    remote = _FakeRemote();
    proc = SyncProcessor(_EmptySync(), remote, local);
    await local.addAttachment(att('a1', 'foto'));
    await local.addAttachment(att('a2', 'foto'));
  });

  test('senza rete gli allegati restano locali e nessuno va perso', () async {
    remote.failWith = _noNetwork();
    await proc.process(force: true);
    expect(local.pendingAttachments(), hasLength(2));
    expect(remote.uploaded, isEmpty);
  });

  test('quando la rete torna partono tutti, col codice del Cruscotto', () async {
    remote.failWith = _noNetwork();
    await proc.process(force: true); // offline
    remote.failWith = null; // torna la connessione
    final sent = await proc.process(force: true);

    expect(sent, 2);
    expect(local.pendingAttachments(), isEmpty);
    expect(remote.uploaded,
        ['TMP-ODL-1/FOTO_DOPO/a1.jpg', 'TMP-ODL-1/FOTO_DOPO/a2.jpg']);
    // La copia locale ora è quella inviata, con l'id assegnato dal backend.
    final ids = local.attachments('TMP-ODL-1').map((a) => a.id).toSet();
    expect(ids, {'srv-a1', 'srv-a2'});
  });

  test('OdL creato sul tablet non ancora inviato (404): riprova dopo', () async {
    remote.failWith = _http404(); // il backend non conosce ancora l'OdL
    await proc.process(force: true);
    expect(local.pendingAttachments(), hasLength(2));

    remote.failWith = null; // l'OdL è stato sincronizzato
    await proc.process(force: true);
    expect(local.pendingAttachments(), isEmpty);
  });

  test('un allegato che fallisce non blocca gli altri', () async {
    var n = 0;
    final flaky = _FlakyRemote(() => n++ == 0); // il primo fallisce
    proc = SyncProcessor(_EmptySync(), flaky, local);
    await proc.process(force: true);
    expect(local.pendingAttachments(), hasLength(1));
    expect(flaky.uploaded, hasLength(1));
  });
}

class _FlakyRemote extends _FakeRemote {
  _FlakyRemote(this.shouldFail);
  final bool Function() shouldFail;

  @override
  Future<Attachment> uploadAttachment(Attachment a) async {
    if (shouldFail()) throw _noNetwork();
    return super.uploadAttachment(a);
  }
}
