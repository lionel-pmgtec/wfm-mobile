// La chiusura di un OdL (invio dell'esito) fa sparire l'OdL dal tablet e,
// insieme, l'avviso associato.
//
// Il backend continua a elencare l'avviso (non si può eliminare: 501), quindi
// il tablet lo ricorda come rimosso e non lo mostra più, nemmeno dopo un
// aggiornamento o un riavvio.

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wfm_mobile/core/error/failures.dart';
import 'package:wfm_mobile/core/network/result.dart';
import 'package:wfm_mobile/core/services/avvisi_rimossi_store.dart';
import 'package:wfm_mobile/data/datasources/remote/remote_data_source.dart';
import 'package:wfm_mobile/data/local/local_creation_store.dart';
import 'package:wfm_mobile/data/repositories/notification_repository_impl.dart';
import 'package:wfm_mobile/domain/entities/entities.dart';
import 'package:wfm_mobile/domain/repositories/esito_repository.dart';
import 'package:wfm_mobile/domain/repositories/notification_repository.dart';
import 'package:wfm_mobile/domain/repositories/work_order_repository.dart';
import 'package:wfm_mobile/presentation/providers/connectivity_provider.dart';
import 'package:wfm_mobile/presentation/providers/core_providers.dart';
import 'package:wfm_mobile/presentation/providers/creation_provider.dart';
import 'package:wfm_mobile/presentation/providers/esito_provider.dart';
import 'package:wfm_mobile/presentation/providers/work_orders_provider.dart';

final _log = <String>[];

/// Il registro senza le riletture degli elenchi dal backend (la Home si
/// aggiorna): contano solo le azioni.
List<String> _senzaLetture() =>
    _log.where((l) => !l.startsWith('REMOTO')).toList();

/// Rete sempre presente: niente controllo reale della connettività.
class _Online extends StateNotifier<bool> implements ConnectivityNotifier {
  _Online() : super(true);
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

WorkOrder _odl(String code, {String? avviso}) => WorkOrder(
    externalCode: code, woType: 'ZA02', avvisoOrigine: avviso);

NotificationAvviso _avv(String n) => NotificationAvviso(
    numeroAvviso: n, descrizione: 'x', tipo: 'ZH', priorita: '1');

Esito _esito(String code) => Esito(
    workOrderCode: code,
    technicianCid: 'TEC001',
    startDateTime: DateTime(2026, 10, 1, 8),
    result: EsitoResult.success);

class _RepoEsito implements EsitoRepository {
  String risposta = 'ESI-1';
  Failure? rifiuta;

  @override
  Future<Result<String>> submitEsito(Esito e) async {
    _log.add('esito ${e.workOrderCode}');
    final f = rifiuta;
    return f == null ? Success(risposta) : Err(f);
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('$i');
}

class _RepoOdl implements WorkOrderRepository {
  @override
  Future<Result<WorkOrder>> updateStatus(String code, WorkOrderStatus s,
      {String? reason, String? note, Geolocation? geolocation}) async {
    _log.add('stato $code ${s.name}');
    return Success(_odl(code).copyWith(status: s));
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('$i');
}

class _Store implements LocalCreationStore {
  final avvisiLocali = <String, NotificationAvviso>{};

  @override
  Future<List<WorkOrder>> workOrders() async => const [];
  @override
  Future<List<NotificationAvviso>> avvisi() async =>
      avvisiLocali.values.toList();
  @override
  Future<void> removeAvviso(String n) async {
    _log.add('rimuovi avviso locale $n');
    avvisiLocali.remove(n);
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('$i');
}

class _Spia implements WfmRemoteDataSource {
  @override
  dynamic noSuchMethod(Invocation i) {
    _log.add('REMOTO ${i.memberName}');
    throw UnimplementedError('$i');
  }
}

class _Remote implements WfmRemoteDataSource {
  final List<NotificationAvviso> avvisi;
  _Remote(this.avvisi);

  @override
  Future<List<NotificationAvviso>> getAvvisi({String? query}) async => avvisi;

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('$i');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _RepoEsito repoEsito;
  late _Store store;

  setUp(() {
    _log.clear();
    AvvisiRimossiStore.resetForTests();
    repoEsito = _RepoEsito();
    store = _Store();
  });

