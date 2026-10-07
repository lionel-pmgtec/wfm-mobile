// Quando un OdL / avviso è arrivato SUL TABLET.
//
// Il backend non manda l'ora di arrivo (di un oggetto SAP arriva solo la data di
// creazione, senza ora). Si registra quindi qui la prima volta che il tablet lo
// vede: serve a mostrare le novità in cima alla lista e a scrivere "2 min fa".


import 'package:hive_flutter/hive_flutter.dart';

class ArrivalStore {
  ArrivalStore._();

  static Box<String>? _box;
  static final Map<String, String> _mem = {};
  static const _base = 'base';

  /// Apre l'archivio su disco e ricarica quanto salvato. [hivePath] serve ai test.
  static Future<void> open({String? hivePath}) async {
    if (hivePath == null) {
      await Hive.initFlutter();
    } else {
      Hive.init(hivePath);
    }
    _box = await Hive.openBox<String>('local_arrivals');
    _mem
      ..clear()
      ..addEntries(_box!.keys.map((k) => MapEntry('$k', _box!.get(k) ?? '')));
  }

  /// Solo per i test: svuota lo stato in memoria e scollega il box.
  static void resetForTests() {
    _mem.clear();
    _box = null;
  }

  static String _k(String kind, String code) => '$kind:$code';

  /// Ora di arrivo sul tablet; null se non nota (oggetto già presente al primo
  /// caricamento, o mai visto).
  static DateTime? of(String kind, String code) {
    final v = _mem[_k(kind, code)];
    if (v == null || v == _base) return null;
    return DateTime.tryParse(v);
  }

  static Future<void> _put(Map<String, String> entries) async {
    if (entries.isEmpty) return;
    _mem.addAll(entries);
    try {
      await _box?.putAll(entries);
    } catch (_) {
      // Un errore di scrittura non deve toccare la lista: resta valido in memoria.
    }
  }

  /// Registra i codici di un elenco appena ricevuto dal backend. I nuovi
  /// risultano arrivati ORA; se è il primo elenco in assoluto per questo tipo,
  /// fanno da riferimento (nessuna ora).
  static Future<void> seen(String kind, Iterable<String> codes) async {
    final init = '_init:$kind';
    final first = !_mem.containsKey(init);
    final now = DateTime.now().toIso8601String();
    final out = <String, String>{if (first) init: _base};
    for (final c in codes) {
      final key = _k(kind, c);
      if (!_mem.containsKey(key)) out[key] = first ? _base : now;
    }
    await _put(out);
  }

  /// Un oggetto nato sul tablet (o appena arrivato): risulta arrivato ORA.
  static Future<void> arrivedNow(String kind, String code) =>
      _put({_k(kind, code): DateTime.now().toIso8601String()});

  /// Ordina dal più recente: prima chi ha un'ora di arrivo (decrescente), poi gli
  /// altri nell'ordine originale. Ordinamento stabile.
  static List<T> sortNewestFirst<T>(
      List<T> items, String kind, String Function(T) code) {
    final dec = [
      for (var i = 0; i < items.length; i++)
        (i: i, t: of(kind, code(items[i])), v: items[i])
    ];
    dec.sort((a, b) {
      if (a.t != null && b.t != null) {
        final c = b.t!.compareTo(a.t!);
        return c != 0 ? c : a.i.compareTo(b.i);
      }
      if (a.t != null) return -1;
      if (b.t != null) return 1;
      return a.i.compareTo(b.i);
    });
    return [for (final d in dec) d.v];
  }
}

/// "adesso", "12 sec fa", "5 min fa", "3 h fa", "2 g fa".
String formatTempoFa(Duration d) {
  final s = d.inSeconds < 0 ? 0 : d.inSeconds;
  if (s < 2) return 'adesso';
  if (s < 60) return '$s sec fa';
  if (s < 3600) return '${s ~/ 60} min fa';
  if (s < 86400) return '${s ~/ 3600} h fa';
  return '${s ~/ 86400} g fa';
}
