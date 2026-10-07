// Eliminare un OdL elimina anche l'avviso a cui è associato.
//
// - l'avviso si elimina solo se l'OdL è stato eliminato;
// - se l'avviso non si riesce a eliminare, l'OdL resta eliminato e l'esito dice
//   perché (non si rimette in piedi un OdL già cancellato);
// - un avviso nato sul tablet e non ancora inviato si toglie dall'archivio
//   locale, senza chiamare il backend;
// - se un altro OdL è ancora associato allo stesso avviso, l'avviso resta;
// - l'OdL senza avviso si elimina come prima.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wfm_mobile/core/error/failures.dart';
import 'package:wfm_mobile/core/network/result.dart';
import 'package:wfm_mobile/core/services/avvisi_rimossi_store.dart';
import 'package:wfm_mobile/data/local/local_creation_store.dart';
import 'package:wfm_mobile/domain/entities/entities.dart';
import 'package:wfm_mobile/domain/repositories/notification_repository.dart';
import 'package:wfm_mobile/domain/repositories/work_order_repository.dart';
import 'package:wfm_mobile/presentation/features/work_orders/widgets/elimina_odl.dart';
import 'package:wfm_mobile/presentation/providers/core_providers.dart';
import 'package:wfm_mobile/presentation/providers/creation_provider.dart';
import 'package:wfm_mobile/presentation/providers/work_orders_provider.dart';

final _log = <String>[];

WorkOrder _odl(String code, {String? avviso, String? sap}) => WorkOrder(
    externalCode: code,
    woType: 'ZA02',
    avvisoOrigine: avviso,
    notificationNumberSap: sap);

class _RepoOdl implements WorkOrderRepository {
  Failure? rifiuta;

  @override
  Future<Result<void>> deleteWorkOrder(String code) async {
    _log.add('elimina OdL $code');
    final f = rifiuta;
    return f == null ? const Success<void>(null) : Err(f);
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('$i');
}

class _RepoAvvisi implements NotificationRepository {
  Failure? rifiuta;

  @override
  Future<Result<void>> deleteAvviso(String numero) async {
    _log.add('elimina avviso $numero');
    final f = rifiuta;
    return f == null ? const Success<void>(null) : Err(f);
  }

