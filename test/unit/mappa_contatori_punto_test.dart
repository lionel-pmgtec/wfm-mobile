// Mappa per creare OdL/avvisi senza la rete Viva (protetta):
// - contatori degli interventi: quelli che il backend manda su OdL e avvisi,
//   uno per matricola, visibili da vicino, con scheda e "Crea OdL SOST";
// - punto scelto: tenendo premuto (o scegliendo un indirizzo cercato) si
//   ottiene l'indirizzo reale del punto (Esri) e si crea l'OdL/avviso lì.
//
// Matricole, marche e indirizzi qui sotto sono valori di prova dei test:
// nell'app arrivano dal backend e dal geocodificatore Esri.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:wfm_mobile/core/router/app_routes.dart';
import 'package:wfm_mobile/core/services/ricerca_indirizzi_service.dart';
import 'package:wfm_mobile/core/services/rete_viva_service.dart';
import 'package:wfm_mobile/domain/entities/entities.dart';
import 'package:wfm_mobile/presentation/features/create_order/create_avviso_screen.dart';
import 'package:wfm_mobile/presentation/features/create_order/create_order_screen.dart';
import 'package:wfm_mobile/presentation/features/map/map_screen.dart';
import 'package:wfm_mobile/presentation/providers/anagrafica_provider.dart';
import 'package:wfm_mobile/presentation/providers/map_provider.dart';

MapPoint _odl(String id,
        {String? matricola,
        String marca = '',
        double lat = 43.6149,
        double lng = 13.5284}) =>
    MapPoint(
      id: id,
      titolo: 'Ordine $id',
      isAvviso: false,
      stato: WorkOrderStatus.ricevuto,
      statoMappa: StatoMappa.assegnato,
      latitude: lat,
      longitude: lng,
      indirizzo: 'VIA TRIESTE 40, 60124 ANCONA',
      address: const Address(
          street: 'VIA TRIESTE', streetNumber: '40', city: 'ANCONA', cap: '60124'),
      matricola: matricola,
      marcaContatore: marca,
      calibroContatore: matricola == null ? '' : '15',
    );

/// Geocodificatore finto: nessuna rete.
class _RicercaFinta extends RicercaIndirizziService {
  @override
  Future<IndirizzoPunto?> indirizzoDi(double lat, double lng) async =>
      const IndirizzoPunto(
          'Via Trieste 40, 60124, Ancona',
          IndirizzoMappa(
              via: 'Via Trieste', civico: '40', comune: 'Ancona', cap: '60124'));

  @override
  Future<List<SuggerimentoIndirizzo>> suggerisci(String testo,
          {double? lat, double? lng}) async =>
      const [SuggerimentoIndirizzo('Via Trieste, 60124, Ancona, ITA', 'k1')];

  @override
  Future<LuogoTrovato?> localizza(SuggerimentoIndirizzo s) async =>
      const LuogoTrovato('Via Trieste, 60124, Ancona', 43.6149, 13.5284);
}

Dio _dioFinto(Object? risposta) {
  final dio = Dio();
  dio.interceptors.add(InterceptorsWrapper(
      onRequest: (o, h) => h.resolve(
          Response(requestOptions: o, statusCode: 200, data: risposta))));
  return dio;
}

