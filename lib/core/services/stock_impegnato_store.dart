// Quantità di materiale PRELEVATE dal tecnico su questo tablet, per magazzino.
//
// Il backend dà la giacenza di ogni materiale ma non la scala quando arriva
// l'esito (POST /esiti salva solo le righe usate). Il tablet tiene quindi il
// conto di ciò che ha prelevato, separatamente per ogni magazzino: la giacenza
// mostrata = giacenza del backend - quanto già prelevato da QUEL magazzino.
// Prelevare dal Magazzino 1 non tocca mai la giacenza del Magazzino 2.
//
// Stesso schema degli altri archivi: box Hive di stringhe con copia in memoria.

import 'package:hive_flutter/hive_flutter.dart';

class StockImpegnatoStore {
  StockImpegnatoStore._();

  static Box<String>? _box;
  static final Map<String, num> _mem = {};

  static String _k(String materiale, String magazzino) =>
      '${materiale.trim().toUpperCase()}|${magazzino.trim().toUpperCase()}';

  /// Apre l'archivio su disco e ricarica quanto salvato. [hivePath] serve ai test.
  static Future<void> open({String? hivePath}) async {
    try {
      if (hivePath == null) {
        await Hive.initFlutter();
      } else {
        Hive.init(hivePath);
      }
      _box = await Hive.openBox<String>('stock_impegnato');
      _mem
        ..clear()
        ..addEntries(_box!.keys.map((k) =>
            MapEntry('$k', num.tryParse(_box!.get(k) ?? '') ?? 0)));
    } catch (_) {
      _box = null; // solo in memoria
    }
  }

  /// Solo per i test: svuota lo stato in memoria e scollega il box.
  static void resetForTests() {
    _mem.clear();
    _box = null;
  }

  /// Quanto è già stato prelevato da [magazzino] per [materiale].
  static num impegnato(String materiale, String magazzino) =>
      _mem[_k(materiale, magazzino)] ?? 0;

  static Future<void> _scrivi(String k, num valore) async {
    if (valore <= 0) {
      _mem.remove(k);
      try {
        await _box?.delete(k);
      } catch (_) {}
    } else {
      _mem[k] = valore;
      try {
        await _box?.put(k, '$valore');
      } catch (_) {}
    }
  }

  /// Registra un prelievo: scala SOLO il magazzino indicato.
  static Future<void> impegna(String materiale, String magazzino, num qta) =>
      _scrivi(_k(materiale, magazzino), impegnato(materiale, magazzino) + qta);

  /// Restituisce al magazzino una quantità non più usata.
  static Future<void> rilascia(String materiale, String magazzino, num qta) =>
      _scrivi(_k(materiale, magazzino), impegnato(materiale, magazzino) - qta);

  /// Giacenza residua di un magazzino (mai negativa).
  static num residuo(num giacenzaBackend, String materiale, String magazzino) {
    final r = giacenzaBackend - impegnato(materiale, magazzino);
    return r < 0 ? 0 : r;
  }
}
