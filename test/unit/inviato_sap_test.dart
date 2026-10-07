// Oggetto già inviato a SAP dal pianificatore: il backend risponde 409
// `{ error, inviatoSap: true }` a status, note ed esito. Il tablet non deve
// ritentare, deve mostrare il messaggio e mettere l'OdL in sola lettura.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wfm_mobile/core/error/failures.dart';
import 'package:wfm_mobile/core/error/invio_sap.dart';
import 'package:wfm_mobile/core/network/connectivity_service.dart';
import 'package:wfm_mobile/core/network/result.dart';
import 'package:wfm_mobile/core/services/sync_processor.dart';
import 'package:wfm_mobile/data/datasources/local/local_data_source.dart';
import 'package:wfm_mobile/data/datasources/remote/remote_data_source.dart';
import 'package:wfm_mobile/data/models/mappers.dart';
import 'package:wfm_mobile/data/repositories/esito_repository_impl.dart';
import 'package:wfm_mobile/data/repositories/work_order_repository_impl.dart';
import 'package:wfm_mobile/domain/entities/entities.dart';
import 'package:wfm_mobile/domain/repositories/sync_repository.dart';

const _msg = "Ordine TMP-ODL-1 inviato a SAP: non si modifica piu'.";

DioException _http(int code, Map<String, dynamic> body) => DioException(
      requestOptions: RequestOptions(path: '/x'),
      response: Response(
          requestOptions: RequestOptions(path: '/x'),
          statusCode: code,
          data: body),
      type: DioExceptionType.badResponse,
    );

DioException _bloccato() => _http(409, {'error': _msg, 'inviatoSap': true});

/// Backend simulato: ogni scrittura fallisce con l'errore comandato.
class _Remote implements WfmRemoteDataSource {
  Object failWith;
  _Remote(this.failWith);

  @override
  Future<WorkOrder> updateStatus(String code, WorkOrderStatus status,
          {String? reason, String? note, Geolocation? geolocation}) async =>
      throw failWith;

  @override
  Future<WorkOrder> updateWorkOrder(WorkOrder order) async => throw failWith;

  @override
  Future<String> submitEsito(Esito esito) async => throw failWith;

  @override
  Future<void> reassignWorkOrder(String code, String technicianCid,
          {String? note}) async =>
      throw failWith;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

/// Backend che accetta il passaggio a un collega e registra la chiamata.
class _RemoteOk implements WfmRemoteDataSource {
  String? chiamata;

