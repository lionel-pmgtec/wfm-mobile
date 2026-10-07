// Archivio delle impostazioni dell'app (Impostazioni): sopravvivono al riavvio.
//
// Stesso schema di ArrivalStore: un box Hive di stringhe, con una copia in
// memoria per leggere in modo sincrono all'avvio del provider. Se il disco non
// è disponibile l'app continua a funzionare con le impostazioni in memoria.

import 'package:hive_flutter/hive_flutter.dart';

class ImpostazioniStore {
  ImpostazioniStore._();

  static Box<String>? _box;
  static final Map<String, String> _mem = {};

  /// Apre l'archivio su disco e ricarica quanto salvato. [hivePath] serve ai test.
  static Future<void> open({String? hivePath}) async {
    try {
      if (hivePath == null) {
        await Hive.initFlutter();
      } else {
        Hive.init(hivePath);
      }
      _box = await Hive.openBox<String>('app_settings');
      _mem
        ..clear()
        ..addEntries(_box!.keys.map((k) => MapEntry('$k', _box!.get(k) ?? '')));
    } catch (_) {
      _box = null; // solo in memoria
    }
  }

  /// Solo per i test: svuota lo stato in memoria e scollega il box.
  static void resetForTests() {
    _mem.clear();
    _box = null;
  }

  static String? leggi(String chiave) => _mem[chiave];

  static Future<void> scrivi(Map<String, String> valori) async {
    _mem.addAll(valori);
    try {
      await _box?.putAll(valori);
    } catch (_) {/* resta in memoria */}
  }
}
