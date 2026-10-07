// Avvisi tolti dal tablet perché il loro OdL è stato chiuso.
//
// Chiudere un OdL lo fa sparire dal tablet; lo stesso deve succedere
// all'avviso associato. Il backend non permette di eliminare un avviso
// (DELETE /notifications/:id risponde 501) e continua a elencarlo in
// GET /notifications: quindi il tablet ricorda quali avvisi ha tolto e non li
// mostra più, anche dopo un aggiornamento o un riavvio.
//
// Stesso schema di ArrivalStore: box Hive di stringhe con copia in memoria.

import 'package:hive_flutter/hive_flutter.dart';

class AvvisiRimossiStore {
  AvvisiRimossiStore._();

  static Box<String>? _box;
  static final Map<String, String> _mem = {};

  /// SAP manda il numero a 12 cifre con gli zeri davanti: "400090003" e
  /// "000400090003" sono lo stesso avviso.
  static String chiave(String numero) =>
      numero.trim().replaceFirst(RegExp(r'^0+'), '').toUpperCase();

  /// Apre l'archivio su disco e ricarica quanto salvato. [hivePath] serve ai test.
  static Future<void> open({String? hivePath}) async {
    try {
      if (hivePath == null) {
        await Hive.initFlutter();
      } else {
        Hive.init(hivePath);
      }
      _box = await Hive.openBox<String>('avvisi_rimossi');
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

  static bool contiene(String numero) => _mem.containsKey(chiave(numero));

  static Future<void> rimuovi(String numero) async {
    final k = chiave(numero);
    if (k.isEmpty) return;
    final quando = DateTime.now().toIso8601String();
    _mem[k] = quando;
    try {
      await _box?.put(k, quando);
    } catch (_) {/* resta in memoria */}
  }

  /// Toglie dall'elenco gli avvisi già rimossi.
  static List<T> filtra<T>(List<T> avvisi, String Function(T) numero) =>
      avvisi.where((a) => !contiene(numero(a))).toList();
}