  @override
  Future<void> reassignWorkOrder(String code, String technicianCid,
          {String? note}) async =>
      chiamata = '$code -> $technicianCid ($note)';

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _Sync implements SyncRepository {
  final queue = <SyncOperation>[];
  final cancelled = <String>[];
  final updated = <SyncOperation>[];

  @override
  Future<void> enqueue(SyncOperation op) async => queue.add(op);

  @override
  Future<List<SyncOperation>> getQueue() async => List.of(queue);

  @override
  Future<void> cancel(String id) async {
    cancelled.add(id);
    queue.removeWhere((o) => o.id == id);
  }

  @override
  Future<void> update(SyncOperation op) async => updated.add(op);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

const _odl = WorkOrder(
  externalCode: 'TMP-ODL-1',
  woType: 'ZA02',
  woTypeDescription: 'Attività Ordinarie Potabile',
  status: WorkOrderStatus.ricevuto,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('riconoscimento del 409', () {
    test('409 con inviatoSap:true è "inviato a SAP"', () {
      expect(eInviatoSap(_bloccato()), isTrue);
    });

    test('altri errori no (409 senza flag, 404, 422)', () {
      expect(eInviatoSap(_http(409, {'error': 'chiuso'})), isFalse);
      expect(eInviatoSap(_http(404, {'error': 'x'})), isFalse);
      expect(eInviatoSap(_http(422, {'error': 'x', 'inviatoSap': true})),
          isFalse);
    });

    test('il messaggio è quello del backend', () {
      expect(inviatoSapFailure(_bloccato()).message, _msg);
    });
  });

  group('work order dal backend', () {
    test('inviatoSap:true -> sola lettura e non annullabile', () {
      final o = workOrderFromJson({
        'externalCode': 'TMP-ODL-1',
        'woType': 'ZA02',
        'status': 'RICEVUTO',
        'inviatoSap': true,
      });
      expect(o.inviatoSap, isTrue);
      expect(o.isClosed, isTrue);
      expect(o.canCancel, isFalse);
    });

    test('senza flag resta modificabile', () {
      final o = workOrderFromJson({
        'externalCode': 'TMP-ODL-1',
        'woType': 'ZA02',
        'status': 'RICEVUTO',
      });
      expect(o.inviatoSap, isFalse);
      expect(o.isClosed, isFalse);
    });

    test('contatoreFermo non esiste più: né letto né rimandato', () {
      final o = workOrderFromJson({
        'externalCode': '1',
        'woType': 'SOST',
        'status': 'RICEVUTO',
        'contatoreFermo': true,
      });
      expect(workOrderToJson(o).containsKey('contatoreFermo'), isFalse);
    });
  });

  group('repository OdL', () {
    late InMemoryLocalDataSource local;
    late _Sync sync;

    setUp(() async {
      local = InMemoryLocalDataSource();
      sync = _Sync();
      await local.upsertWorkOrder(_odl);
    });

    test('cambio stato su OdL inviato a SAP: errore chiaro, niente coda',
        () async {
      final repo = WorkOrderRepositoryImpl(
          _Remote(_bloccato()), local, ConnectivityService(), sync);
      final res = await repo.updateStatus(
          'TMP-ODL-1', WorkOrderStatus.inEsecuzione);

      expect(res, isA<Err>());
      final f = (res as Err).failure;
      expect(f, isA<InviatoSapFailure>());
      expect(f.message, _msg);
      expect(sync.queue, isEmpty);
      expect(local.cachedWorkOrder('TMP-ODL-1')!.isClosed, isTrue);
    });

    test('nota su OdL inviato a SAP: errore chiaro, niente coda', () async {
      final repo = WorkOrderRepositoryImpl(
          _Remote(_bloccato()), local, ConnectivityService(), sync);
      final res = await repo.updateWorkOrder(_odl.copyWith(notes: 'x'));

      expect((res as Err).failure, isA<InviatoSapFailure>());
      expect(sync.queue, isEmpty);
      expect(local.cachedWorkOrder('TMP-ODL-1')!.inviatoSap, isTrue);
    });
  });

  group('passaggio a un collega (reassign)', () {
    late InMemoryLocalDataSource local;

    setUp(() async {
      local = InMemoryLocalDataSource();
      await local.upsertWorkOrder(_odl);
    });

    WorkOrderRepositoryImpl repo(WfmRemoteDataSource r) =>
        WorkOrderRepositoryImpl(r, local, ConnectivityService(), _Sync());

    test('200: l\'OdL sparisce dal tablet e si manda CID + nota', () async {
      final r = _RemoteOk();
      final res =
          await repo(r).reassign('TMP-ODL-1', 'TEC002', note: 'ferie');

      expect(res, isA<Success>());
      expect(r.chiamata, 'TMP-ODL-1 -> TEC002 (ferie)');
      expect(local.cachedWorkOrder('TMP-ODL-1'), isNull);
    });

    test('422 "tecnico inesistente": messaggio del backend, OdL resta',
        () async {
      final res = await repo(_Remote(
              _http(422, {'error': 'Tecnico ZZZ999 inesistente.'})))
          .reassign('TMP-ODL-1', 'ZZZ999');

      expect((res as Err).failure.message, 'Tecnico ZZZ999 inesistente.');
      expect(local.cachedWorkOrder('TMP-ODL-1'), isNotNull);
    });

    test('409 inviato a SAP: errore dedicato e OdL in sola lettura', () async {
      final res =
          await repo(_Remote(_bloccato())).reassign('TMP-ODL-1', 'TEC002');

      expect((res as Err).failure, isA<InviatoSapFailure>());
      expect(local.cachedWorkOrder('TMP-ODL-1')!.isClosed, isTrue);
    });

    test('senza rete: errore chiaro, niente coda', () async {
      final res = await repo(_Remote(DioException(
              requestOptions: RequestOptions(path: '/x'),
              type: DioExceptionType.connectionError)))
          .reassign('TMP-ODL-1', 'TEC002');

      expect((res as Err).failure, isA<NetworkFailure>());
      expect(local.cachedWorkOrder('TMP-ODL-1'), isNotNull);
    });
  });

  group('repository esito', () {
    test('esito su OdL inviato a SAP: errore, NON accodato', () async {
      final local = InMemoryLocalDataSource();
      await local.upsertWorkOrder(_odl);
      final sync = _Sync();
      final repo = EsitoRepositoryImpl(
          _Remote(_bloccato()), local, ConnectivityService(), sync);

      final res = await repo.submitEsito(Esito(
          workOrderCode: 'TMP-ODL-1',
          technicianCid: 'TEC001',
          startDateTime: DateTime(2026, 9, 29, 9),
          result: EsitoResult.success));

      expect((res as Err).failure, isA<InviatoSapFailure>());
      expect(sync.queue, isEmpty);
    });

    test('errore di rete: l\'esito resta accodato come prima', () async {
      final sync = _Sync();
      final repo = EsitoRepositoryImpl(
          _Remote(DioException(
              requestOptions: RequestOptions(path: '/esiti'),
              type: DioExceptionType.connectionError)),
          InMemoryLocalDataSource(),
          ConnectivityService(),
          sync);

      final res = await repo.submitEsito(Esito(
          workOrderCode: 'TMP-ODL-1',
          technicianCid: 'TEC001',
          startDateTime: DateTime(2026, 9, 29, 9),
          result: EsitoResult.success));

      expect(res, isA<Success>());
      expect(sync.queue, hasLength(1));
    });
  });

  group('coda di sincronizzazione', () {
    SyncOperation op(String id) => SyncOperation(
          id: id,
          type: SyncOperationType.updateStatus,
          entityId: 'TMP-ODL-1',
          payload: const {'status': 'inEsecuzione'},
          createdAt: DateTime(2026, 9, 29),
        );

    test('409 inviato a SAP: tolta dalla coda, mai ritentata', () async {
      final local = InMemoryLocalDataSource();
      await local.upsertWorkOrder(_odl);
      final sync = _Sync()..queue.add(op('op-1'));
      final proc = SyncProcessor(sync, _Remote(_bloccato()), local);

      await proc.process(force: true);

      expect(sync.cancelled, ['op-1']);
      expect(sync.updated, isEmpty); // non marcata "da ritentare"
      expect(local.cachedWorkOrder('TMP-ODL-1')!.isClosed, isTrue);
    });

    test('un altro errore del server resta in coda da ritentare', () async {
      final sync = _Sync()..queue.add(op('op-2'));
      final proc = SyncProcessor(
          sync, _Remote(_http(500, {'error': 'x'})), InMemoryLocalDataSource());

      await proc.process(force: true);

      expect(sync.cancelled, isEmpty);
      expect(sync.updated.single.status, SyncStatus.failed);
    });
  });
}
