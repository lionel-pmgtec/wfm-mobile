// Astrazione dello stato di rete (online/offline). Implementazione manuale per
// l'MVP front-end (commutabile dalla UI per testare la modalità offline).
//
// In produzione: collegare connectivity_plus per il rilevamento reale e
// scatenare la sincronizzazione automatica (specifiche EF-M11.3).

import 'dart:async';
import 'package:flutter/foundation.dart';

class ConnectivityService {
  final ValueNotifier<bool> online = ValueNotifier<bool>(true);
  final _controller = StreamController<bool>.broadcast();

  Stream<bool> get onStatusChange => _controller.stream;
  bool get isOnline => online.value;

  void setOnline(bool value) {
    if (online.value == value) return;
    online.value = value;
    _controller.add(value);
  }

  void toggle() => setOnline(!online.value);

  void dispose() {
    _controller.close();
    online.dispose();
  }
}
