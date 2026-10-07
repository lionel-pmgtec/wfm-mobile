// Lettura contatori via NFC: il codice
// letto è il testo del record NDEF "Text" se il chip lo porta, altrimenti
// l'UID esadecimale del tag — così un contatore senza NDEF resta leggibile.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:wfm_mobile/presentation/features/scanner/barcode_scanner_screen.dart';

NfcTag _tagConNdefTesto(String testo) {
  final testoBytes = utf8.encode(testo);
  return NfcTag(handle: 'h1', data: {
    'ndef': {
      'isWritable': false,
      'maxSize': 512,
      'cachedMessage': {
        'records': [
          {
            'typeNameFormat': 1, // nfcWellknown
            'type': Uint8List.fromList([0x54]), // 'T'
            'identifier': Uint8List.fromList([]),
            'payload': Uint8List.fromList([2, ...ascii.encode('en'), ...testoBytes]),
          },
        ],
      },
    },
  });
}

NfcTag _tagSoloUid(List<int> uid) {
  return NfcTag(handle: 'h2', data: {
    'nfca': {
      'identifier': Uint8List.fromList(uid),
      'atqa': Uint8List.fromList([]),
      'sak': 0,
      'maxTransceiveLength': 253,
      'timeout': 618,
    },
  });
}

void main() {
  test('tag con record NDEF di testo: torna il testo (la matricola)', () {
    final tag = _tagConNdefTesto('000000000090000212');
    expect(codiceDaTagNfc(tag), '000000000090000212');
  });

  test('tag senza NDEF: torna l\'UID esadecimale maiuscolo', () {
    final tag = _tagSoloUid([0x04, 0xA1, 0x9F, 0x2B]);
    expect(codiceDaTagNfc(tag), '04A19F2B');
  });

  test('tag senza NDEF e senza nessuna tecnologia nota: nessun codice', () {
    final tag = NfcTag(handle: 'h3', data: const {});
    expect(codiceDaTagNfc(tag), isNull);
  });
}
