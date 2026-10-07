// Assegnare a un collega l'OdL che si sta creando.
//
// Il backend assegna SEMPRE l'OdL a chi lo crea (POST /work-orders ignora il
// CID del corpo). Quindi: il collega scelto si salva con l'OdL locale
// (`assegnaA`) e, appena il backend accetta l'OdL, l'app lo passa al collega
// con POST /work-orders/:id/reassign — dopo aver mandato le foto prese qui,
// che il backend accetta solo da chi ha l'OdL assegnato.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wfm_mobile/core/error/failures.dart';
import 'package:wfm_mobile/core/network/result.dart';
import 'package:wfm_mobile/core/services/sync_processor.dart';
import 'package:wfm_mobile/core/widgets/match_code_field.dart';
import 'package:wfm_mobile/data/datasources/local/local_data_source.dart';
import 'package:wfm_mobile/data/datasources/remote/remote_data_source.dart';
import 'package:wfm_mobile/data/local/local_creation_store.dart';
import 'package:wfm_mobile/data/models/mappers.dart';
import 'package:wfm_mobile/domain/entities/entities.dart';
import 'package:wfm_mobile/domain/repositories/auth_repository.dart';
import 'package:wfm_mobile/domain/repositories/sync_repository.dart';
import 'package:wfm_mobile/domain/repositories/work_order_repository.dart';
import 'package:wfm_mobile/presentation/providers/core_providers.dart';
import 'package:wfm_mobile/presentation/providers/creation_provider.dart';
import 'package:wfm_mobile/presentation/providers/reassign_provider.dart';
import 'package:wfm_mobile/presentation/providers/sync_provider.dart';
import 'package:wfm_mobile/presentation/providers/work_orders_provider.dart';
import 'package:wfm_mobile/presentation/widgets/assegnatario_field.dart';

/// Registro comune delle chiamate, per verificarne l'ordine.
final _log = <String>[];

class _Store implements LocalCreationStore {
  final ordini = <String, WorkOrder>{};

  @override
  Future<List<WorkOrder>> workOrders() async => ordini.values.toList();
  @override
  Future<WorkOrder?> workOrder(String code) async => ordini[code];
  @override
  Future<void> saveWorkOrder(WorkOrder o) async => ordini[o.externalCode] = o;
  @override
  Future<void> removeWorkOrder(String code) async => ordini.remove(code);
  @override
  Future<List<NotificationAvviso>> avvisi() async => const [];

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('$i');
}

class _Repo implements WorkOrderRepository {
  Failure? rifiutaPassaggio;

  @override
  Future<Result<WorkOrder>> createWorkOrder(WorkOrder order) async {
    _log.add('crea ${order.externalCode}');
    return Success(order);
  }

  @override
  Future<Result<void>> reassign(String code, String cid, {String? note}) async {
    _log.add('passa $code a $cid');
    final f = rifiutaPassaggio;
    return f == null ? const Success<void>(null) : Err(f);
  }

  @override
  Future<Result<List<WorkOrder>>> getWorkOrders(
          {WorkOrderFilter filter = const WorkOrderFilter()}) async =>
      const Success([]);

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('$i');
}

/// Il processore di sync: qui interessa solo che parta (foto) PRIMA del
/// passaggio al collega.
class _Sync extends SyncProcessor {
  _Sync() : super(_Nulla(), _NullaRemote(), InMemoryLocalDataSource());

  @override
  Future<int> process({bool force = false}) async {
    _log.add('allegati');
    return 0;
  }
}

class _Nulla implements SyncRepository {
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

class _NullaRemote implements WfmRemoteDataSource {
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

class _Auth implements AuthRepository {
  @override
  AppUser? get currentUser =>
      const AppUser(cid: 'TEC001', nome: 'Marco', cognome: 'Bianchi');

