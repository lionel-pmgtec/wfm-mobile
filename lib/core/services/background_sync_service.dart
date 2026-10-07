
// La sincronizzazione in FOREGROUND (al ritorno della connettività e via la
// schermata "Coda di sincronizzazione" nelle Impostazioni) resta operativa.

import 'package:flutter/foundation.dart';

class BackgroundSyncService {
  BackgroundSyncService._();
  static final BackgroundSyncService instance = BackgroundSyncService._();

  bool _initialized = false;

  /// Placeholder: nessuno scheduler di background registrato.
  Future<void> initialize(
      {Duration frequency = const Duration(minutes: 15)}) async {
    if (kIsWeb || _initialized) return;
    _initialized = true;
  }

  /// Placeholder: nulla da annullare finché lo scheduler è disabilitato.
  Future<void> cancel() async {
    _initialized = false;
  }
}