void main() {
  setUpAll(() => initializeDateFormatting('it_IT', null));

  group('contatori dal backend', () {
    test('uno per matricola (anche con gli zeri davanti), con gli interventi',
        () {
      final c = contatoriDaPunti([
        _odl('1', matricola: '000000000000135075', marca: 'SENSUS'),
        _odl('2', matricola: '135075'),
        _odl('3', matricola: 'X9'),
        _odl('4'), // senza contatore
        _odl('5', matricola: '  '),
      ]);
      expect(c, hasLength(2));
      final primo = c.firstWhere((x) => x.interventi.contains('1'));
      expect(primo.interventi, ['1', '2']);
      expect(primo.marca, 'SENSUS');
      expect(primo.calibro, '15');
      expect(primo.address?.street, 'VIA TRIESTE');
    });
  });

  group('indirizzo del punto (reverseGeocode Esri)', () {
    test('via e civico separati, comune e CAP', () async {
      final s = RicercaIndirizziService(
          dio: _dioFinto({
        'address': {
          'Match_addr': 'Via Trieste 40, 60124, Ancona',
          'Address': 'Via Trieste 40',
          'AddNum': '40',
          'City': 'Ancona',
          'Postal': '60124',
        }
      }));
      final p = (await s.indirizzoDi(43.6149, 13.5284))!;
      expect(p.etichetta, 'Via Trieste 40, 60124, Ancona');
      expect(p.indirizzo.via, 'Via Trieste');
      expect(p.indirizzo.civico, '40');
      expect(p.indirizzo.comune, 'Ancona');
      expect(p.indirizzo.cap, '60124');
    });

    test('in mare (nessun comune): null', () async {
      final s = RicercaIndirizziService(
          dio: _dioFinto({
        'address': {'Match_addr': 'Adriatic Sea', 'Address': '', 'City': ''}
      }));
      expect(await s.indirizzoDi(43.7, 13.6), isNull);
    });

    test('servizio in errore: null', () async {
      final s = RicercaIndirizziService(
          dio: _dioFinto({
        'error': {'code': 400}
      }));
      expect(await s.indirizzoDi(43.7, 13.6), isNull);
    });
  });

  group('percorsi con l\'indirizzo del punto', () {
    test('OdL senza tipo: posizione e indirizzo', () {
      final q = Uri.parse(AppRoutes.createOrderDaMappaPath(
              lat: 43.6,
              lng: 13.5,
              indirizzo: const IndirizzoMappa(
                  via: 'Via Trieste', civico: '40', comune: 'Ancona')))
          .queryParameters;
      expect(q.containsKey('type'), isFalse);
      expect(q['via'], 'Via Trieste');
      expect(q['civico'], '40');
      expect(q['comune'], 'Ancona');
      expect(IndirizzoMappa.daQuery(q)!.via, 'Via Trieste');
    });

    test('senza via né comune nei parametri: nessun indirizzo', () {
      expect(IndirizzoMappa.daQuery({'lat': '1', 'civico': '4'}), isNull);
    });
  });

  group('mappa', () {
    Future<List<String>> apri(WidgetTester t, List<MapPoint> punti) async {
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
          mapPointsProvider.overrideWith((ref) async => punti),
          mapMissingCountProvider.overrideWith((ref) async => 0),
          ricercaIndirizziProvider.overrideWithValue(_RicercaFinta()),
          reteVivaProvider.overrideWith((ref) async => ReteViva.vuota),
        ],
        child: MaterialApp.router(routerConfig: router),
      ));
      await t.pump();
      await t.pump();
      return aperti;
    }

    Future<void> avvicina(WidgetTester t, int volte) async {
      for (var i = 0; i < volte; i++) {
        await t.tap(find.byTooltip('Avvicina'));
        await t.pump();
      }
      await t.pump();
    }

    testWidgets('da lontano i contatori non si vedono: invito ad avvicinarsi',
        (t) async {
      await apri(t, [_odl('1', matricola: 'M-1')]);
      await avvicina(t, 1); // zoom 14
      expect(find.byType(SimboloContatore), findsNothing);
      expect(find.text('Avvicinati per vedere la rete e i contatori'),
          findsOneWidget);
    });

    testWidgets('da vicino compaiono, uno per matricola', (t) async {
      await apri(t, [
        _odl('1', matricola: 'M-1'),
        _odl('2', matricola: '000M-1'), // stesso contatore
        _odl('3'), // senza contatore
      ]);
      await avvicina(t, 2); // zoom 15
      expect(find.byType(SimboloContatore), findsOneWidget);
      expect(find.textContaining('Avvicinati'), findsNothing);
    });

    testWidgets('senza contatori: nessun invito ad avvicinarsi', (t) async {
      await apri(t, [_odl('1')]);
      expect(find.textContaining('Avvicinati'), findsNothing);
    });

    testWidgets('si possono spegnere dal pannello', (t) async {
      await apri(t, [_odl('1', matricola: 'M-1')]);
      await avvicina(t, 2);
      await t.tap(find.byTooltip('Fondo mappa'));
      await t.pumpAndSettle();
      await t.tap(
          find.widgetWithText(SwitchListTile, 'Contatori degli interventi'));
      await t.pumpAndSettle();
      await t.tapAt(const Offset(500, 100));
      await t.pumpAndSettle();
      expect(find.byType(SimboloContatore), findsNothing);
    });

    testWidgets('scheda contatore e "Crea OdL SOST" con matricola e indirizzo',
        (t) async {
      final aperti =
          await apri(t, [_odl('50557247', matricola: 'M-1', marca: 'SENSUS')]);
      await avvicina(t, 2);
      await t.tap(find.byType(SimboloContatore));
      await t.pump();

      expect(find.text('CONTATORE'), findsOneWidget);
      expect(find.text('M-1'), findsOneWidget);
      expect(find.text('SENSUS'), findsOneWidget);
      expect(find.text('50557247'), findsOneWidget); // intervento
      await t.tap(find.text('Crea OdL SOST'));
      await t.pumpAndSettle();

      final q = Uri.parse(aperti.single).queryParameters;
      expect(q['type'], 'SOST');
      expect(q['meter'], 'M-1');
      expect(q['lat'], '43.6149');
      expect(q['via'], 'VIA TRIESTE');
      expect(q['civico'], '40');
      expect(q['comune'], 'ANCONA');
    });

    testWidgets('tenere premuto: indirizzo del punto e "Crea avviso"',
        (t) async {
      final aperti = await apri(t, const []);
      await t.longPressAt(const Offset(500, 800));
      await t.pump();
      await t.pump();

      expect(find.text('PUNTO SCELTO'), findsOneWidget);
      expect(find.text('Via Trieste 40, 60124, Ancona'), findsOneWidget);
      await t.tap(find.text('Crea avviso'));
      await t.pumpAndSettle();

      final u = Uri.parse(aperti.single);
      expect(u.path, AppRoutes.createAvviso);
      expect(u.queryParameters['via'], 'Via Trieste');
      expect(u.queryParameters['comune'], 'Ancona');
      expect(u.queryParameters['lat'], isNotNull);
    });

    testWidgets('tenere premuto: "Crea OdL" senza tipo imposto', (t) async {
      final aperti = await apri(t, const []);
      await t.longPressAt(const Offset(500, 800));
      await t.pump();
      await t.pump();
      await t.tap(find.text('Crea OdL'));
      await t.pumpAndSettle();

      final q = Uri.parse(aperti.single).queryParameters;
      expect(q.containsKey('type'), isFalse);
      expect(q['cap'], '60124');
    });

    testWidgets('un indirizzo cercato diventa il punto scelto', (t) async {
      await apri(t, const []);
      await t.tap(find.byType(TextField));
      await t.enterText(find.byType(TextField), 'via trieste');
      await t.pump(const Duration(milliseconds: 400));
      await t.pump();
      await t.tap(find.text('Via Trieste, 60124, Ancona, ITA'));
      await t.pump();
      await t.pump();

      expect(find.text('PUNTO SCELTO'), findsOneWidget);
      expect(find.byIcon(Icons.location_on_rounded), findsOneWidget);
    });

    testWidgets('legenda: contatore e "tieni premuto"', (t) async {
      await apri(t, const []);
      await t.tap(find.byTooltip('Legenda'));
      await t.pump();
      expect(find.text('Contatore di un intervento'), findsOneWidget);
      expect(find.textContaining('Tieni premuto sulla mappa'), findsOneWidget);
    });
  });

  group('moduli precompilati col punto della mappa', () {
    const ind = IndirizzoMappa(
        via: 'Via Trieste', civico: '40', comune: 'Ancona', cap: '60124');

    testWidgets('OdL: via, civico, comune, CAP', (t) async {
      await t.binding.setSurfaceSize(const Size(1200, 3000));
      await t.pumpWidget(ProviderScope(
        overrides: [
          workOrderTypesProvider.overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(
            home: CreateOrderScreen(
                latitudine: 43.6, longitudine: 13.5, indirizzo: ind)),
      ));
      await t.pumpAndSettle();
      for (final v in ['Via Trieste', '40', 'Ancona', '60124']) {
        expect(find.widgetWithText(TextFormField, v), findsOneWidget,
            reason: v);
      }
    });

    testWidgets('avviso: via, civico, comune', (t) async {
      await t.binding.setSurfaceSize(const Size(1200, 3000));
      await t.pumpWidget(ProviderScope(
        overrides: [
          lookupProvider('avviso-types').overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(
            home: CreateAvvisoScreen(
                latitudine: 43.6, longitudine: 13.5, indirizzo: ind)),
      ));
      await t.pumpAndSettle();
      for (final v in ['Via Trieste', '40', 'Ancona']) {
        expect(find.widgetWithText(TextFormField, v), findsOneWidget,
            reason: v);
      }
    });
  });
}
