// Le tre operazioni standard di ogni OdL (0010 Trasferimento, 0040 Lavori
// Idraulici, 0200 Automezzi), qualunque sia il tipo.
//
// Il backend le dà (`OPERAZIONI_SOST`) solo a una SOST creata dal tablet: un
// ZA02 arrivava senza e la scheda Operazioni restava vuota. Il tablet le
// propone quando l'ordine non ne ha; le operazioni mandate dal backend (cicli
// SAP) hanno sempre la precedenza.

import 'package:flutter_test/flutter_test.dart';
import 'package:wfm_mobile/data/models/mappers.dart';
import 'package:wfm_mobile/domain/entities/entities.dart';

Map<String, dynamic> _json({Object? operations}) => {
      'externalCode': 'TMP-ODL-1',
      'woType': 'ZA02',
      'status': 'RICEVUTO',
      'address': {'street': 'VIA FERMO', 'streetNumber': '19', 'city': 'Ancona'},
      if (operations != null) 'operations': operations,
    };

void main() {
  test('sono quelle del backend: numero, descrizione, chiave di controllo', () {
    expect(
        [for (final o in kOperazioniStandard) (o.number, o.description, o.codice)],
        [
          ('0010', 'Trasferimento', 'PM01'),
          ('0040', 'Lavori Idraulici', 'ZM01'),
          ('0200', 'Automezzi', 'PM01'),
        ]);
  });

  group('lettura di un OdL dal backend', () {
    test('senza operazioni (ZA02 creato dal tablet): le tre standard', () {
      final o = workOrderFromJson(_json(operations: const []));
      expect(o.operations.map((x) => x.number), ['0010', '0040', '0200']);
    });

    test('campo operations assente: le tre standard', () {
      expect(workOrderFromJson(_json()).operations, hasLength(3));
    });

    test('operazioni mandate dal backend (ciclo SAP): restano quelle', () {
      final o = workOrderFromJson(_json(operations: [
        {
          'id': '0010',
          'number': '0010',
          'codice': 'PM01',
          'testoBreve': 'Sopralluogo',
          'description': 'Sopralluogo',
          'workCenter': 'ACNOT01A'
        },
        {
          'id': '0140',
          'number': '0140',
          'codice': 'ZM01',
          'testoBreve': 'Ispezione fognaria',
          'description': 'Ispezione fognaria'
        },
      ]));
      expect(o.operations.map((x) => x.number), ['0010', '0140']);
      expect(o.operations.first.description, 'Sopralluogo');
    });

    test('copia salvata sul tablet: le operazioni restano le stesse', () {
      final salvato = workOrderToJson(workOrderFromJson(_json()));
      final riletto = workOrderFromJson(salvato);
      expect(riletto.operations.map((x) => x.number), ['0010', '0040', '0200']);
    });
  });

  test('OdL creato sul tablet: le tre operazioni viaggiano al backend', () {
    // Il backend, per un tipo diverso da SOST, legge `operations` del corpo
    // (operazioniDaApp: number -> OPERAZIONE, testoBreve -> DESCRIZIONE,
    // codice -> CHIAVE_CONTR) e le salva sull'ordine.
    final j = workOrderToJson(WorkOrder(
        externalCode: 'TMP-ODL-9',
        woType: 'ZA02',
        operations: kOperazioniStandard));
    final ops = (j['operations'] as List).cast<Map<String, dynamic>>();
    expect([for (final o in ops) o['number']], ['0010', '0040', '0200']);
    expect(ops[1]['codice'], 'ZM01');
    expect(ops[1]['testoBreve'], 'Lavori Idraulici');
  });
}
