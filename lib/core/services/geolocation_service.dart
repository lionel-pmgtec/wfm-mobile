// Servizio di geolocalizzazione (geolocator).
// Usato da: Play/Stop OdL, scatto foto (geotag), schermata mappa.

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../domain/entities/value_objects.dart';

class GeolocationService {
  GeolocationService._();
  static final GeolocationService instance = GeolocationService._();

  bool _denied = false;

  /// Verifica e richiede i permessi runtime. Restituisce true se ottenuti.
  Future<bool> ensurePermission() async {
    if (kIsWeb) return false;

    if (!await Geolocator.isLocationServiceEnabled()) {
      _denied = true;
      return false;
    }

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }

    final granted = perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse;
    _denied = !granted;
    return granted;
  }

  /// Posizione corrente. Restituisce null se permessi negati o GPS off.
  /// Non lancia eccezioni — sicuro da chiamare nei flussi lifecycle OdL.
  Future<Geolocation?> getCurrentPosition({
    LocationAccuracy accuracy = LocationAccuracy.high,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    if (kIsWeb) return null;
    if (_denied) {
      final ok = await ensurePermission();
      if (!ok) return null;
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: accuracy,
          timeLimit: timeout,
        ),
      );
      return Geolocation(
        latitude: pos.latitude,
        longitude: pos.longitude,
        accuracy: pos.accuracy,
        capturedAt: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Ultima posizione nota (più veloce, può essere stale).
  Future<Geolocation?> getLastKnownPosition() async {
    if (kIsWeb) return null;
    try {
      final pos = await Geolocator.getLastKnownPosition();
      if (pos == null) return null;
      return Geolocation(
        latitude: pos.latitude,
        longitude: pos.longitude,
        accuracy: pos.accuracy,
        capturedAt: pos.timestamp,
      );
    } catch (_) {
      return null;
    }
  }
}
