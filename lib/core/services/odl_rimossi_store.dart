// OdL eliminati dal tecnico su questo tablet.
//
// Ciò che l'operatore elimina sul tablet si elimina SOLO sul tablet: il
// backend non cancella gli ordini (DELETE /work-orders/:id risponde 501) e
// continua a elencarli in GET /work-orders. Il tablet ricorda quali ha
// eliminato e non li mostra più, anche dopo un aggiornamento o un riavvio.
// L'ordine resta intatto sul cruscotto e per gli altri tecnici.
//
// Stesso schema di AvvisiRimossiStore: box Hive di stringhe con copia in memoria.

import 'package:hive_flutter/hive_flutter.dart';

class OdlRimossiStore {
  OdlRimossiStore._();

  static Box<String>? _box;
  static final Map<String, String> _mem = {};

  static String chiave(String codice) => codice.trim().toUpperCase();

  /// Apre l'archivio su disco e ricarica quanto salvato. [hivePath] serve ai test.
  static Future<void> open({String? hivePath}) async {
    try {
      if (hivePath == null) {
        await Hive.initFlutter();
      } else {
        Hive.init(hivePath);
      }
      _box = await Hive.openBox<String>('odl_rimossi');
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

  static bool contiene(String codice) => _mem.containsKey(chiave(codice));

  static Future<void> rimuovi(String codice) async {
    final k = chiave(codice);
    if (k.isEmpty) return;
    final quando = DateTime.now().toIso8601String();
    _mem[k] = quando;
    try {
      await _box?.put(k, quando);
    } catch (_) {/* resta in memoria */}
  }

  /// Toglie dall'elenco gli OdL già eliminati.
  static List<T> filtra<T>(List<T> ordini, String Function(T) codice) =>
      ordini.where((o) => !contiene(codice(o))).toList();
}
