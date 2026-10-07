// Mappa: fondo ArcGIS (Esri), stati/colori/forme come la mappa del cruscotto,
// ricerca, scelta del fondo, comandi flottanti, elenco degli interventi,
// scheda con tipo/priorità e pulsante "Naviga".

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wfm_mobile/core/services/navigazione_service.dart';
import 'package:wfm_mobile/core/services/ricerca_indirizzi_service.dart';
import 'package:wfm_mobile/core/services/rete_viva_service.dart';
import 'package:wfm_mobile/domain/entities/entities.dart';
import 'package:wfm_mobile/presentation/features/map/map_screen.dart';
import 'package:wfm_mobile/presentation/providers/map_provider.dart';
import 'package:wfm_mobile/presentation/widgets/naviga_button.dart';

MapPoint _odl(String id, WorkOrderStatus s, {bool approx = true}) => MapPoint(
      id: id,
      titolo: 'Ordine $id',
      isAvviso: false,
      stato: s,
      statoMappa: StatoMappa.daOrdine(s)!,
      statoLabel: s.label,
      tipo: 'ZA02',
      priorita: 'Programmato',
      latitude: 43.61,
      longitude: 13.51,
      approssimativa: approx,
      indirizzo: 'VIA TRIESTE 40, 60121 ANCONA (AN)',
    );

MapPoint _avviso(String id) => MapPoint(
      id: id,
      titolo: 'Perdita',
      isAvviso: true,
      statoMappa: StatoMappa.daAvviso(AvvisoStato.inLavorazione),
      statoLabel: AvvisoStato.inLavorazione.label,
      tipo: 'ZI',
      latitude: 43.62,
      longitude: 13.52,
      indirizzo: 'CORSO GARIBALDI 10, ANCONA',
    );

/// Geocodificatore finto (solo test): risposte fisse, niente rete.
class _RicercaFinta extends RicercaIndirizziService {
  @override
  Future<List<SuggerimentoIndirizzo>> suggerisci(String testo,
          {double? lat, double? lng}) async =>
      testo.toLowerCase().contains('trieste')
          ? const [SuggerimentoIndirizzo('Via Trieste, 60124, Ancona, ITA', 'k1')]
          : const [];

  @override
  Future<LuogoTrovato?> localizza(SuggerimentoIndirizzo s) async =>
      const LuogoTrovato('Via Trieste, 60124, Ancona', 43.6149, 13.5283);

  @override
  Future<IndirizzoPunto?> indirizzoDi(double lat, double lng) async => null;
}

