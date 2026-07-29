
//
// TODO(backend):  reintrodurre uno scheduler compatibile (workmanager >= 0.6 con embedding v2, oppure
// android_alarm_manager_plus) e implementare il retry della coda offline:
//   1. Apertura DB locale (Hive) sulla syncQueue
//   2. POST/PUT verso il middleware con token da secure storage
//   3. Rimozione dalla coda in caso di successo
//
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
