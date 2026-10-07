// Rete Viva Servizi disegnata sulla mappa (zona Ancona 60128): condotte,
// allacci, contatori, riduttori. Dai contatori e dai riduttori si creano OdL
// e avvisi con l'indirizzo e la posizione del punto.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wfm_mobile/core/config/rete_arcgis_config.dart';
import 'package:wfm_mobile/core/router/app_routes.dart';
import 'package:wfm_mobile/core/services/rete_viva_service.dart';
import 'package:wfm_mobile/presentation/features/map/map_screen.dart';
import 'package:wfm_mobile/presentation/providers/map_provider.dart';

/// Piccola rete al centro di default della mappa (43.615, 13.519).
const _geoJson = '''
{"type":"FeatureCollection","features":[
 {"type":"Feature","geometry":{"type":"LineString","coordinates":[[13.5180,43.6150],[13.5200,43.6150]]},
  "properties":{"tipo":"condotta","rete":"adduzione","materiale":"Acciaio 100","via":"Via Fermo"}},
 {"type":"Feature","geometry":{"type":"LineString","coordinates":[[13.5190,43.6150],[13.5190,43.6160]]},
  "properties":{"tipo":"condotta","rete":"distribuzione","materiale":"PEAD 90","via":"Via Beniamino Gigli"}},
 {"type":"Feature","geometry":{"type":"LineString","coordinates":[[13.5186,43.6153],[13.5186,43.6150]]},
  "properties":{"tipo":"allaccio"}},
 {"type":"Feature","geometry":{"type":"Point","coordinates":[13.5186,43.6153]},
  "properties":{"tipo":"contatore","id":"C0001","via":"Via Beniamino Gigli","civico":"12","cap":"60128","comune":"Ancona"}},
 {"type":"Feature","geometry":{"type":"Point","coordinates":[13.5195,43.6150]},
  "properties":{"tipo":"riduttore","codice":"AN04","via":"Via Fermo / Via Beniamino Gigli","comune":"Ancona"}}
]}''';

