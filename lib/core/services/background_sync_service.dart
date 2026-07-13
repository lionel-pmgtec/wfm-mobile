// Sincronizzazione periodica in background — STUB (scheduler disabilitato).
//
// Il plugin `workmanager` 0.5.2 non è compatibile con l'embedding Android v2
// delle versioni recenti di Flutter (la build Android fallisce nel plugin
// Kotlin: shim/registerWith/PluginRegistrantCallback rimossi). Il task
// periodico era comunque un NO-OP finché il middleware non è collegato, quindi
// è stato rimosso per sbloccare la build. Questo stub mantiene l'API
// (initialize / cancel) così `main.dart` e i futuri chiamanti restano invariati.
//
// TODO(backend): quando il middleware sarà disponibile, reintrodurre uno
// scheduler compatibile (workmanager >= 0.6 con embedding v2, oppure
// android_alarm_manager_plus) e implementare qui il retry della coda offline:
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

  /// Placeholder: nessuno scheduler di background registrato (vedi nota sopra).
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
