// Stato di rete (online/offline) basato sul rilevamento REALE della conetività
// (connectivity_plus), con la possibilità di forzare l'offline della UI
// per i test (impostazione "Modalità offline").

// NB: connectivity_plus rileva la presenza dell'interfaccia (WiFi/dati), non la
// raggiungibilità reale di internet. La resilienza agli errori di rete durante
// le chiamate è gestita, in aggiunta, dal repository (fallback in coda).

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityService {
  final ValueNotifier<bool> online = ValueNotifier<bool>(true);
  final _controller = StreamController<bool>.broadcast();
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _sub;

  bool _realOnline = true; // interfaccia di rete presente
  bool _manualOffline = false; // forzatura offline dalla UI (test)

  ConnectivityService() {
    _init();
  }

  Future<void> _init() async {
    try {
      _realOnline = _hasConnection(await _connectivity.checkConnectivity());
      _recompute();
    } catch (_) {
      print('Errore nel controllo della connetività'); // In caso di errore restiamo ottimisti (online): i fallback gestiscono.
    }
    _sub = _connectivity.onConnectivityChanged.listen((results) {
      _realOnline = _hasConnection(results);
      _recompute();
    });
  }

  bool _hasConnection(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  Stream<bool> get onStatusChange => _controller.stream;
  bool get isOnline => online.value;

  void _recompute() {
    final effective = _realOnline && !_manualOffline;
    if (online.value == effective) return;
    online.value = effective;
    _controller.add(effective);
  }

  /// Dalla UI: `value == false` forza l'offline (test); `value == true` rimuove
  /// la forzatura e torna a seguire lo stato reale della rete.
  void setOnline(bool value) {
    _manualOffline = !value;
    _recompute();
  }

  void toggle() => setOnline(!isOnline);

  void dispose() {
    _sub?.cancel();
    _controller.close();
    online.dispose();
  }
}
