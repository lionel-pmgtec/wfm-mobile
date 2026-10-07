// Ciò che il tecnico elimina sul tablet si elimina SOLO sul tablet.
//
// Il backend non cancella né ordini né avvisi (DELETE risponde 501): il tablet
// non lo chiama, ricorda cosa è stato eliminato e non lo mostra più, anche
// dopo un aggiornamento o un riavvio. Sul cruscotto l'ordine resta.

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wfm_mobile/core/error/failures.dart';
import 'package:wfm_mobile/core/network/connectivity_service.dart';
import 'package:wfm_mobile/core/network/result.dart';
import 'package:wfm_mobile/core/services/avvisi_rimossi_store.dart';
import 'package:wfm_mobile/core/services/odl_rimossi_store.dart';
import 'package:wfm_mobile/data/datasources/local/local_data_source.dart';
import 'package:wfm_mobile/data/datasources/remote/remote_data_source.dart';
import 'package:wfm_mobile/data/local/local_creation_store.dart';
import 'package:wfm_mobile/data/repositories/work_order_repository_impl.dart';
import 'package:wfm_mobile/domain/entities/entities.dart';
import 'package:wfm_mobile/domain/repositories/sync_repository.dart';
import 'package:wfm_mobile/domain/repositories/work_order_repository.dart';
import 'package:wfm_mobile/presentation/providers/avvisi_provider.dart';
import 'package:wfm_mobile/presentation/providers/connectivity_provider.dart';
import 'package:wfm_mobile/presentation/providers/core_providers.dart';
import 'package:wfm_mobile/presentation/providers/creation_provider.dart';
import 'package:wfm_mobile/presentation/providers/work_orders_provider.dart';

final _log = <String>[];

WorkOrder _odl(String code, {String? avviso}) =>
    WorkOrder(externalCode: code, woType: 'ZA02', avvisoOrigine: avviso);

NotificationAvviso _avv(String n) => NotificationAvviso(
    numeroAvviso: n, descrizione: 'x', tipo: 'ZH', priorita: '1');

class _Rete implements ConnectivityService {
  final bool _online;
  _Rete(this._online);
  @override
  bool get isOnline => _online;
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

class _Sync implements SyncRepository {
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('$i');
}

/// Backend finto: elenca gli ordini e RIFIUTA ogni cancellazione (501).
class _Remote implements WfmRemoteDataSource {
  final List<WorkOrder> ordini;
  _Remote(this.ordini);

  @override
  Future<List<WorkOrder>> getWorkOrders(WorkOrderFilter filter) async => ordini;

  /// Avvisi che il backend elenca (anche quelli già eliminati sul tablet).
  List<NotificationAvviso> avvisiBackend = const [];

  @override
  Future<List<NotificationAvviso>> getAvvisi({String? query}) async =>
      avvisiBackend;

  @override
  Future<void> deleteWorkOrder(String code) async {
    _log.add('BACKEND delete OdL $code');
    throw StateError('501');
  }

  @override
  Future<void> deleteAvviso(String n) async {
    _log.add('BACKEND delete avviso $n');
    throw StateError('501');
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('$i');
}

class _Store implements LocalCreationStore {
  final odlLocali = <String, WorkOrder>{};
  final avvisiLocali = <String, NotificationAvviso>{};

  @override
  Future<List<WorkOrder>> workOrders() async => odlLocali.values.toList();
  @override
  Future<List<NotificationAvviso>> avvisi() async =>
      avvisiLocali.values.toList();
  @override
  Future<void> removeWorkOrder(String c) async {
    _log.add('rimuovi OdL locale $c');
    odlLocali.remove(c);
  }

  @override
  Future<void> removeAvviso(String n) async {
    _log.add('rimuovi avviso locale $n');
    avvisiLocali.remove(n);
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('$i');
}

class _Online extends StateNotifier<bool> implements ConnectivityNotifier {
  _Online() : super(true);
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _log.clear();
    OdlRimossiStore.resetForTests();
    AvvisiRimossiStore.resetForTests();
  });