void main() {
  group('stati sulla mappa = stati e colori del cruscotto', () {
    test('ordini', () {
      expect(StatoMappa.daOrdine(WorkOrderStatus.ricevuto), StatoMappa.assegnato);
      expect(StatoMappa.daOrdine(WorkOrderStatus.inEsecuzione),
          StatoMappa.inEsecuzione);
      // La pausa esiste solo sul tablet: per il backend è in esecuzione.
      expect(StatoMappa.daOrdine(WorkOrderStatus.inPausa),
          StatoMappa.inEsecuzione);
      expect(StatoMappa.daOrdine(WorkOrderStatus.sospeso), StatoMappa.sospeso);
      expect(StatoMappa.daOrdine(WorkOrderStatus.completato),
          StatoMappa.completato);
      // Ciclo chiuso: non compaiono, come sul cruscotto.
      expect(StatoMappa.daOrdine(WorkOrderStatus.annullato), isNull);
      expect(StatoMappa.daOrdine(WorkOrderStatus.inviatoSAP), isNull);
    });

    test('avvisi', () {
      expect(StatoMappa.daAvviso(AvvisoStato.creato), StatoMappa.assegnato);
      expect(StatoMappa.daAvviso(AvvisoStato.presoInCarico),
          StatoMappa.assegnato);
      expect(StatoMappa.daAvviso(AvvisoStato.inLavorazione),
          StatoMappa.inEsecuzione);
      expect(StatoMappa.daAvviso(AvvisoStato.sospeso), StatoMappa.sospeso);
      expect(StatoMappa.daAvviso(AvvisoStato.chiuso), StatoMappa.completato);
    });

    test('colori identici al cruscotto (MapPage.tsx)', () {
      expect(StatoMappa.assegnato.colore, const Color(0xFFFF9800));
      expect(StatoMappa.inEsecuzione.colore, const Color(0xFFE53935));
      expect(StatoMappa.sospeso.colore, const Color(0xFF9C27B0));
      expect(StatoMappa.completato.colore, const Color(0xFF4CAF50));
    });
  });

  group('Naviga', () {
    test('con coordinate: percorso verso il punto', () {
      final uri = NavigazioneService.uriPercorso(lat: 43.615, lng: 13.519)!;
      expect(uri.host, 'www.google.com');
      expect(uri.path, '/maps/dir/');
      expect(uri.queryParameters['api'], '1');
      expect(uri.queryParameters['destination'], '43.615,13.519');
      expect(uri.queryParameters['travelmode'], 'driving');
    });

    test('senza coordinate: percorso verso l\'indirizzo in chiaro', () {
      final uri = NavigazioneService.uriPercorsoIndirizzo(const Address(
          street: 'VIA TRIESTE', streetNumber: '40', city: 'ANCONA'))!;
      expect(uri.queryParameters['destination'], contains('VIA TRIESTE 40'));
      expect(uri.queryParameters['destination'], contains('ANCONA'));
    });

    test('le coordinate del backend vincono sull\'indirizzo', () {
      final uri = NavigazioneService.uriPercorsoIndirizzo(const Address(
          street: 'VIA TRIESTE', city: 'ANCONA', latitude: 43.6, longitude: 13.5))!;
      expect(uri.queryParameters['destination'], '43.6,13.5');
    });

    test('niente posizione né indirizzo: nessun link', () {
      expect(NavigazioneService.uriPercorso(), isNull);
      expect(NavigazioneService.uriPercorsoIndirizzo(const Address()), isNull);
    });
  });

  group('schermata mappa', () {
    Future<void> apri(WidgetTester t, List<MapPoint> punti) async {
      await t.binding.setSurfaceSize(const Size(1000, 1600));
      await t.pumpWidget(ProviderScope(
        overrides: [
          mapPointsProvider.overrideWith((ref) async => punti),
          mapMissingCountProvider.overrideWith((ref) async => 0),
          ricercaIndirizziProvider.overrideWithValue(_RicercaFinta()),
          reteVivaProvider.overrideWith((ref) async => ReteViva.vuota),
        ],
        child: const MaterialApp(home: MapScreen()),
      ));
      await t.pump();
      await t.pump();
    }

    List<String> urlTessere(WidgetTester t) => t
        .widgetList<TileLayer>(find.byType(TileLayer))
        .map((l) => l.urlTemplate!)
        .toList();

    Finder segnapostoSullaMappa() => find.descendant(
        of: find.byType(MarkerClusterLayerWidget),
        matching: find.byType(Segnaposto));

    Future<void> cerca(WidgetTester t, String testo) async {
      await t.tap(find.byType(TextField));
      await t.enterText(find.byType(TextField), testo);
      await t.pump(const Duration(milliseconds: 400));
      await t.pump();
    }

    testWidgets('fondo di default: grigio chiaro Esri + attribuzione',
        (t) async {
      await apri(t, [_odl('1', WorkOrderStatus.ricevuto)]);
      expect(urlTessere(t), [
        'https://services.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Light_Gray_Base/MapServer/tile/{z}/{y}/{x}',
        'https://services.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Light_Gray_Reference/MapServer/tile/{z}/{y}/{x}',
      ]);
      expect(find.text('Esri, © OpenStreetMap contributors'), findsOneWidget);
    });

    testWidgets('scelta del fondo: 4 mappe, satellite con vie e nomi',
        (t) async {
      await apri(t, [_odl('1', WorkOrderStatus.ricevuto)]);
      await t.tap(find.byTooltip('Fondo mappa'));
      await t.pumpAndSettle();
      for (final f in FondoMappa.values) {
        expect(find.text(f.label), findsOneWidget);
      }
      await t.tap(find.text('Satellite'));
      await t.pumpAndSettle();
      final urls = urlTessere(t);
      expect(urls, hasLength(3));
      expect(urls[0], contains('World_Imagery'));
      expect(urls[1], contains('Reference/World_Transportation'));
      expect(urls[2], contains('Reference/World_Boundaries_and_Places'));
    });

    testWidgets('fondo stradale e topografico', (t) async {
      await apri(t, [_odl('1', WorkOrderStatus.ricevuto)]);
      for (final (label, servizio) in [
        ('Stradale', 'World_Street_Map'),
        ('Topografico', 'World_Topo_Map'),
      ]) {
        await t.tap(find.byTooltip('Fondo mappa'));
        await t.pumpAndSettle();
        await t.tap(find.text(label));
        await t.pumpAndSettle();
        expect(urlTessere(t).single, contains(servizio));
      }
    });

    testWidgets('comandi flottanti presenti', (t) async {
      await apri(t, [_odl('1', WorkOrderStatus.ricevuto)]);
      for (final tip in [
        'Fondo mappa',
        'Legenda',
        'Centra sulla mia posizione',
        'Inquadra tutti gli interventi',
        'Avvicina',
        'Allontana',
      ]) {
        expect(find.byTooltip(tip), findsOneWidget, reason: tip);
      }
    });

    testWidgets('legenda: si apre col pulsante, stati e forme', (t) async {
      await apri(t, [_odl('1', WorkOrderStatus.ricevuto)]);
      expect(find.text('LEGENDA'), findsNothing);
      await t.tap(find.byTooltip('Legenda'));
      await t.pump();
      expect(find.text('LEGENDA'), findsOneWidget);
      expect(find.text('Ordine'), findsOneWidget);
      expect(find.text('Avviso'), findsOneWidget);
      expect(find.text('Posizione da indirizzo (approssimativa)'),
          findsOneWidget);
      expect(find.text('Più interventi vicini'), findsOneWidget);
    });

    testWidgets('il filtro vale anche per gli avvisi', (t) async {
      await apri(t, [
        _odl('1', WorkOrderStatus.ricevuto),
        _odl('2', WorkOrderStatus.inEsecuzione),
        _avviso('400'),
      ]);
      expect(find.text('3 sulla mappa'), findsOneWidget);

      await t.tap(find.text('In esecuzione').first);
      await t.pump();
      // OdL 2 e l'avviso in lavorazione.
      expect(find.text('2 sulla mappa'), findsOneWidget);
    });

    testWidgets('segnaposto: cerchio per l\'ordine, quadrato per l\'avviso',
        (t) async {
      await apri(t, [_odl('1', WorkOrderStatus.ricevuto), _avviso('400')]);
      final segni = t.widgetList<Segnaposto>(find.byType(Segnaposto)).toList();
      final ordine = segni.firstWhere(
          (s) => !s.avviso && s.colore == StatoMappa.assegnato.colore);
      final avviso = segni.firstWhere(
          (s) => s.avviso && s.colore == StatoMappa.inEsecuzione.colore);
      expect(ordine.approssimativa, isTrue);
      expect(avviso.approssimativa, isFalse);
    });

    testWidgets('elenco: ogni intervento, e il tocco apre la scheda',
        (t) async {
      await apri(
          t, [_odl('50557247', WorkOrderStatus.ricevuto), _avviso('400')]);
      expect(find.text('Ordine 50557247'), findsOneWidget);
      expect(find.text('Perdita'), findsOneWidget);

      await t.tap(find.text('Ordine 50557247'));
      await t.pump();
      expect(find.text('Tipo ZA02  ·  Priorità: Programmato'), findsOneWidget);
      expect(find.text('Naviga'), findsOneWidget);
    });

    testWidgets('scheda dal segnaposto: tipo, priorità, approssimativa, Naviga',
        (t) async {
      await apri(t, [_odl('50557247', WorkOrderStatus.ricevuto)]);
      await t.tap(segnapostoSullaMappa().first);
      await t.pump();

      expect(find.text('50557247'), findsOneWidget);
      expect(find.text('Tipo ZA02  ·  Priorità: Programmato'), findsOneWidget);
      expect(find.textContaining('può essere approssimativa'), findsOneWidget);
      expect(find.text('Naviga'), findsOneWidget);
      expect(find.text('Apri dettaglio'), findsOneWidget);
    });

    testWidgets('ricerca: interventi corrispondenti e indirizzi Esri',
        (t) async {
      await apri(
          t, [_odl('50557247', WorkOrderStatus.ricevuto), _avviso('400')]);
      await cerca(t, 'trieste');

      expect(find.text('INTERVENTI'), findsOneWidget);
      expect(find.text('INDIRIZZI'), findsOneWidget);
      expect(find.text('Via Trieste, 60124, Ancona, ITA'), findsOneWidget);
      // L'OdL in via Trieste sì; l'avviso (corso Garibaldi) no.
      expect(find.textContaining('50557247 · VIA TRIESTE'), findsOneWidget);
      expect(find.textContaining('400 · CORSO GARIBALDI'), findsNothing);
    });

    testWidgets('scegliere un indirizzo mette il segnaposto di ricerca',
        (t) async {
      await apri(t, [_odl('1', WorkOrderStatus.ricevuto)]);
      await cerca(t, 'via trieste');
      await t.tap(find.text('Via Trieste, 60124, Ancona, ITA'));
      await t.pump();
      await t.pump();

      expect(find.byIcon(Icons.location_on_rounded), findsOneWidget);
      expect(find.text('INDIRIZZI'), findsNothing); // risultati chiusi
    });
  });

  group('pulsante Naviga dei dettagli', () {
    Future<void> apri(WidgetTester t, Address a) => t.pumpWidget(MaterialApp(
        home: Scaffold(body: NavigaButton(indirizzo: a))));

    testWidgets('con un indirizzo compare', (t) async {
      await apri(t, const Address(street: 'VIA TRIESTE', city: 'ANCONA'));
      expect(find.text('Naviga'), findsOneWidget);
    });

    testWidgets('senza indirizzo non compare', (t) async {
      await apri(t, const Address());
      expect(find.text('Naviga'), findsNothing);
    });
  });
}