  @override
  Future<Result<List<NotificationAvviso>>> getAvvisi({String? query}) async =>
      const Success([]);

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

void main() {
  late _RepoOdl repoOdl;
  late _RepoAvvisi repoAvvisi;
  late _Store store;

  setUp(() {
    _log.clear();
    AvvisiRimossiStore.resetForTests();
    repoOdl = _RepoOdl();
    repoAvvisi = _RepoAvvisi();
    store = _Store();
  });

  /// [odl] = gli OdL che il tablet conosce.
  ProviderContainer contenitore(List<WorkOrder> odl) {
    final c = ProviderContainer(overrides: [
      workOrderRepositoryProvider.overrideWithValue(repoOdl),
      notificationRepositoryProvider.overrideWithValue(repoAvvisi),
      localCreationStoreProvider.overrideWithValue(store),
      workOrdersProvider.overrideWith((ref) async => odl),
      workOrderDetailProvider.overrideWith(
          (ref, code) async => odl.firstWhere((o) => o.externalCode == code)),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  test("OdL con avviso: si eliminano entrambi, prima l'OdL", () async {
    final c = contenitore([_odl('5001', avviso: '4001')]);
    final e = await c.read(workOrderActionsProvider).eliminaConAvviso('5001');
    expect(e.odl.isSuccess, isTrue);
    expect(e.avviso, '4001');
    expect(e.avvisoEliminato, isTrue);
    // Il backend non elimina gli avvisi (501): il tablet lo toglie dall'elenco.
    expect(_log, ['elimina OdL 5001']);
    expect(AvvisiRimossiStore.contiene('4001'), isTrue);
  });

  test("l'avviso si trova anche da notificationNumberSAP", () async {
    final c = contenitore([_odl('5001', sap: '4002')]);
    final e = await c.read(workOrderActionsProvider).eliminaConAvviso('5001');
    expect(e.avviso, '4002');
    expect(AvvisiRimossiStore.contiene('4002'), isTrue);
  });

  test('OdL senza avviso: come prima, nessuna chiamata sugli avvisi', () async {
    final c = contenitore([_odl('5001')]);
    final e = await c.read(workOrderActionsProvider).eliminaConAvviso('5001');
    expect(e.odl.isSuccess, isTrue);
    expect(e.avviso, isNull);
    expect(_log, ['elimina OdL 5001']);
    expect(AvvisiRimossiStore.contiene('4001'), isFalse);
  });

  test("OdL non eliminato: l'avviso resta", () async {
    repoOdl.rifiuta = const ServerFailure('non disponibile');
    final c = contenitore([_odl('5001', avviso: '4001')]);
    final e = await c.read(workOrderActionsProvider).eliminaConAvviso('5001');
    expect(e.odl.isSuccess, isFalse);
    expect(e.avviso, isNull);
    expect(_log, ['elimina OdL 5001']);
    expect(AvvisiRimossiStore.contiene('4001'), isFalse);
  });

  test("avviso nato sul tablet e non inviato: si toglie dall'archivio locale",
      () async {
    store.avvisiLocali['TMP-AVV-1'] = const NotificationAvviso(
        numeroAvviso: 'TMP-AVV-1', descrizione: 'x', tipo: 'ZH', priorita: '1');
    final c = contenitore([_odl('TMP-ODL-9', avviso: 'TMP-AVV-1')]);
    final e =
        await c.read(workOrderActionsProvider).eliminaConAvviso('TMP-ODL-9');
    expect(e.avvisoEliminato, isTrue);
    expect(_log, ['elimina OdL TMP-ODL-9', 'rimuovi avviso locale TMP-AVV-1']);
  });

  test("un altro OdL usa ancora lo stesso avviso: l'avviso resta", () async {
    final c = contenitore([
      _odl('5001', avviso: '4001'),
      _odl('5002', avviso: '4001'),
    ]);
    final azioni = c.read(workOrderActionsProvider);
    expect(await azioni.avvisoDaEliminare('5001'), isNull);
    final e = await azioni.eliminaConAvviso('5001');
    expect(e.avviso, isNull);
    expect(_log, ['elimina OdL 5001']);
  });

  test("delete() (usato dagli altri flussi) elimina anche l'avviso", () async {
    final c = contenitore([_odl('5001', avviso: '4001')]);
    final r = await c.read(workOrderActionsProvider).delete('5001');
    expect(r.isSuccess, isTrue);
    expect(_log, ['elimina OdL 5001']);
    expect(AvvisiRimossiStore.contiene('4001'), isTrue);
  });

  group('testi', () {
    test("la conferma nomina l'avviso che verrà eliminato", () {
      expect(messaggioEliminazioneOdl('5001', '4001'),
          contains('avviso associato 4001'));
      expect(messaggioEliminazioneOdl('5001', null), isNot(contains('avviso')));
    });

    Future<void> mostra(WidgetTester t, EliminazioneOdl esito) async {
      late BuildContext ctx;
      await t.pumpWidget(MaterialApp(
          home: Scaffold(body: Builder(builder: (c) {
        ctx = c;
        return const SizedBox();
      }))));
      mostraEsitoEliminazioneOdl(ctx, '5001', esito);
      await t.pump();
    }

    const ok = Success<void>(null);

    testWidgets('esito: nessun avviso', (t) async {
      await mostra(t, const EliminazioneOdl(ok));
      expect(find.text('OdL 5001 eliminato'), findsOneWidget);
    });

    testWidgets('esito: avviso eliminato', (t) async {
      await mostra(t,
          const EliminazioneOdl(ok, avviso: '4001', avvisoEliminato: true));
      expect(find.text('OdL 5001 e avviso 4001 eliminati'), findsOneWidget);
    });

    testWidgets('esito: avviso non eliminato, con il motivo', (t) async {
      await mostra(t,
          const EliminazioneOdl(ok, avviso: '4001', erroreAvviso: 'rete'));
      expect(find.textContaining("l'avviso 4001 non è stato eliminato: rete"),
          findsOneWidget);
    });
  });
}
