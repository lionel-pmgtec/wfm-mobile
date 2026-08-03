//
// Serve perché SAP trasmette l'indirizzo di intervento (INDIRIZZO_LAVORO) ma
// lascia vuoti LATITUDINE e LONGITUDINE: senza questa conversione nessun
// oggetto potrebbe comparire sulla mappa.
//
// Sorgente: Nominatim (OpenStreetMap), lo stesso servizio usato dal cruscotto.
// Regole d'uso rispettate: User-Agent identificativo, al massimo una richiesta
// al secondo, e cache persistente per non richiedere due volte lo stesso
// indirizzo (le coordinate di una via non cambiano).

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../domain/entities/value_objects.dart';

class GeoPoint {
  final double latitude;
  final double longitude;
  const GeoPoint(this.latitude, this.longitude);
}

class GeocodingService {
  GeocodingService._();
  static final GeocodingService instance = GeocodingService._();

  static const String _boxName = 'geocode_cache';
  static const String _endpoint = 'https://nominatim.openstreetmap.org/search';

  /// Nominatim chiede un massimo di una richiesta al secondo.
  static const Duration _minInterval = Duration(milliseconds: 1100);

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: const {'User-Agent': 'WFM-Mobile/1.0 (Viva Servizi)'},
  ));

  Box<String>? _box;
  final Map<String, GeoPoint?> _memoria = {};
  Future<void>? _initFuture;
  DateTime? _ultimaRichiesta;

  Future<void> _ensureInit() => _initFuture ??= _init();

  Future<void> _init() async {
    try {
      await Hive.initFlutter();
      _box = await Hive.openBox<String>(_boxName);
    } catch (_) {
      _box = null;
    }
  }

  /// Chiave di cache: l'indirizzo normalizzato.
  String _chiave(Address a) => [
        a.street.trim(),
        a.streetNumber.trim(),
        a.cap.trim(),
        a.city.trim(),
        a.localita.trim(),
        a.provincia.trim(),
      ].where((s) => s.isNotEmpty).join('|').toUpperCase();

  /// Un indirizzo è geocodificabile solo se ha almeno via o comune.
  static bool isGeocodable(Address a) =>
      a.street.trim().isNotEmpty ||
      a.city.trim().isNotEmpty ||
      a.localita.trim().isNotEmpty;

  /// Coordinate dell'indirizzo. Ritorna `null` se non trovate.
  /// Se l'indirizzo porta già le coordinate da SAP, quelle vincono.
  Future<GeoPoint?> resolve(Address address) async {
    if (address.hasCoordinates) {
      return GeoPoint(address.latitude!, address.longitude!);
    }
    if (!isGeocodable(address)) return null;

    await _ensureInit();
    final chiave = _chiave(address);
    if (chiave.isEmpty) return null;

    // 1) memoria di processo
    if (_memoria.containsKey(chiave)) return _memoria[chiave];

    // 2) cache su disco (anche i "non trovato", per non riprovare all'infinito)
    final salvato = _box?.get(chiave);
    if (salvato != null) {
      final punto = _decodifica(salvato);
      _memoria[chiave] = punto;
      return punto;
    }

    // 3) interrogazione della rete, con il ritmo consentito
    final punto = await _interroga(address);
    _memoria[chiave] = punto;
    await _box?.put(
      chiave,
      punto == null
          ? 'null'
          : jsonEncode({'lat': punto.latitude, 'lon': punto.longitude}),
    );
    return punto;
  }

  GeoPoint? _decodifica(String raw) {
    if (raw == 'null') return null;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      return GeoPoint((j['lat'] as num).toDouble(), (j['lon'] as num).toDouble());
    } catch (_) {
      return null;
    }
  }

  Future<GeoPoint?> _interroga(Address a) async {
    await _attendiTurno();
    try {
      final via = [a.street.trim(), a.streetNumber.trim()]
          .where((s) => s.isNotEmpty)
          .join(' ');
      final comune = a.city.trim().isNotEmpty ? a.city.trim() : a.localita.trim();

      final r = await _dio.get(_endpoint, queryParameters: {
        'format': 'jsonv2',
        'limit': 1,
        'countrycodes': 'it',
        if (via.isNotEmpty) 'street': via,
        if (comune.isNotEmpty) 'city': comune,
        if (a.cap.trim().isNotEmpty) 'postalcode': a.cap.trim(),
        if (a.provincia.trim().isNotEmpty) 'state': a.provincia.trim(),
      });

      final lista = r.data;
      if (lista is List && lista.isNotEmpty) {
        final primo = lista.first as Map<String, dynamic>;
        final lat = double.tryParse('${primo['lat']}');
        final lon = double.tryParse('${primo['lon']}');
        if (lat != null && lon != null) return GeoPoint(lat, lon);
      }
    } catch (_) {
      // Rete assente o servizio non raggiungibile: l'oggetto resta senza
      // posizione, senza bloccare la mappa.
    }
    return null;
  }

  /// Distanzia le richieste per rispettare il limite del servizio.
  Future<void> _attendiTurno() async {
    final ora = DateTime.now();
    final ultima = _ultimaRichiesta;
    if (ultima != null) {
      final trascorso = ora.difference(ultima);
      if (trascorso < _minInterval) {
        await Future<void>.delayed(_minInterval - trascorso);
      }
    }
    _ultimaRichiesta = DateTime.now();
  }
}
