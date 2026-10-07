// Lettura dei livelli della rete Viva Servizi (FeatureServer ArcGIS REST).
//
// Si interroga solo la zona visibile (`query` con envelope in WGS84) e si
// chiedono tutti i campi: i nomi dei campi non li conosciamo finché il
// servizio è protetto, quindi la scheda mostra quello che il servizio manda,
// con le etichette (alias) del livello. Nessun campo inventato.

import 'package:dio/dio.dart';

import '../config/rete_arcgis_config.dart';

/// Un punto della rete (contatore, riduttore…) con i suoi attributi ArcGIS.
class ElementoRete {
  final StratoRete strato;
  final double lat;
  final double lng;

  /// Attributi così come li manda il servizio (nome campo -> valore).
  final Map<String, Object?> attributi;

  const ElementoRete({
    required this.strato,
    required this.lat,
    required this.lng,
    required this.attributi,
  });

  /// Identificativo del punto nel livello (OBJECTID), se c'è.
  String get id {
    for (final e in attributi.entries) {
      final k = e.key.toLowerCase();
      if ((k == 'objectid' || k == 'fid' || k == 'oid') && e.value != null) {
        return '${strato.name}-${e.value}';
      }
    }
    return '${strato.name}-$lat,$lng';
  }

  /// La matricola, se il livello ha un campo che la contiene. Si riconosce
  /// dal NOME del campo ("matricola", "numero di serie"): se non c'è, null.
  String? get matricola {
    for (final e in attributi.entries) {
      final k = e.key.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
      final v = '${e.value ?? ''}'.trim();
      if (v.isEmpty) continue;
      if (k.contains('matricola') ||
          k.contains('numeroserie') ||
          k.contains('nserie') ||
          k == 'serie') {
        return v;
      }
    }
    return null;
  }
}

/// Descrizione del livello: etichette dei campi e campo "titolo".
class SchemaStrato {
  final Map<String, String> alias;
  final String? campoTitolo;
  const SchemaStrato({this.alias = const {}, this.campoTitolo});

  String etichetta(String campo) => alias[campo] ?? campo;
}

/// Il servizio ha rifiutato l'accesso (token assente, scaduto o non valido).
class ReteNonAccessibile implements Exception {
  final String messaggio;
  const ReteNonAccessibile(this.messaggio);
  @override
  String toString() => messaggio;
}

class ReteArcgisService {
  ReteArcgisService({
    Dio? dio,
    this.servizio = ReteArcgisConfig.servizio,
    this.token = ReteArcgisConfig.token,
  }) : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 20),
            ));

  final Dio _dio;
  final String servizio;
  final String token;
  final Map<StratoRete, SchemaStrato> _schemi = {};

  bool get attivo => token.isNotEmpty;

  /// ArcGIS risponde 200 anche agli errori, con `{error: {code, message}}`.
  Map<String, dynamic> _verifica(Object? data) {
    if (data is! Map<String, dynamic>) {
      throw const ReteNonAccessibile('Risposta del servizio ArcGIS non valida.');
    }
    final err = data['error'];
    if (err is Map) {
      final code = err['code'];
      if (code == 498 || code == 499 || code == 403) {
        throw ReteNonAccessibile(
            'Accesso ai livelli ArcGIS rifiutato ($code): token assente o scaduto.');
      }
      throw ReteNonAccessibile('Errore ArcGIS ${code ?? ''}: ${err['message']}');
    }
    return data;
  }

  Future<SchemaStrato> schema(StratoRete s) async {
    final noto = _schemi[s];
    if (noto != null) return noto;
    final r = await _dio.get('$servizio/${s.layerId}',
        queryParameters: {'f': 'json', 'token': token});
    final d = _verifica(r.data);
    final alias = <String, String>{
      for (final f in (d['fields'] as List? ?? const []))
        if (f is Map && f['name'] != null)
          '${f['name']}': '${f['alias'] ?? f['name']}',
    };
    final schema = SchemaStrato(
        alias: alias, campoTitolo: d['displayField'] as String?);
    _schemi[s] = schema;
    return schema;
  }

  /// Punti del livello dentro il rettangolo (gradi WGS84).
  Future<List<ElementoRete>> nellaZona(
    StratoRete s, {
    required double sud,
    required double ovest,
    required double nord,
    required double est,
    int massimo = 400,
  }) async {
    if (!attivo) return const [];
    final r = await _dio.get('$servizio/${s.layerId}/query', queryParameters: {
      'where': '1=1',
      'geometry': '$ovest,$sud,$est,$nord',
      'geometryType': 'esriGeometryEnvelope',
      'inSR': 4326,
      'spatialRel': 'esriSpatialRelIntersects',
      'outFields': '*',
      'returnGeometry': true,
      'outSR': 4326,
      'resultRecordCount': massimo,
      'f': 'json',
      'token': token,
    });
    final d = _verifica(r.data);
    final out = <ElementoRete>[];
    for (final f in (d['features'] as List? ?? const [])) {
      if (f is! Map) continue;
      final g = f['geometry'];
      if (g is! Map || g['x'] is! num || g['y'] is! num) continue;
      out.add(ElementoRete(
        strato: s,
        lat: (g['y'] as num).toDouble(),
        lng: (g['x'] as num).toDouble(),
        attributi: Map<String, Object?>.from(
            (f['attributes'] as Map?) ?? const <String, Object?>{}),
      ));
    }
    return out;
  }
}
