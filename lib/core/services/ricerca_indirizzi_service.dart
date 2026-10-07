// Ricerca di indirizzi e luoghi per la mappa ("Trova indirizzo o luogo").
//
// Servizio: ArcGIS World Geocoding (geocode.arcgis.com), lo stesso fornitore
// della mappa di base. `suggest` propone mentre si scrive, poi
// `findAddressCandidates` (con il magicKey del suggerimento) dà la posizione.
// Solo per mostrare il risultato sulla mappa: niente viene salvato.
// `reverseGeocode` fa il contrario: dal punto toccato sulla mappa all'indirizzo
// (via, civico, comune, CAP), per precompilare un OdL o un avviso.

import 'package:dio/dio.dart';

import '../router/app_routes.dart';

/// Indirizzo di un punto della mappa (geocodifica inversa).
class IndirizzoPunto {
  /// Etichetta completa, es. "Via Trieste 40, 60124, Ancona".
  final String etichetta;
  final IndirizzoMappa indirizzo;
  const IndirizzoPunto(this.etichetta, this.indirizzo);
}

class SuggerimentoIndirizzo {
  final String testo;
  final String magicKey;
  const SuggerimentoIndirizzo(this.testo, this.magicKey);
}

class LuogoTrovato {
  final String indirizzo;
  final double lat;
  final double lng;
  const LuogoTrovato(this.indirizzo, this.lat, this.lng);
}

class RicercaIndirizziService {
  RicercaIndirizziService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
            ));

  static final RicercaIndirizziService instance = RicercaIndirizziService();

  static const _base =
      'https://geocode.arcgis.com/arcgis/rest/services/World/GeocodeServer';

  final Dio _dio;

  /// Suggerimenti mentre si scrive, in Italia e vicino al punto indicato.
  Future<List<SuggerimentoIndirizzo>> suggerisci(String testo,
      {double? lat, double? lng}) async {
    final t = testo.trim();
    if (t.length < 3) return const [];
    try {
      final r = await _dio.get('$_base/suggest', queryParameters: {
        'text': t,
        'countryCode': 'ITA',
        'maxSuggestions': 6,
        if (lat != null && lng != null) 'location': '$lng,$lat',
        'f': 'json',
      });
      final lista = (r.data is Map ? r.data['suggestions'] : null) as List?;
      return [
        for (final s in lista ?? const [])
          if (s is Map && s['isCollection'] != true)
            SuggerimentoIndirizzo('${s['text']}', '${s['magicKey']}'),
      ];
    } catch (_) {
      // Rete assente o servizio non raggiungibile: nessun suggerimento.
      return const [];
    }
  }

  /// Posizione di un suggerimento scelto. Null se non trovata.
  Future<LuogoTrovato?> localizza(SuggerimentoIndirizzo s) async {
    try {
      final r = await _dio.get('$_base/findAddressCandidates', queryParameters: {
        'SingleLine': s.testo,
        'magicKey': s.magicKey,
        'maxLocations': 1,
        'outSR': 4326,
        'f': 'json',
      });
      final candidati = (r.data is Map ? r.data['candidates'] : null) as List?;
      if (candidati == null || candidati.isEmpty) return null;
      final c = candidati.first as Map;
      final loc = c['location'] as Map;
      return LuogoTrovato(
        '${c['address']}',
        (loc['y'] as num).toDouble(),
        (loc['x'] as num).toDouble(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Indirizzo del punto (lat/lng in gradi). Null se lì non c'è un indirizzo
  /// (mare, campagna senza vie) o se il servizio non risponde.
  Future<IndirizzoPunto?> indirizzoDi(double lat, double lng) async {
    try {
      final r = await _dio.get('$_base/reverseGeocode', queryParameters: {
        'location': '$lng,$lat',
        'langCode': 'ITA',
        'outSR': 4326,
        'f': 'json',
      });
      final a = (r.data is Map ? r.data['address'] : null);
      if (a is! Map) return null;
      String campo(String k) => '${a[k] ?? ''}'.trim();
      final comune = campo('City');
      final completo = campo('Address'); // "Via Trieste 40"
      if (comune.isEmpty || completo.isEmpty) return null;
      final civico = campo('AddNum');
      final via = civico.isNotEmpty && completo.endsWith(' $civico')
          ? completo.substring(0, completo.length - civico.length - 1)
          : completo;
      return IndirizzoPunto(
        campo('Match_addr').isEmpty ? '$completo, $comune' : campo('Match_addr'),
        IndirizzoMappa(
            via: via, civico: civico, comune: comune, cap: campo('Postal')),
      );
    } catch (_) {
      return null;
    }
  }
}