  ProviderContainer contenitore(List<WorkOrder> odl) {
    final c = ProviderContainer(overrides: [
      esitoRepositoryProvider.overrideWithValue(repoEsito),
      workOrderRepositoryProvider.overrideWithValue(_RepoOdl()),
      localCreationStoreProvider.overrideWithValue(store),
      connectivityStatusProvider.overrideWith((ref) => _Online()),
      remoteDataSourceProvider.overrideWithValue(_Spia()),
      workOrdersProvider.overrideWith((ref) async => odl),
      workOrderDetailProvider.overrideWith(
          (ref, code) async => odl.firstWhere((o) => o.externalCode == code)),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  test("chiudere l'OdL toglie anche il suo avviso", () async {
    final c = contenitore([_odl('5001', avviso: '4001')]);
    final r = await c.read(esitoControllerProvider).submit(_esito('5001'));
    expect(r.isSuccess, isTrue);
    expect(AvvisiRimossiStore.contiene('4001'), isTrue);
    expect(_senzaLetture(), ['esito 5001', 'stato 5001 completato']);
  });

  test('esito in coda offline (PENDING): l\'avviso sparisce comunque',
      () async {
    repoEsito.risposta = 'PENDING';
    final c = contenitore([_odl('5001', avviso: '4001')]);
    await c.read(esitoControllerProvider).submit(_esito('5001'));
    expect(AvvisiRimossiStore.contiene('4001'), isTrue);
  });

  test("esito rifiutato: né l'OdL né l'avviso vengono toccati", () async {
    repoEsito.rifiuta = const ValidationFailure('Selezionare un esito');
    final c = contenitore([_odl('5001', avviso: '4001')]);
    final r = await c.read(esitoControllerProvider).submit(_esito('5001'));
    expect(r.isSuccess, isFalse);
    expect(AvvisiRimossiStore.contiene('4001'), isFalse);
    expect(_senzaLetture(), ["esito 5001"]);
  });

  test("OdL senza avviso: la chiusura è quella di sempre", () async {
    final c = contenitore([_odl('5001')]);
    final r = await c.read(esitoControllerProvider).submit(_esito('5001'));
    expect(r.isSuccess, isTrue);
    expect(_senzaLetture(), ['esito 5001', 'stato 5001 completato']);
  });

  test("un altro OdL aperto usa lo stesso avviso: l'avviso resta", () async {
    final c = contenitore([
      _odl('5001', avviso: '4001'),
      _odl('5002', avviso: '4001'),
    ]);
    await c.read(esitoControllerProvider).submit(_esito('5001'));
    expect(AvvisiRimossiStore.contiene('4001'), isFalse);
  });

  test('avviso nato sul tablet e non inviato: si toglie dall\'archivio locale',
      () async {
    store.avvisiLocali['TMP-AVV-1'] = _avv('TMP-AVV-1');
    final c = contenitore([_odl('TMP-ODL-9', avviso: 'TMP-AVV-1')]);
    await c.read(esitoControllerProvider).submit(_esito('TMP-ODL-9'));
    expect(_log, contains('rimuovi avviso locale TMP-AVV-1'));
    expect(AvvisiRimossiStore.contiene('TMP-AVV-1'), isFalse);
  });

  group("l'elenco degli avvisi", () {
    test('non contiene più gli avvisi rimossi (anche con gli zeri davanti)',
        () async {
      await AvvisiRimossiStore.rimuovi('000400090003');
      final repo = NotificationRepositoryImpl(
          _Remote([_avv('400090003'), _avv('400090004'), _avv('000400090003')]));
      final r = await repo.getAvvisi();
      expect(r.valueOrNull!.map((a) => a.numeroAvviso), ['400090004']);
    });

    test('senza avvisi rimossi: tutti', () async {
      final repo = NotificationRepositoryImpl(
          _Remote([_avv('1'), _avv('2')]));
      expect((await repo.getAvvisi()).valueOrNull, hasLength(2));
    });
  });

  test('gli avvisi rimossi restano tali dopo il riavvio', () async {
    final dir = await Directory.systemTemp.createTemp('avvisi_rimossi_test');
    addTearDown(() async {
      try {
        await dir.delete(recursive: true);
      } catch (_) {}
    });
    await AvvisiRimossiStore.open(hivePath: dir.path);
    await AvvisiRimossiStore.rimuovi('4001');

    AvvisiRimossiStore.resetForTests();
    expect(AvvisiRimossiStore.contiene('4001'), isFalse); // memoria vuota
    await AvvisiRimossiStore.open(hivePath: dir.path);
    expect(AvvisiRimossiStore.contiene('4001'), isTrue);
  });

  test('NotificationRepository: contratto invariato', () {
    expect(NotificationRepositoryImpl(_Remote(const [])),
        isA<NotificationRepository>());
  });
}
