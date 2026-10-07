// Lettura a voce alta (flutter_tts): voce, tono e velocità scelti in
// Impostazioni → Voce di lettura.
//
// Android non dice se una voce è maschile o femminile: si propongono le voci
// italiane installate sul tablet con il loro nome, e il tono (più grave o più
// acuto) permette di cambiare timbro anche quando ne esiste una sola.
// Tutto è "silenzioso" se il motore non c'è: nessuna eccezione verso la UI.

import 'package:flutter_tts/flutter_tts.dart';

/// Una voce installata sul dispositivo.
class VoceDisponibile {
  final String nome;
  final String lingua;
  const VoceDisponibile(this.nome, this.lingua);
}

class LetturaVocale {
  LetturaVocale._();
  static final LetturaVocale instance = LetturaVocale._();

  final FlutterTts _tts = FlutterTts();
  bool _lingua = false;

  /// Frase usata da "Prova la voce".
  static const fraseProva =
      'Buongiorno, questa è la voce di lettura dell\'applicazione.';

  Future<void> _assicuraLingua() async {
    if (_lingua) return;
    _lingua = true;
    try {
      await _tts.setLanguage('it-IT');
    } catch (_) {}
  }

  /// Voci italiane installate (vuoto se il motore non risponde).
  Future<List<VoceDisponibile>> vociItaliane() async {
    try {
      final r = await _tts.getVoices;
      if (r is! List) return const [];
      final voci = <VoceDisponibile>[];
      for (final v in r) {
        if (v is! Map) continue;
        final nome = '${v['name'] ?? ''}'.trim();
        final lingua = '${v['locale'] ?? ''}'.trim();
        if (nome.isNotEmpty && lingua.toLowerCase().replaceAll('_', '-').startsWith('it')) {
          voci.add(VoceDisponibile(nome, lingua));
        }
      }
      voci.sort((a, b) => a.nome.compareTo(b.nome));
      return voci;
    } catch (_) {
      return const [];
    }
  }

  /// Imposta voce, tono e velocità. Una voce non più installata viene
  /// ignorata: resta quella predefinita.
  Future<void> applica(
      {String voce = '', double tono = 1.0, double velocita = 0.5}) async {
    await _assicuraLingua();
    try {
      if (voce.isNotEmpty) {
        final trovata = (await vociItaliane()).where((v) => v.nome == voce);
        if (trovata.isNotEmpty) {
          await _tts.setVoice({'name': trovata.first.nome, 'locale': trovata.first.lingua});
        }
      }
      await _tts.setPitch(tono);
      await _tts.setSpeechRate(velocita);
    } catch (_) {}
  }

  void suFine(void Function() f) {
    try {
      _tts.setCompletionHandler(f);
    } catch (_) {}
  }

  Future<void> parla(String testo) => _tts.speak(testo);

  Future<void> ferma() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
