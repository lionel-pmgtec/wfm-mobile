// Descrizione ordine: solo ciò che l'operatore ha scritto, senza "Dati specifici".

import 'package:flutter_test/flutter_test.dart';
import 'package:wfm_mobile/core/utils/note_ordine.dart';

void main() {
  group('componiNoteCreazione (OdL creato sulla tablet)', () {
    test('SOST: la matricola ha il suo campo, restano solo le note digitate', () {
      // Il modulo scarta la matricola (kCampiConCampoProprio) prima di comporre.
      expect(kCampiConCampoProprio.contains('matricola'), isTrue);
      expect(componiNoteCreazione(extra: const [], base: 'Test'), 'Test');
    });

    test('nessuna nota: testo vuoto (non "Dati specifici")', () {
      expect(componiNoteCreazione(extra: const [], base: ''), '');
      expect(componiNoteCreazione(extra: const [], base: '   '), '');
    });

    test('ZMAV: "Lavoro da eseguire" compare come solo valore, senza etichetta', () {
      final t = componiNoteCreazione(
        extra: [(label: 'Lavoro da eseguire', value: 'ripristino carreggiata')],
        base: 'cliente avvisato',
      );
      expect(t, 'ripristino carreggiata\n\ncliente avvisato');
      expect(t.contains('Dati specifici'), isFalse);
      expect(t.contains('Lavoro da eseguire'), isFalse);
    });

    test('più campi specifici: "Etichetta: valore" per distinguerli', () {
      final t = componiNoteCreazione(extra: [
        (label: 'Calibro', value: 'DN15'),
        (label: 'Sigillo', value: 'S-1'),
      ], base: '');
      expect(t, 'Calibro: DN15\nSigillo: S-1');
    });

    test('valori vuoti ignorati', () {
      expect(
          componiNoteCreazione(
              extra: [(label: 'Lavoro', value: '  ')], base: 'Test'),
          'Test');
    });
  });

  group('notaPulita (OdL già creati con la versione precedente)', () {
    test('il testo esatto della schermata: resta solo "Test"', () {
      const vecchio =
          'Dati specifici:\nMatricola contatore da sostituire: 1234567\n\nTest';
      expect(notaPulita(vecchio), 'Test');
    });

    test('senza nota dell\'operatore: vuoto', () {
      expect(
          notaPulita(
              'Dati specifici:\nMatricola contatore da sostituire: 1234567'),
          '');
    });

    test('una nota normale non viene toccata', () {
      expect(notaPulita('Contatore in pozzetto allagato'),
          'Contatore in pozzetto allagato');
      expect(notaPulita('riga 1\n\nriga 2'), 'riga 1\n\nriga 2');
    });

    test('non tocca altre righe che contengono la parola matricola', () {
      expect(notaPulita('Verificare la matricola del vicino'),
          'Verificare la matricola del vicino');
    });
  });
}
