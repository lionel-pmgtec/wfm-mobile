import 'package:flutter_test/flutter_test.dart';
import 'package:wfm_mobile/core/utils/validators.dart';
import 'package:wfm_mobile/domain/entities/enums.dart';

void main() {
  group('Validators', () {
    test('required', () {
      expect(Validators.required(''), isNotNull);
      expect(Validators.required('x'), isNull);
    });

    test('number', () {
      expect(Validators.number('abc'), isNotNull);
      expect(Validators.number('12.5'), isNull);
      expect(Validators.number('', allowEmpty: true), isNull);
    });

    test('meterReading rifiuta valori inferiori al precedente', () {
      expect(Validators.meterReading('5', previous: 10), isNotNull);
      expect(Validators.meterReading('15', previous: 10), isNull);
    });
  });

  group('WorkOrderStatus', () {
    test('mappa i codici SAP', () {
      expect(WorkOrderStatus.fromSap('RICEVUTO'), WorkOrderStatus.ricevuto);
      expect(WorkOrderStatus.fromSap('IN_ESECUZIONE'),
          WorkOrderStatus.inEsecuzione);
      expect(WorkOrderStatus.fromSap('SOSPESO'), WorkOrderStatus.sospeso);
      expect(WorkOrderStatus.fromSap('I0005'), WorkOrderStatus.completato);
    });
  });
}
