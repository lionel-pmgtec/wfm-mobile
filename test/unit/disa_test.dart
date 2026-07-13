// Verifica del supporto al tipo OdL DISA (Disattivazione fornitura).
// Test a livello di entita: nessun dato mock, gli OdL sono costruiti inline.

import 'package:flutter_test/flutter_test.dart';
import 'package:wfm_mobile/domain/entities/entities.dart';

void main() {
  test('un OdL DISA espone disattivazione, contatore e lettura', () {
    const disa = WorkOrder(
      externalCode: '50557262',
      woType: 'DISA',
      woTypeDescription: 'Misuratori - Chiusura (sigillo)',
      meter: Meter(
        matricola: '20114578',
        brand: 'SENSUS',
        lastReading: 125.0,
      ),
    );
    expect(disa.hasDisattivazione, isTrue);
    expect(disa.meter, isNotNull);
    expect(disa.meter!.lastReading, isNotNull);
  });

  test('hasDisattivazione è falso per gli altri tipi', () {
    const atti = WorkOrder(externalCode: '1', woType: 'ATTI');
    expect(atti.hasDisattivazione, isFalse);
  });

  test('Appointment.copyWith aggiorna l\'esito', () {
    final a = Appointment(id: 'x', workOrderCode: '1', date: DateTime(2026, 6, 8));
    final done = a.copyWith(outcome: AppointmentOutcome.effettuato);
    expect(done.outcome, AppointmentOutcome.effettuato);
    expect(done.date, a.date);
  });
}
