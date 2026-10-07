// Avviso e OdL generato da esso.
//
// - Per gli OdL nati sul tablet il backend NON scrive l'OdL sull'avviso
//   (`ordineDiLavoro` vuoto): il tablet legge il legame dall'OdL
//   (`avvisoOrigine`), così l'avviso mostra "OdL …" / "Apri OdL" e non
//   "Genera OdL".
// - La bannière "Pronto intervento" della Home mostra gli avvisi ZH/ZF e si
//   aggiorna quando arrivano avvisi nuovi.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:wfm_mobile/core/services/avvisi_rimossi_store.dart';
import 'package:wfm_mobile/data/datasources/remote/remote_data_source.dart';
import 'package:wfm_mobile/domain/entities/entities.dart';
import 'package:wfm_mobile/presentation/features/avvisi/sub_screens/avviso_lavoro_tab.dart';
import 'package:wfm_mobile/presentation/providers/avvisi_provider.dart';
import 'package:wfm_mobile/presentation/providers/core_providers.dart';
import 'package:wfm_mobile/presentation/providers/creation_provider.dart';
import 'package:wfm_mobile/presentation/providers/work_orders_provider.dart';

WorkOrder _odl(String code, {String? avviso, String? sap}) => WorkOrder(
    externalCode: code,
    woType: 'ZA02',
    avvisoOrigine: avviso,
    notificationNumberSap: sap);

NotificationAvviso _avv(String n,
        {String tipo = 'ZI', String stato = 'RICEVUTO', String? odl}) =>
    NotificationAvviso(
        numeroAvviso: n,
        descrizione: 'Avviso $n',
        tipo: tipo,
        priorita: '1',
        stato: stato,
        ordineDiLavoro: odl);

class _Remote implements WfmRemoteDataSource {
  List<NotificationAvviso> avvisi;
  _Remote(this.avvisi);

  @override
  Future<List<NotificationAvviso>> getAvvisi({String? query}) async => avvisi;

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('$i');
}

void main() {
  setUpAll(() => initializeDateFormatting('it_IT', null));
  setUp(AvvisiRimossiStore.resetForTests);

  group('ordineCollegatoProvider', () {
    ProviderContainer contenitore(List<WorkOrder> odl) {
      final c = ProviderContainer(
          overrides: [workOrdersProvider.overrideWith((ref) async => odl)]);
      addTearDown(c.dispose);
      return c;
    }

    test("l'OdL che porta il numero dell'avviso è quello collegato", () async {
      final c = contenitore([
        _odl('A1'),
        _odl('A2', avviso: 'TMP-AVV-1'),
      ]);
      final o = await c.read(ordineCollegatoProvider('TMP-AVV-1').future);
      expect(o?.externalCode, 'A2');
    });

    test('anche con gli zeri davanti e da notificationNumberSAP', () async {
      final c = contenitore([_odl('A3', sap: '000400090003')]);
      expect(
          (await c.read(ordineCollegatoProvider('400090003').future))
              ?.externalCode,
          'A3');
    });

    test('avviso senza OdL: nessun collegamento', () async {
      final c = contenitore([_odl('A1', avviso: 'TMP-AVV-9')]);
      expect(await c.read(ordineCollegatoProvider('TMP-AVV-1').future), isNull);
    });
  });

  group('tab Lavoro dell\'avviso', () {
    Future<void> apri(WidgetTester t, NotificationAvviso a, List<WorkOrder> odl,
        List<String> aperti) async {
      await t.binding.setSurfaceSize(const Size(1000, 1600));
      final router = GoRouter(routes: [
        GoRoute(
            path: '/',
            builder: (_, __) => Scaffold(body: AvvisoLavoroTab(avviso: a))),
        GoRoute(
            path: '/work-orders/:id',
            builder: (_, s) {
              aperti.add(s.pathParameters['id']!);
              return const Text('dettaglio OdL');
            }),
        GoRoute(
            path: '/avvisi/:id/genera-ordine',
            builder: (_, s) {
              aperti.add('genera ${s.pathParameters['id']}');
              return const Text('genera');
            }),
      ]);
      await t.pumpWidget(ProviderScope(
        overrides: [workOrdersProvider.overrideWith((ref) async => odl)],
        child: MaterialApp.router(routerConfig: router),
      ));
      await t.pumpAndSettle();
    }

    testWidgets("avviso con OdL generato sul tablet: 'Apri OdL'", (t) async {
      final aperti = <String>[];
      await apri(t, _avv('TMP-AVV-1'), [_odl('TMP-ODL-7', avviso: 'TMP-AVV-1')],
          aperti);
      expect(find.text('OdL TMP-ODL-7'), findsOneWidget);
      expect(find.text('Nessun ordine — genera adesso'), findsNothing);
      expect(find.text('Genera OdL'), findsNothing);

      await t.tap(find.text('Apri OdL'));
      await t.pumpAndSettle();
      expect(aperti, ['TMP-ODL-7']);
    });

    testWidgets("avviso senza OdL: 'Genera OdL' come prima", (t) async {
      final aperti = <String>[];
      await apri(t, _avv('TMP-AVV-2'), [_odl('X', avviso: 'TMP-AVV-1')], aperti);
      expect(find.text('Nessun ordine — genera adesso'), findsOneWidget);
      await t.tap(find.text('Genera OdL'));
      await t.pumpAndSettle();
      expect(aperti, ['genera TMP-AVV-2']);
    });

    testWidgets("OdL collegato dal backend (SAP): resta quello dell'avviso",
        (t) async {
      final aperti = <String>[];
      await apri(t, _avv('4001', odl: '5001'), const [], aperti);
      expect(find.text('OdL 5001'), findsOneWidget);
      expect(find.text('Apri OdL'), findsOneWidget);
    });
  });

  group('bannière Pronto intervento della Home', () {
    ProviderContainer contenitore(_Remote remote) {
      final c = ProviderContainer(overrides: [
        remoteDataSourceProvider.overrideWithValue(remote),
        createdWorkOrdersProvider.overrideWith((ref) async => <WorkOrder>[]),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    test('mostra gli avvisi ZH e ZF, non gli altri tipi', () async {
      final c = contenitore(_Remote([
        _avv('1', tipo: 'ZH'),
        _avv('2', tipo: 'ZF'),
        _avv('3', tipo: 'IS'),
        _avv('4', tipo: 'ZI'),
      ]));
      final l = await c.read(prontoInterventoAvvisiProvider.future);
      expect(l.map((a) => a.tipo), ['ZH', 'ZF']);
    });

    test('un avviso ZH nuovo compare dopo il rinfresco (sync, poll, realtime)',
        () async {
      final remote = _Remote([_avv('1', tipo: 'IS')]);
      final c = contenitore(remote);
      expect(await c.read(prontoInterventoAvvisiProvider.future), isEmpty);

      remote.avvisi = [_avv('1', tipo: 'IS'), _avv('2', tipo: 'ZH')];
      // Senza rinfresco la bannière tiene la sua copia: per questo i punti
      // che aggiornano gli avvisi aggiornano anche lei.
      c.invalidate(avvisiProvider);
      c.invalidate(prontoInterventoAvvisiProvider);
      final l = await c.read(prontoInterventoAvvisiProvider.future);
      expect(l.map((a) => a.numeroAvviso), ['2']);
    });
  });
}