  group("repository degli OdL (cache e backend finti)", () {
    WorkOrderRepositoryImpl repo(List<WorkOrder> sulBackend,
        {bool online = true, InMemoryLocalDataSource? local}) {
      return WorkOrderRepositoryImpl(_Remote(sulBackend),
          local ?? InMemoryLocalDataSource(), _Rete(online), _Sync());
    }

    Future<List<String>> codici(WorkOrderRepository r) async =>
        (await r.getWorkOrders()).valueOrNull!.map((o) => o.externalCode).toList();

    test("elimina: l'OdL sparisce e il backend non viene chiamato", () async {
      final r = repo([_odl('A'), _odl('B'), _odl('C')]);
      expect(await codici(r), ['A', 'B', 'C']);

      final res = await r.deleteWorkOrder('B');
      expect(res.isSuccess, isTrue);
      expect(_log, isEmpty); // nessuna chiamata al backend
      expect(await codici(r), ['A', 'C']);
      // E anche agli aggiornamenti successivi (il backend lo elenca ancora).
      expect(await codici(r), ['A', 'C']);
    });

    test('anche senza rete: la cache non lo mostra più', () async {
      final local = InMemoryLocalDataSource();
      final online = repo([_odl('A'), _odl('B')], local: local);
      await codici(online); // riempie la cache
      await online.deleteWorkOrder('A');

      final offline = repo(const [], online: false, local: local);
      expect(await codici(offline), ['B']);
    });

    test('le statistiche non contano l\'OdL eliminato', () async {
      final r = repo([_odl('A'), _odl('B')]);
      await r.deleteWorkOrder('A');
      final stats = (await r.getStats()).valueOrNull!;
      expect(stats[WorkOrderStatus.ricevuto], 1);
    });

    test("l'eliminazione resta dopo il riavvio", () async {
      final dir = await Directory.systemTemp.createTemp('odl_rimossi_test');
      addTearDown(() async {
        try {
          await dir.delete(recursive: true);
        } catch (_) {}
      });
      await OdlRimossiStore.open(hivePath: dir.path);
      await repo([_odl('A')]).deleteWorkOrder('A');

      OdlRimossiStore.resetForTests();
      expect(OdlRimossiStore.contiene('A'), isFalse);
      await OdlRimossiStore.open(hivePath: dir.path);
      expect(OdlRimossiStore.contiene('A'), isTrue);
      expect(await codici(repo([_odl('A'), _odl('B')])), ['B']);
    });
  });

  group('azioni', () {
    late _Store store;

    ProviderContainer contenitore(List<WorkOrder> odl) {
      store = _Store();
      final remote = _Remote(odl);
      final c = ProviderContainer(overrides: [
        remoteDataSourceProvider.overrideWithValue(remote),
        localDataSourceProvider.overrideWithValue(InMemoryLocalDataSource()),
        connectivityProvider.overrideWithValue(_Rete(true)),
        syncRepositoryProvider.overrideWithValue(_Sync()),
        localCreationStoreProvider.overrideWithValue(store),
        connectivityStatusProvider.overrideWith((ref) => _Online()),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    test("avviso del cruscotto: eliminato sul tablet, senza il backend",
        () async {
      final c = contenitore(const []);
      final r = await c.read(deleteAvvisoProvider)('000400090003');
      expect(r.isSuccess, isTrue);
      expect(_log, isEmpty);
      expect(AvvisiRimossiStore.contiene('400090003'), isTrue);
    });

    test("avviso nato sul tablet: eliminato dall'archivio locale", () async {
      final c = contenitore(const []);
      store.avvisiLocali['TMP-AVV-1'] = _avv('TMP-AVV-1');
      final r = await c.read(deleteAvvisoProvider)('TMP-AVV-1');
      expect(r.isSuccess, isTrue);
      expect(_log, ['rimuovi avviso locale TMP-AVV-1']);
    });

    test("la bannière Pronto Intervento della Home si aggiorna e non lo mostra",
        () async {
      final c = contenitore(const []);
      final remote = c.read(remoteDataSourceProvider) as _Remote;
      remote.avvisiBackend = [
        NotificationAvviso(
            numeroAvviso: '000400090003',
            descrizione: 'Tombino ostruito',
            tipo: 'ZF',
            priorita: '1',
            stato: 'RICEVUTO'),
      ];
      final prima = await c.read(prontoInterventoAvvisiProvider.future);
      expect(prima, hasLength(1)); // c'è, come nella schermata Home

      await c.read(deleteAvvisoProvider)('000400090003');
      final dopo = await c.read(prontoInterventoAvvisiProvider.future);
      expect(dopo, isEmpty);
      expect(_log, isEmpty); // e senza il backend
    });

    test('un avviso eliminato sul tablet non si apre più', () async {
      final c = contenitore(const []);
      await c.read(deleteAvvisoProvider)('400090003');
      await expectLater(c.read(avvisoDetailProvider('400090003').future),
          throwsA(isA<NonTrovatoFailure>()));
      expect(_log, isEmpty);
    });

    test('OdL del cruscotto con avviso: eliminati entrambi, senza backend',
        () async {
      final c = contenitore([_odl('5001', avviso: '4001')]);
      final e =
          await c.read(workOrderActionsProvider).eliminaConAvviso('5001');
      expect(e.odl.isSuccess, isTrue);
      expect(e.avvisoEliminato, isTrue);
      expect(_log, isEmpty);
      expect(OdlRimossiStore.contiene('5001'), isTrue);
      expect(AvvisiRimossiStore.contiene('4001'), isTrue);
    });

    test("OdL nato sul tablet e non inviato: si toglie dall'archivio locale",
        () async {
      final c = contenitore(const []);
      store.odlLocali['TMP-ODL-9'] = _odl('TMP-ODL-9', avviso: 'TMP-AVV-9');
      store.avvisiLocali['TMP-AVV-9'] = _avv('TMP-AVV-9');
      final e =
          await c.read(workOrderActionsProvider).eliminaConAvviso('TMP-ODL-9');
      expect(e.odl.isSuccess, isTrue);
      expect(_log, [
        'rimuovi OdL locale TMP-ODL-9',
        'rimuovi avviso locale TMP-AVV-9',
      ]);
      expect(OdlRimossiStore.contiene('TMP-ODL-9'), isFalse);
    });
  });
}
