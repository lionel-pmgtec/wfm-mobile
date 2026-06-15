// Verifica del supporto al tipo OdL DISA (Disattivazione fornitura).

import 'package:flutter_test/flutter_test.dart';
import 'package:wfm_mobile/data/mock/mock_data.dart';
import 'package:wfm_mobile/domain/entities/entities.dart';

void main() {
  test('esiste un OdL DISA nei dati mock con contatore e lettura', () {
    final disa =
        MockData.workOrders().firstWhere((o) => o.woType == 'DISA');
    expect(disa.hasDisattivazione, isTrue);
    expect(disa.meter, isNotNull);
    expect(disa.meter!.lastReading, isNotNull);
  });

  test('hasDisattivazione è falso per gli altri tipi', () {
    const atti = WorkOrder(externalCode: '1', woType: 'ATTI');
    expect(atti.hasDisattivazione, isFalse);
  });

  test('DISA è tra i codici TAM disponibili', () {
    expect(MockData.tamCodes, contains('DISA'));
  });

  test('Appointment.copyWith aggiorna l\'esito', () {
    final a = Appointment(id: 'x', workOrderCode: '1', date: DateTime(2026, 6, 8));
    final done = a.copyWith(outcome: AppointmentOutcome.effettuato);
    expect(done.outcome, AppointmentOutcome.effettuato);
    expect(done.date, a.date);
  });
}
