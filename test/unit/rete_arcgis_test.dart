// Rete Viva Servizi sulla mappa (livelli ArcGIS protetti: contatori,
// riduttori di pressione).
// - Senza token (ARCGIS_TOKEN): nessun interruttore nel pannello, nessuna
//   chiamata, nessun punto.
// - Con token: il servizio interroga solo la zona visibile e da vicino; il
//   tocco su un punto apre la scheda con Naviga / Crea avviso / Crea OdL, che
//   portano posizione (e matricola, se il livello la ha) nei moduli.
//
// I punti e gli attributi qui sotto sono valori di prova dei test (il servizio
// reale è protetto): non esistono nel codice dell'app.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:wfm_mobile/core/config/rete_arcgis_config.dart';
import 'package:wfm_mobile/core/router/app_routes.dart';
import 'package:wfm_mobile/core/services/rete_arcgis_service.dart';
import 'package:wfm_mobile/core/services/rete_viva_service.dart';
import 'package:wfm_mobile/domain/entities/entities.dart';
import 'package:wfm_mobile/presentation/features/create_order/create_avviso_screen.dart';
import 'package:wfm_mobile/presentation/features/create_order/create_order_screen.dart';
import 'package:wfm_mobile/presentation/features/map/map_screen.dart';
import 'package:wfm_mobile/presentation/providers/anagrafica_provider.dart';
import 'package:wfm_mobile/presentation/providers/map_provider.dart';

/// Dio che risponde con [risposta] e registra le richieste (niente rete).
Dio _dioFinto(List<RequestOptions> richieste, Object? Function(RequestOptions) risposta) {
  final dio = Dio();
  dio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
    richieste.add(o);
    h.resolve(Response(requestOptions: o, statusCode: 200, data: risposta(o)));
  }));
  return dio;
}

/// Servizio finto con token: un contatore e un riduttore al centro di Ancona.
class _ReteFinta extends ReteArcgisService {
  _ReteFinta() : super(token: 'token-di-prova');

  final zone = <StratoRete>[];

  @override
  Future<SchemaStrato> schema(StratoRete s) async => const SchemaStrato(
      alias: {'MATRICOLA': 'Matricola', 'CALIBRO': 'Calibro (mm)'},
      campoTitolo: 'MATRICOLA');

  @override
  Future<List<ElementoRete>> nellaZona(StratoRete s,
      {required double sud,
      required double ovest,
      required double nord,
      required double est,
      int massimo = 400}) async {
    zone.add(s);
    return [
      if (s == StratoRete.misuratori)
        const ElementoRete(
            strato: StratoRete.misuratori,
            lat: 43.615,
            lng: 13.519,
            attributi: {
              'OBJECTID': 1,
              'MATRICOLA': 'M-TEST-01',
              'CALIBRO': 15,
              'GlobalID': '{abc}',
            }),
      if (s == StratoRete.riduttori)
        const ElementoRete(
            strato: StratoRete.riduttori,
            lat: 43.6152,
            lng: 13.5195,
            attributi: {'OBJECTID': 7, 'NOME': 'RID-TEST'}),
    ];
  }
}

class _ReteNegata extends ReteArcgisService {
  _ReteNegata() : super(token: 'scaduto');
  @override
  Future<List<ElementoRete>> nellaZona(StratoRete s,
          {required double sud,
          required double ovest,
          required double nord,
          required double est,
          int massimo = 400}) async =>
      throw const ReteNonAccessibile(
          'Accesso ai livelli ArcGIS rifiutato (498): token assente o scaduto.');
}

