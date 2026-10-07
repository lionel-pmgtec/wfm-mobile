// "Data Fine Prevista": la fonte è il backend. SAP manda un solo DATA_FINE
// (AFKO-GLTRP) e il backend lo dà come `dataEsec`; la fine prevista vera è la
// fine schedulata, in `testata.date.fineSchedulato` (null finché SAP non la
// manda). Niente valori di ripiego inventati.

import 'package:flutter_test/flutter_test.dart';
import 'package:wfm_mobile/data/models/mappers.dart';

Map<String, dynamic> _wo({Map<String, dynamic>? testata, Object? dataFine}) => {
      'externalCode': '000090000006',
      'woType': 'ZF01',
      'status': 'RICEVUTO',
      // Come risponde il backend: DATA_FINE di SAP sotto `dataEsec`.
      'dataEsec': '2026-09-24',
      if (dataFine != null) 'dataFine': dataFine,
      if (testata != null) 'testata': testata,
    };

Map<String, dynamic> _testata(Object? fineSchedulato) => {
      'date': {
        'inizioCardine': '2026-09-24',
        'fineCardine': '2026-09-24',
        'inizioSchedulato': null,
        'fineSchedulato': fineSchedulato,
      },
    };

void main() {
  test('SAP non manda la fine schedulata: nessuna data fine prevista', () {
    final o = workOrderFromJson(_wo(testata: _testata(null)));
    expect(o.dataFine, isNull);
    expect(o.dataEsec, DateTime(2026, 9, 24)); // la data di SAP resta com'è
  });

  test('SAP manda la fine schedulata: è la data fine prevista', () {
    final o = workOrderFromJson(_wo(testata: _testata('2026-10-02')));
    expect(o.dataFine, DateTime(2026, 10, 2));
    expect(o.dataEsec, DateTime(2026, 9, 24)); // due date distinte, nessun doppione
  });

  test('senza il nodo testata: nessun errore, nessuna data', () {
    expect(workOrderFromJson(_wo()).dataFine, isNull);
    expect(workOrderFromJson(_wo(testata: {'date': null})).dataFine, isNull);
  });

  test('una chiave `dataFine` in cima non è la fonte (il backend non la manda)',
      () {
    final o = workOrderFromJson(_wo(dataFine: '2030-01-01'));
    expect(o.dataFine, isNull);
  });

  test('non si rimanda mai al backend: lì `dataFine` è il DATA_FINE cardine',
      () {
    final o = workOrderFromJson(_wo(testata: _testata('2026-10-02')));
    expect(workOrderToJson(o).containsKey('dataFine'), isFalse);
  });
}