  @override
  dynamic noSuchMethod(Invocation i) => null;
}

WorkOrder _odl(String code, {String? assegnaA}) => WorkOrder(
      externalCode: code,
      woType: 'ZA02',
      woTypeDescription: 'Attività Ordinarie Potabile',
      cidAssegnato: 'TEC001',
      assegnaA: assegnaA,
    );

void main() {
  late _Store store;
  late _Repo repo;
  late ProviderContainer c;

  setUp(() {
    _log.clear();
    store = _Store();
    repo = _Repo();
    c = ProviderContainer(overrides: [
      localCreationStoreProvider.overrideWithValue(store),
      workOrderRepositoryProvider.overrideWithValue(repo),
      syncProcessorProvider.overrideWithValue(_Sync()),
    ]);
  });
  tearDown(() => c.dispose());

  group('invio di un OdL creato sul tablet', () {
    test('con un collega scelto: crea, manda le foto, poi lo passa', () async {
      final o = _odl('TMP-ODL-1', assegnaA: 'TEC002');
      await store.saveWorkOrder(o);

      final res = await c
          .read(creationControllerProvider)
          .sendWorkOrder(o);

      expect(res.ok, isTrue);
      expect(res.message, 'Ordine inviato al cruscotto e passato a TEC002');
      expect(_log, ['crea TMP-ODL-1', 'allegati', 'passa TMP-ODL-1 a TEC002']);
      expect(store.ordini, isEmpty);
    });

    test('senza collega: nessun passaggio (comportamento di prima)', () async {
      final o = _odl('TMP-ODL-2');
      await store.saveWorkOrder(o);

      final res = await c
          .read(creationControllerProvider)
          .sendWorkOrder(o);

      expect(res.message, 'Ordine inviato al cruscotto');
      expect(_log.where((l) => l.startsWith('passa')), isEmpty);
    });

    test('passaggio rifiutato: OdL inviato comunque, resta a chi lo crea',
        () async {
      repo.rifiutaPassaggio = const ServerFailure('Tecnico TEC999 inesistente.');
      final o = _odl('TMP-ODL-3', assegnaA: 'TEC999');
      await store.saveWorkOrder(o);

      final res = await c
          .read(creationControllerProvider)
          .sendWorkOrder(o);

      expect(res.ok, isTrue); // l'OdL è sul cruscotto
      expect(res.message, contains('non passato a TEC999'));
      expect(res.message, contains('Tecnico TEC999 inesistente.'));
      expect(res.message, contains('Resta assegnato a te'));
      expect(store.ordini, isEmpty);
    });

    test('"Invia tutto": conta gli OdL non passati al collega', () async {
      repo.rifiutaPassaggio = const ServerFailure('No.');
      await store.saveWorkOrder(_odl('TMP-ODL-4', assegnaA: 'TEC002'));
      await store.saveWorkOrder(_odl('TMP-ODL-5'));

      final res = await c.read(creationControllerProvider).syncAll();

      expect(res.ok, 2);
      expect(res.failed, 0);
      expect(res.nonPassati, 1);
      expect(res.primoNonPassato, contains('non passato a TEC002'));
    });
  });

  group('"Riassegna" su un OdL non ancora inviato', () {
    test('memorizza il collega: passerà all\'invio', () async {
      await store.saveWorkOrder(_odl('TMP-ODL-6'));

      final res = await c
          .read(workOrderActionsProvider)
          .reassign('TMP-ODL-6', 'TEC002');

      expect(res.valueOrNull, EsitoRiassegnazione.allInvio);
      expect(store.ordini['TMP-ODL-6']!.assegnaA, 'TEC002');
      expect(_log, isEmpty); // nessuna chiamata al backend
    });

    test('riscegliere chi l\'ha creato annulla il passaggio', () async {
      await store.saveWorkOrder(_odl('TMP-ODL-7', assegnaA: 'TEC002'));

      final res = await c
          .read(workOrderActionsProvider)
          .reassign('TMP-ODL-7', 'TEC001');

      expect(res.valueOrNull, EsitoRiassegnazione.resta);
      expect(store.ordini['TMP-ODL-7']!.assegnaA, isNull);
    });

    test('OdL già inviato: passaggio immediato come prima', () async {
      final res = await c
          .read(workOrderActionsProvider)
          .reassign('000050556444', 'TEC002');

      expect(res.valueOrNull, EsitoRiassegnazione.passato);
      expect(_log, ['passa 000050556444 a TEC002']);
    });
  });

  group('copia locale (outbox)', () {
    test('il collega scelto sopravvive al salvataggio/rilettura', () {
      final j = workOrderToJson(_odl('TMP-ODL-8', assegnaA: 'TEC002'));
      expect(workOrderFromJson(j).assegnaA, 'TEC002');
    });

    test('senza collega il campo non viene scritto', () {
      final j = workOrderToJson(_odl('TMP-ODL-9'));
      expect(j.containsKey('assegnaA'), isFalse);
      expect(workOrderFromJson(j).assegnaA, isNull);
    });
  });

  group('campo "Assegna a"', () {
    Future<List<String?>> apri(WidgetTester t) async {
      final scelte = <String?>[];
      String? valore;
      await t.pumpWidget(ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_Auth()),
          availableOperatorsProvider.overrideWith((ref) async => const [
                AppUser(cid: 'TEC001', nome: 'Marco', cognome: 'Bianchi'),
                AppUser(cid: 'TEC002', nome: 'Luca', cognome: 'Rossi'),
              ]),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (_, setState) => AssegnatarioField(
                value: valore,
                onChanged: (cid) => setState(() {
                  valore = cid;
                  scelte.add(cid);
                }),
              ),
            ),
          ),
        ),
      ));
      await t.pumpAndSettle();
      return scelte;
    }

    testWidgets('di default: io', (t) async {
      await apri(t);
      expect(find.text('TEC001 — Marco Bianchi (io)'), findsOneWidget);
    });

    testWidgets('scegliere un collega lo restituisce, tornare a "io" dà null',
        (t) async {
      final scelte = await apri(t);

      await t.tap(find.byType(MatchCodeField<String>));
      await t.pumpAndSettle();
      await t.tap(find.text('Luca Rossi'));
      await t.pumpAndSettle();
      expect(find.text('TEC002 — Luca Rossi'), findsOneWidget);

      await t.tap(find.byType(MatchCodeField<String>));
      await t.pumpAndSettle();
      await t.tap(find.text('Marco Bianchi (io)'));
      await t.pumpAndSettle();

      expect(scelte, ['TEC002', null]);
    });
  });
}