void main() {
  setUpAll(() => initializeDateFormatting('it_IT', null));

  group('ReteArcgisService', () {
    test('senza token: spento, nessuna chiamata', () async {
      final richieste = <RequestOptions>[];
      final s = ReteArcgisService(
          token: '', dio: _dioFinto(richieste, (_) => const {}));
      expect(s.attivo, isFalse);
      expect(
          await s.nellaZona(StratoRete.misuratori,
              sud: 43.6, ovest: 13.5, nord: 43.7, est: 13.6),
          isEmpty);
      expect(richieste, isEmpty);
      // Il default di compilazione dei test non ha token.
      expect(ReteArcgisConfig.attivo, isFalse);
    });

    test('query: livello, zona visibile in WGS84, token, tutti i campi',
        () async {
      final richieste = <RequestOptions>[];
      final s = ReteArcgisService(
          servizio: 'https://esempio/FeatureServer',
          token: 't1',
          dio: _dioFinto(
              richieste,
              (_) => {
                    'features': [
                      {
                        'attributes': {'OBJECTID': 3, 'MATRICOLA': 'X9'},
                        'geometry': {'x': 13.51, 'y': 43.61},
                      },
                      // Senza geometria: scartato.
                      {'attributes': {'OBJECTID': 4}},
                    ]
                  }));
      final punti = await s.nellaZona(StratoRete.misuratori,
          sud: 43.6, ovest: 13.5, nord: 43.7, est: 13.6);

      final q = richieste.single;
      expect(q.uri.path, '/FeatureServer/12/query');
      expect(q.queryParameters['geometry'], '13.5,43.6,13.6,43.7');
      expect(q.queryParameters['geometryType'], 'esriGeometryEnvelope');
      expect(q.queryParameters['inSR'], 4326);
      expect(q.queryParameters['outSR'], 4326);
      expect(q.queryParameters['outFields'], '*');
      expect(q.queryParameters['token'], 't1');

      expect(punti, hasLength(1));
      expect(punti.single.lat, 43.61);
      expect(punti.single.lng, 13.51);
      expect(punti.single.matricola, 'X9');
      expect(punti.single.id, 'misuratori-3');
    });

    test('riduttori: livello 5', () async {
      final richieste = <RequestOptions>[];
      final s = ReteArcgisService(
          servizio: 'https://esempio/FeatureServer',
          token: 't1',
          dio: _dioFinto(richieste, (_) => {'features': []}));
      await s.nellaZona(StratoRete.riduttori,
          sud: 0, ovest: 0, nord: 1, est: 1);
      expect(richieste.single.uri.path, '/FeatureServer/5/query');
    });

    test('499/498 dentro una risposta 200: ReteNonAccessibile', () async {
      for (final code in [498, 499]) {
        final s = ReteArcgisService(
            token: 't',
            dio: _dioFinto([], (_) => {
                  'error': {'code': code, 'message': 'Token Required'}
                }));
        expect(
            () => s.nellaZona(StratoRete.misuratori,
                sud: 0, ovest: 0, nord: 1, est: 1),
            throwsA(isA<ReteNonAccessibile>()));
      }
    });

    test('schema: etichette dei campi e campo titolo, in cache', () async {
      final richieste = <RequestOptions>[];
      final s = ReteArcgisService(
          servizio: 'https://esempio/FeatureServer',
          token: 't',
          dio: _dioFinto(
              richieste,
              (_) => {
                    'displayField': 'MATRICOLA',
                    'fields': [
                      {'name': 'MATRICOLA', 'alias': 'Matricola contatore'},
                      {'name': 'CALIBRO'},
                    ]
                  }));
      final a = await s.schema(StratoRete.misuratori);
      await s.schema(StratoRete.misuratori);
      expect(richieste, hasLength(1));
      expect(richieste.single.uri.path, '/FeatureServer/12');
      expect(a.campoTitolo, 'MATRICOLA');
      expect(a.etichetta('MATRICOLA'), 'Matricola contatore');
      expect(a.etichetta('CALIBRO'), 'CALIBRO');
    });

    test('matricola riconosciuta solo dal nome del campo', () {
      ElementoRete e(Map<String, Object?> a) => ElementoRete(
          strato: StratoRete.misuratori, lat: 0, lng: 0, attributi: a);
      expect(e({'Matricola': 'A1'}).matricola, 'A1');
      expect(e({'NUMERO_SERIE': 'B2'}).matricola, 'B2');
      expect(e({'N_SERIE': 'C3'}).matricola, 'C3');
      expect(e({'CODICE': 'D4'}).matricola, isNull);
      expect(e({'MATRICOLA': '  '}).matricola, isNull);
    });
  });

  group('percorsi di creazione dalla rete', () {
    test('OdL: tipo, matricola, posizione, ciclo', () {
      final u = Uri.parse(AppRoutes.createOrderDaMappaPath(
          woType: 'ZA02', lat: 43.6, lng: 13.5, ciclo: 'CONRID1'));
      expect(u.path, AppRoutes.createOrder);
      expect(u.queryParameters, {
        'type': 'ZA02',
        'lat': '43.6',
        'lng': '13.5',
        'ciclo': 'CONRID1',
      });
    });

    test('avviso: matricola e posizione; senza matricola niente "meter"', () {
      final u = Uri.parse(AppRoutes.createAvvisoDaMappaPath(
          matricola: 'M 1/2', lat: 43.6, lng: 13.5));
      expect(u.path, AppRoutes.createAvviso);
      expect(u.queryParameters['meter'], 'M 1/2');
      final v = Uri.parse(
          AppRoutes.createAvvisoDaMappaPath(lat: 43.6, lng: 13.5));
      expect(v.queryParameters.containsKey('meter'), isFalse);
    });
  });

  group('mappa', () {
    Future<List<String>> apri(WidgetTester t, {ReteArcgisService? rete}) async {
      final aperti = <String>[];
      await t.binding.setSurfaceSize(const Size(1000, 1600));
      final router = GoRouter(routes: [
        GoRoute(path: '/', builder: (_, __) => const MapScreen()),
        GoRoute(
            path: AppRoutes.createOrder,
            builder: (_, s) {
              aperti.add(s.uri.toString());
              return const Text('modulo OdL');
            }),
        GoRoute(
            path: AppRoutes.createAvviso,
            builder: (_, s) {
              aperti.add(s.uri.toString());
              return const Text('modulo avviso');
            }),
      ]);
      await t.pumpWidget(ProviderScope(
        overrides: [
          mapPointsProvider.overrideWith((ref) async => const <MapPoint>[]),
          mapMissingCountProvider.overrideWith((ref) async => 0),
          reteVivaProvider.overrideWith((ref) async => ReteViva.vuota),
          if (rete != null) reteArcgisProvider.overrideWithValue(rete),
        ],
        child: MaterialApp.router(routerConfig: router),
      ));
      await t.pump();
      await t.pump();
      return aperti;
    }

    /// Da zoom 13 a 16 (il minimo della rete) e attesa del caricamento.
    Future<void> avvicinaAllaRete(WidgetTester t) async {
      for (var i = 0; i < 3; i++) {
        await t.tap(find.byTooltip('Avvicina'));
        await t.pump();
      }
      await t.pump(const Duration(milliseconds: 600));
      await t.pump();
    }

    testWidgets('senza token: nel pannello del fondo non compare la rete',
        (t) async {
      await apri(t);
      await t.tap(find.byTooltip('Fondo mappa'));
      await t.pumpAndSettle();

      expect(find.text('Fondo mappa'), findsWidgets);
      expect(find.text('Rete Viva Servizi'), findsNothing);
      // Solo i contatori degli interventi (dal backend), niente livelli Viva.
      expect(find.byType(SwitchListTile), findsNWidgets(2));
      expect(find.text('Contatori degli interventi'), findsOneWidget);
      expect(find.widgetWithText(SwitchListTile, 'Rete idrica Viva Servizi'),
          findsOneWidget);
      expect(find.textContaining('ARCGIS_TOKEN'), findsNothing);
    });

    testWidgets('con token: il pannello offre i due livelli, accesi',
        (t) async {
      await apri(t, rete: _ReteFinta());
      await t.tap(find.byTooltip('Fondo mappa'));
      await t.pumpAndSettle();

      expect(find.text('Rete Viva Servizi'), findsOneWidget);
      final interruttori = [
        for (final titolo in ['Contatori', 'Riduttori di pressione'])
          t.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, titolo)),
      ];
      for (final s in interruttori) {
        expect(s.value, isTrue);
        expect(s.onChanged, isNotNull);
      }
    });

    testWidgets('senza token: nessun punto e nessun avviso "Avvicinati"',
        (t) async {
      await apri(t);
      await avvicinaAllaRete(t);
      expect(find.byType(PuntoRete), findsNothing);
      expect(find.textContaining('Avvicinati'), findsNothing);
    });

    testWidgets('con token, da lontano: invito ad avvicinarsi, nessuna query',
        (t) async {
      final rete = _ReteFinta();
      await apri(t, rete: rete);
      await t.pump(const Duration(milliseconds: 600));
      await t.pump();
      expect(find.textContaining('Avvicinati per vedere la rete'),
          findsOneWidget);
      expect(rete.zone, isEmpty);
    });

    testWidgets('con token, da vicino: contatori e riduttori sulla mappa',
        (t) async {
      final rete = _ReteFinta();
      await apri(t, rete: rete);
      await avvicinaAllaRete(t);

      expect(rete.zone.toSet(), StratoRete.values.toSet());
      final punti = t.widgetList<PuntoRete>(find.byType(PuntoRete)).toList();
      expect(punti.map((p) => p.strato).toSet(), StratoRete.values.toSet());
      expect(find.textContaining('Avvicinati'), findsNothing);
    });

    testWidgets('spegnere un livello lo toglie dalla mappa', (t) async {
      final rete = _ReteFinta();
      await apri(t, rete: rete);
      await avvicinaAllaRete(t);

      await t.tap(find.byTooltip('Fondo mappa'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(SwitchListTile, 'Riduttori di pressione'));
      await t.pumpAndSettle();
      await t.tapAt(const Offset(500, 100)); // chiude il pannello
      await t.pumpAndSettle();

      final punti = t.widgetList<PuntoRete>(find.byType(PuntoRete)).toList();
      expect(punti.map((p) => p.strato).toSet(), {StratoRete.misuratori});
    });

    testWidgets('scheda contatore: attributi con etichette, azioni', (t) async {
      final rete = _ReteFinta();
      await apri(t, rete: rete);
      await avvicinaAllaRete(t);

      await t.tap(find.byWidgetPredicate(
          (w) => w is PuntoRete && w.strato == StratoRete.misuratori));
      await t.pump();
      await t.pump();

      expect(find.byType(ElementoReteCard), findsOneWidget);
      expect(find.text('CONTATORI'), findsOneWidget);
      expect(find.text('Calibro (mm)'), findsOneWidget);
      expect(find.text('15'), findsOneWidget);
      // Campi tecnici nascosti.
      expect(find.text('OBJECTID'), findsNothing);
      expect(find.text('GlobalID'), findsNothing);
      for (final a in ['Naviga', 'Crea avviso', 'Crea OdL']) {
        expect(find.text(a), findsOneWidget, reason: a);
      }
    });

    testWidgets('Crea OdL da un contatore: SOST con matricola e posizione',
        (t) async {
      final rete = _ReteFinta();
      final aperti = await apri(t, rete: rete);
      await avvicinaAllaRete(t);
      await t.tap(find.byWidgetPredicate(
          (w) => w is PuntoRete && w.strato == StratoRete.misuratori));
      await t.pump();
      await t.tap(find.text('Crea OdL'));
      await t.pumpAndSettle();

      final q = Uri.parse(aperti.single).queryParameters;
      expect(q['type'], 'SOST');
      expect(q['meter'], 'M-TEST-01');
      expect(q['lat'], '43.615');
      expect(q['lng'], '13.519');
    });

    testWidgets('Crea OdL da un riduttore: ZA02 col ciclo CONRID1', (t) async {
      final rete = _ReteFinta();
      final aperti = await apri(t, rete: rete);
      await avvicinaAllaRete(t);
      await t.tap(find.byWidgetPredicate(
          (w) => w is PuntoRete && w.strato == StratoRete.riduttori));
      await t.pump();
      await t.tap(find.text('Crea OdL'));
      await t.pumpAndSettle();

      final q = Uri.parse(aperti.single).queryParameters;
      expect(q['type'], 'ZA02');
      expect(q['ciclo'], 'CONRID1');
      expect(q.containsKey('meter'), isFalse);
    });

    testWidgets('Crea avviso da un contatore: matricola e posizione',
        (t) async {
      final rete = _ReteFinta();
      final aperti = await apri(t, rete: rete);
      await avvicinaAllaRete(t);
      await t.tap(find.byWidgetPredicate(
          (w) => w is PuntoRete && w.strato == StratoRete.misuratori));
      await t.pump();
      await t.tap(find.text('Crea avviso'));
      await t.pumpAndSettle();

      final u = Uri.parse(aperti.single);
      expect(u.path, AppRoutes.createAvviso);
      expect(u.queryParameters['meter'], 'M-TEST-01');
      expect(u.queryParameters['lat'], '43.615');
    });

    testWidgets('token rifiutato: messaggio, nessun punto', (t) async {
      await apri(t, rete: _ReteNegata());
      await avvicinaAllaRete(t);
      expect(find.textContaining('token assente o scaduto'), findsOneWidget);
      expect(find.byType(PuntoRete), findsNothing);
    });
  });

  group('moduli precompilati dalla mappa', () {
    testWidgets('OdL ZA02 dal riduttore: propone la riga del ciclo CONRID1',
        (t) async {
      await t.binding.setSurfaceSize(const Size(1200, 3000));
      await t.pumpWidget(ProviderScope(
        overrides: [
          workOrderTypesProvider.overrideWith((ref) async => [
                const WorkOrderTypeOption(code: 'ZA02', label: 'Tipo di prova'),
              ]),
          workOrderFieldsProvider('ZA02').overrideWith((ref) async => const []),
          workOrderTemplatesProvider('ZA02').overrideWith((ref) async => const [
                WorkOrderActivityTemplate(
                    woType: 'ZA02',
                    tipoAttivita: 'A1',
                    tipoAttivitaDesc: 'Riga predefinita',
                    gruppoCicli: 'ALTRO1',
                    predefinita: true),
                WorkOrderActivityTemplate(
                    woType: 'ZA02',
                    tipoAttivita: 'A2',
                    tipoAttivitaDesc: 'Riga del riduttore',
                    gruppoCicli: 'CONRID1'),
              ]),
          orderPrioritiesProvider('ZA02')
              .overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(
            home: CreateOrderScreen(
                initialWoType: 'ZA02',
                initialGruppoCicli: 'CONRID1',
                latitudine: 43.6,
                longitudine: 13.5)),
      ));
      await t.pumpAndSettle();
      expect(find.text('A2 · Riga del riduttore'), findsOneWidget);
      expect(find.text('A1 · Riga predefinita'), findsNothing);
    });

    testWidgets('avviso dal contatore: promemoria con matricola e posizione',
        (t) async {
      await t.binding.setSurfaceSize(const Size(1200, 3000));
      await t.pumpWidget(ProviderScope(
        overrides: [
          lookupProvider('avviso-types').overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(
            home: CreateAvvisoScreen(
                matricola: 'M-TEST-01', latitudine: 43.6, longitudine: 13.5)),
      ));
      await t.pumpAndSettle();
      expect(find.text('Contatore M-TEST-01 · posizione presa dalla mappa'),
          findsOneWidget);
    });

    testWidgets('avviso normale: nessun promemoria', (t) async {
      await t.binding.setSurfaceSize(const Size(1200, 3000));
      await t.pumpWidget(ProviderScope(
        overrides: [
          lookupProvider('avviso-types').overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(home: CreateAvvisoScreen()),
      ));
      await t.pumpAndSettle();
      expect(find.textContaining('presa dalla mappa'), findsNothing);
    });
  });
}
