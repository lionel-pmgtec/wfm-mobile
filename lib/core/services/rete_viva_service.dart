// Rete Viva Servizi della mappa (zona Ancona 60128): condotte, allacci,
// contatori e riduttori di pressione.
//
// Il file assets/rete_viva/rete_viva_ancona.geojson è prodotto da
// tools/rete_viva/genera_rete_viva.py: vie ed edifici da OpenStreetMap,
// indirizzi da OSM o dalla geocodifica inversa Esri. Ogni contatore ha un
// indirizzo reale (via, civico, CAP, comune) su cui creare OdL e avvisi.

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

import '../config/rete_arcgis_config.dart';
import 'rete_arcgis_service.dart';

/// Tratto di condotta lungo una via.
class CondottaRete {
  final List<LatLng> punti;

  /// Rete di adduzione (rossa) o di distribuzione (verde).
  final bool adduzione;
  final String materiale;
  final String via;

  /// Dove scrivere il materiale (metà del tratto più lungo) e con che
  /// inclinazione (radianti, già "dritta" per la lettura).
  final LatLng etichetta;
  final double angolo;

  const CondottaRete({
    required this.punti,
    required this.adduzione,
    required this.materiale,
    required this.via,
    required this.etichetta,
    required this.angolo,
  });
}

class ReteViva {
  final List<CondottaRete> condotte;

  /// Allacci: dal contatore alla condotta.
  final List<List<LatLng>> allacci;
  final List<ElementoRete> contatori;
  final List<ElementoRete> riduttori;

  const ReteViva({
    this.condotte = const [],
    this.allacci = const [],
    this.contatori = const [],
    this.riduttori = const [],
  });

  static const vuota = ReteViva();

  bool get isEmpty => condotte.isEmpty && contatori.isEmpty;

  /// Legge il GeoJSON della rete.
  factory ReteViva.daGeoJson(String testo) {
    final d = jsonDecode(testo) as Map<String, dynamic>;
    final condotte = <CondottaRete>[];
    final allacci = <List<LatLng>>[];
    final contatori = <ElementoRete>[];
    final riduttori = <ElementoRete>[];

    LatLng ll(List c) =>
        LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble());

    for (final f in (d['features'] as List? ?? const [])) {
      if (f is! Map) continue;
      final p = Map<String, dynamic>.from(f['properties'] as Map? ?? const {});
      final g = f['geometry'] as Map?;
      final coord = g?['coordinates'];
      if (coord is! List) continue;
      String s(String k) => '${p[k] ?? ''}'.trim();
      switch (p['tipo']) {
        case 'condotta':
          final punti = [for (final c in coord) ll(c as List)];
          if (punti.length < 2) continue;
          final (pos, ang) = _posizioneEtichetta(punti);
          condotte.add(CondottaRete(
            punti: punti,
            adduzione: p['rete'] == 'adduzione',
            materiale: s('materiale'),
            via: s('via'),
            etichetta: pos,
            angolo: ang,
          ));
        case 'allaccio':
          allacci.add([for (final c in coord) ll(c as List)]);
        case 'contatore':
          final pt = ll(coord);
          contatori.add(ElementoRete(
            strato: StratoRete.misuratori,
            lat: pt.latitude,
            lng: pt.longitude,
            attributi: {
              'OBJECTID': s('id'),
              'Via': s('via'),
              'Civico': s('civico'),
              'CAP': s('cap'),
              'Comune': s('comune'),
            },
          ));
        case 'riduttore':
          final pt = ll(coord);
          riduttori.add(ElementoRete(
            strato: StratoRete.riduttori,
            lat: pt.latitude,
            lng: pt.longitude,
            attributi: {
              'OBJECTID': s('codice'),
              'Codice': s('codice'),
              'Via': s('via'),
              'Comune': s('comune'),
            },
          ));
      }
    }
    return ReteViva(
        condotte: condotte,
        allacci: allacci,
        contatori: contatori,
        riduttori: riduttori);
  }

  /// Metà del segmento più lungo e sua inclinazione sullo schermo.
  static (LatLng, double) _posizioneEtichetta(List<LatLng> punti) {
    var migliore = 0.0;
    var pos = punti.first;
    var ang = 0.0;
    final kx = math.cos(punti.first.latitude * math.pi / 180);
    for (var i = 0; i < punti.length - 1; i++) {
      final a = punti[i], b = punti[i + 1];
      final dx = (b.longitude - a.longitude) * kx;
      final dy = b.latitude - a.latitude;
      final l = dx * dx + dy * dy;
      if (l > migliore) {
        migliore = l;
        pos = LatLng((a.latitude + b.latitude) / 2,
            (a.longitude + b.longitude) / 2);
        // Sullo schermo la y cresce verso il basso.
        ang = math.atan2(-dy, dx);
      }
    }
    if (ang > math.pi / 2) ang -= math.pi;
    if (ang < -math.pi / 2) ang += math.pi;
    return (pos, ang);
  }
}

/// Indirizzo di un elemento della rete, dagli attributi (Via, Civico…).
({String via, String civico, String cap, String comune})? indirizzoElemento(
    ElementoRete e) {
  String a(String k) => '${e.attributi[k] ?? ''}'.trim();
  final via = a('Via');
  if (via.isEmpty) return null;
  return (via: via, civico: a('Civico'), cap: a('CAP'), comune: a('Comune'));
}

class ReteVivaService {
  static const asset = 'assets/rete_viva/rete_viva_ancona.geojson';

  Future<ReteViva> carica() async =>
      ReteViva.daGeoJson(await rootBundle.loadString(asset));
}
