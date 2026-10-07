// Giacenze dei materiali per magazzino, quando il backend non le dà.
//
// /anagrafica/materials manda UN solo stock per materiale (nel suo magazzino
// predefinito). Il file assets/anagrafica/giacenze_magazzini.json, generato da
// tools/anagrafica/genera_giacenze.py dai dati di anagrafiche.json, completa
// gli altri magazzini perché ogni materiale si possa prelevare da più di uno.
// Se il backend manda `stockPerMagazzino`, quello vince e questo non si usa.

import 'dart:convert';

import 'package:flutter/services.dart';

import '../../domain/entities/entities.dart';

class GiacenzeMagazziniService {
  static const asset = 'assets/anagrafica/giacenze_magazzini.json';

  /// codice materiale -> (codice magazzino -> quantità)
  Future<Map<String, Map<String, num>>> carica() async {
    try {
      final d = jsonDecode(await rootBundle.loadString(asset)) as Map;
      return {
        for (final e in d.entries)
          '${e.key}': {
            for (final w in (e.value as Map).entries)
              '${w.key}': w.value as num,
          },
      };
    } catch (_) {
      return const {}; // senza il file: resta lo stock unico del backend
    }
  }

  /// I materiali con le giacenze per magazzino: quelle del backend se ci sono,
  /// altrimenti quelle del file.
  static List<MaterialItem> completa(
          List<MaterialItem> materiali, Map<String, Map<String, num>> file) =>
      [
        for (final m in materiali)
          if (m.stockPerMagazzino.isEmpty && file[m.materialCode] != null)
            m.copyWith(stockPerMagazzino: file[m.materialCode])
          else
            m,
      ];
}