void main() {
  group('file della rete', () {
    final rete = ReteViva.daGeoJson(
        File(ReteVivaService.asset).readAsStringSync());

    test('condotte (adduzione e distribuzione), allacci, contatori, riduttori',
        () {
      expect(rete.condotte.length, greaterThan(100));
      expect(rete.condotte.where((c) => c.adduzione), isNotEmpty);
      expect(rete.condotte.where((c) => !c.adduzione), isNotEmpty);
      expect(rete.allacci.length, rete.contatori.length);
      expect(rete.contatori.length, greaterThan(300));
      expect(rete.riduttori, isNotEmpty);
    });

    test('ogni contatore ha un indirizzo (via, CAP, comune)', () {
      for (final c in rete.contatori) {
        final i = indirizzoElemento(c)!;
        expect(i.via, isNotEmpty);
        expect(i.comune, 'Ancona');
        expect(i.cap, matches(RegExp(r'^\d{5}$')));
      }
    });

    test('tutto nella zona di Ancona della mappa', () {
      for (final c in [...rete.contatori, ...rete.riduttori]) {
        expect(c.lat, inInclusiveRange(43.59, 43.61));
        expect(c.lng, inInclusiveRange(13.50, 13.52));
      }
    });

    test('identificativi univoci', () {
      final ids = [for (final c in rete.contatori) c.id];
      expect(ids.toSet().length, ids.length);
    });
  });

  test('lettura: tipi, attributi, etichetta dritta', () {
    final r = ReteViva.daGeoJson(_geoJson);
    expect(r.condotte, hasLength(2));
    expect(r.condotte.first.adduzione, isTrue);
    expect(r.condotte.first.materiale, 'Acciaio 100');
    expect(r.condotte.first.angolo, closeTo(0, 1e-9)); // tratto orizzontale
    expect(r.condotte.last.angolo.abs(), closeTo(1.5708, 1e-3)); // verticale
    expect(r.contatori.single.strato, StratoRete.misuratori);
    expect(r.contatori.single.attributi['Civico'], '12');
    expect(r.contatori.single.matricola, isNull); // nessuna matricola inventata
    expect(r.riduttori.single.attributi['Codice'], 'AN04');
  });

  group('mappa', () {
    Future<List<String>> apri(WidgetTester t) async {
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
          mapPointsProvider.overrideWith((ref) async => const []),
          mapMissingCountProvider.overrideWith((ref) async => 0),
          reteVivaProvider
              .overrideWith((ref) async => ReteViva.daGeoJson(_geoJson)),
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

    Finder punto(StratoRete s) =>
        find.byWidgetPredicate((w) => w is PuntoRete && w.strato == s);

    testWidgets('da lontano la rete non si disegna: invito ad avvicinarsi',
        (t) async {
      await apri(t);
      expect(find.byType(PolylineLayer), findsNothing);
      expect(punto(StratoRete.misuratori), findsNothing);
      expect(find.text('Avvicinati per vedere la rete e i contatori'),
          findsOneWidget);
    });

    testWidgets('da vicino: condotte, allacci, contatore e riduttore',
        (t) async {
      await apri(t);
      await avvicina(t, 3); // zoom 16
      final linee = t
          .widgetList<PolylineLayer>(find.byType(PolylineLayer))
          .expand((l) => l.polylines)
          .toList();
      expect(linee, hasLength(3)); // 2 condotte + 1 allaccio
      expect(linee.where((p) => p.pattern != const StrokePattern.solid()),
          hasLength(1)); // l'allaccio è tratteggiato
      expect(punto(StratoRete.misuratori), findsOneWidget);
      expect(punto(StratoRete.riduttori), findsOneWidget);
      expect(find.textContaining('Avvicinati'), findsNothing);
      // I materiali si leggono solo più da vicino.
      expect(find.text('PEAD 90'), findsNothing);
    });

    testWidgets('a zoom 17 materiali e codici dei riduttori', (t) async {
      await apri(t);
      await avvicina(t, 4);
      expect(find.text('PEAD 90'), findsOneWidget);
      expect(find.text('Acciaio 100'), findsOneWidget);
      expect(find.text('AN04'), findsOneWidget);
    });

    testWidgets('contatore: scheda con l\'indirizzo e "Crea OdL" SOST',
        (t) async {
      final aperti = await apri(t);
      await avvicina(t, 3);
      await t.tap(punto(StratoRete.misuratori));
      await t.pump();

      expect(find.text('CONTATORI'), findsOneWidget);
      expect(find.text('Via Beniamino Gigli'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('C0001'), findsNothing); // identificativo tecnico
      await t.tap(find.text('Crea OdL'));
      await t.pumpAndSettle();

      final q = Uri.parse(aperti.single).queryParameters;
      expect(q['type'], 'SOST');
      expect(q['via'], 'Via Beniamino Gigli');
      expect(q['civico'], '12');
      expect(q['cap'], '60128');
      expect(q['comune'], 'Ancona');
      expect(q['lat'], '43.6153');
      expect(q.containsKey('meter'), isFalse); // la matricola la mette il tecnico
    });

    testWidgets('contatore: "Crea avviso" con indirizzo e posizione',
        (t) async {
      final aperti = await apri(t);
      await avvicina(t, 3);
      await t.tap(punto(StratoRete.misuratori));
      await t.pump();
      await t.tap(find.text('Crea avviso'));
      await t.pumpAndSettle();

      final u = Uri.parse(aperti.single);
      expect(u.path, AppRoutes.createAvviso);
      expect(u.queryParameters['via'], 'Via Beniamino Gigli');
      expect(u.queryParameters['lng'], '13.5186');
    });

    testWidgets('riduttore: ZA02 col ciclo CONRID1, sulla prima via',
        (t) async {
      final aperti = await apri(t);
      await avvicina(t, 3);
      await t.tap(punto(StratoRete.riduttori));
      await t.pump();
      await t.tap(find.text('Crea OdL'));
      await t.pumpAndSettle();

      final q = Uri.parse(aperti.single).queryParameters;
      expect(q['type'], 'ZA02');
      expect(q['ciclo'], 'CONRID1');
      expect(q['via'], 'Via Fermo');
    });

    testWidgets('si spegne dal pannello', (t) async {
      await apri(t);
      await avvicina(t, 3);
      await t.tap(find.byTooltip('Fondo mappa'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(SwitchListTile, 'Rete idrica Viva Servizi'));
      await t.pumpAndSettle();
      await t.tapAt(const Offset(500, 100));
      await t.pumpAndSettle();
      expect(find.byType(PolylineLayer), findsNothing);
      expect(find.byType(PuntoRete), findsNothing);
    });

    testWidgets('toccando l\'invito si va sulla rete', (t) async {
      await apri(t);
      await t.tap(find.text('Avvicinati per vedere la rete e i contatori'));
      await t.pump();
      await t.pump();
      expect(punto(StratoRete.misuratori), findsOneWidget);
      expect(find.textContaining('Avvicinati'), findsNothing);
    });

    testWidgets('legenda della rete', (t) async {
      await apri(t);
      await t.tap(find.byTooltip('Legenda'));
      await t.pump();
      for (final v in [
        'Condotta di adduzione',
        'Condotta di distribuzione',
        'Allaccio',
        'Contatore',
        'Riduttore di pressione',
      ]) {
        expect(find.text(v), findsOneWidget, reason: v);
      }
    });
  });
}
