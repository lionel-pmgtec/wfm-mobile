// L'appuntamento mostrato è quello preso col cliente.
//
// Il backend manda `appointmentDate` a cascata: giorno di pianificazione (oggi,
// se non indicato) e solo dopo l'appuntamento SAP. Verificato sul backend:
//   - ordine con appuntamento del cliente il 7/10 alle 10:30 -> arriva
//     appointmentDate = oggi, ora 10:30 (la data del cliente è coperta);
//   - ordine senza appuntamento -> arriva appointmentDate = oggi, ora vuota.
// L'appuntamento vero sta in `datiSap.APPUNTAMENTO` (assente se non c'è).
// Il tablet legge quello: niente appuntamenti fittizi, e il pulsante per
// crearne uno c'è sempre.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:wfm_mobile/data/models/mappers.dart';
import 'package:wfm_mobile/domain/entities/entities.dart';
import 'package:wfm_mobile/presentation/features/appointments/appointments_screen.dart';
import 'package:wfm_mobile/presentation/providers/appointments_provider.dart';
import 'package:wfm_mobile/presentation/providers/work_orders_provider.dart';

/// Payload come lo manda il backend: [datiSap] dell'ordine e la cascata.
Map<String, dynamic> _json({
  Map<String, dynamic>? appuntamentoSap,
  String appointmentDate = '2026-10-01',
  String ora = '',
  String oraFine = '',
  bool conDatiSap = true,
}) =>
    {
      'externalCode': '000090000101',
      'woType': 'ZA02',
      'status': 'RICEVUTO',
      'appointmentDate': appointmentDate,
      'appointmentStartTime': ora,
      'appointmentEndTime': oraFine,
      'address': {'street': 'VIA FERMO', 'streetNumber': '19', 'city': 'Ancona'},
      if (conDatiSap) 'datiSap': {'APPUNTAMENTO': appuntamentoSap},
    };

void main() {
  setUpAll(() => initializeDateFormatting('it_IT', null));

  group('lettura dal backend', () {
    test('ordine SAP senza appuntamento: nessuna data, nessuna ora', () {
      // Il backend manda comunque appointmentDate = oggi.
      final o = workOrderFromJson(_json());
      expect(o.appointmentDate, isNull);
      expect(o.appointmentStartTime, '');
      expect(o.appointmentEndTime, '');
    });

    test("ordine con appuntamento del cliente: la SUA data e la sua ora", () {
      // Il backend manda appointmentDate = 1/10 (pianificazione) con l'ora
      // del cliente: la data giusta è quella di APPUNTAMENTO.
      final o = workOrderFromJson(_json(
        appuntamentoSap: {
          'FISSATO_DATA': '2026-10-07',
          'FISSATO_ORA': '10:30:00',
          'FISSATO_ORA_LIMITE': '11:30:00',
        },
        ora: '10:30',
        oraFine: '11:30',
      ));
      expect(o.appointmentDate, DateTime(2026, 10, 7));
      expect(o.appointmentStartTime, '10:30');
      expect(o.appointmentEndTime, '11:30');
    });

    test('formato SAP compatto (20261008 / 090000), come dagli ordini del tablet',
        () {
      final o = workOrderFromJson(_json(appuntamentoSap: {
        'FISSATO_DATA': '20261008',
        'FISSATO_ORA': '090000',
        'FISSATO_ORA_LIMITE': '',
      }));
      expect(o.appointmentDate, DateTime(2026, 10, 8));
      expect(o.appointmentStartTime, '09:00');
      expect(o.appointmentEndTime, '');
    });

    test('appuntamento con la sola data (senza ora)', () {
      final o = workOrderFromJson(_json(
          appuntamentoSap: {'FISSATO_DATA': '2026-10-07', 'FISSATO_ORA': ''}));
      expect(o.appointmentDate, DateTime(2026, 10, 7));
      expect(o.appointmentStartTime, '');
    });

    test('copia salvata sul tablet (senza datiSap): valori già veri, invariati',
        () {
      final salvato = workOrderToJson(workOrderFromJson(_json(
          appuntamentoSap: {
            'FISSATO_DATA': '2026-10-07',
            'FISSATO_ORA': '10:30:00'
          })));
      expect(salvato.containsKey('datiSap'), isFalse);
      final riletto = workOrderFromJson(salvato);
      expect(riletto.appointmentDate, DateTime(2026, 10, 7));
      expect(riletto.appointmentStartTime, '10:30');

      final senza = workOrderFromJson(workOrderToJson(workOrderFromJson(_json())));
      expect(senza.appointmentDate, isNull);
    });

    test('OdL creato dal tablet senza data: nessun appuntamento (ora=oggi del backend ignorata)',
        () {
      // Risposta reale: APPUNTAMENTO assente, appointmentDate = oggi.
      final o = workOrderFromJson(_json());
      expect(o.appointmentDate, isNull);
    });
  });

  test('invio al backend: senza appuntamento non si manda né data né ora', () {
    // Il tablet non inventa più "oggi" né "08:00" alla creazione: il backend
    // senza data non crea nessun appuntamento (verificato: APPUNTAMENTO assente).
    const o = WorkOrder(externalCode: 'TMP-ODL-1', woType: 'ZA02');
    final j = workOrderToJson(o);
    expect(j['appointmentDate'], isNull);
    expect(j['appointmentStartTime'], '');
  });

  group('lista Appuntamenti', () {
    Future<void> apri(WidgetTester t, WorkOrder ordine) async {
      await t.binding.setSurfaceSize(const Size(1000, 1600));
      await t.pumpWidget(ProviderScope(
        overrides: [
          workOrderDetailProvider(ordine.externalCode)
              .overrideWith((ref) async => ordine),
        ],
        child: MaterialApp(
            home: AppointmentsScreen(code: ordine.externalCode)),
      ));
      await t.pumpAndSettle();
    }

    testWidgets('senza appuntamento del cliente: lista vuota, ma "Nuovo" c\'è',
        (t) async {
      await apri(t, workOrderFromJson(_json()));
      expect(find.text('Nessun appuntamento'), findsOneWidget);
      expect(find.text('Nuovo'), findsOneWidget);
    });

    testWidgets("con l'appuntamento del cliente: compare, e 'Nuovo' c'è lo stesso",
        (t) async {
      await apri(
          t,
          workOrderFromJson(_json(appuntamentoSap: {
            'FISSATO_DATA': '2026-10-07',
            'FISSATO_ORA': '10:30:00',
            'FISSATO_ORA_LIMITE': '11:30:00',
          })));
      expect(find.text('Nessun appuntamento'), findsNothing);
      expect(find.textContaining('10:30'), findsWidgets);
      expect(find.text('Nuovo'), findsOneWidget);
    });

    test('il seed non usa più la data di pianificazione', () {
      final c = ProviderContainer(overrides: [
        workOrderDetailProvider('000090000101')
            .overrideWith((ref) async => workOrderFromJson(_json(ora: '10:30'))),
      ]);
      addTearDown(c.dispose);
      // Anche con un'ora (che da sola non basta più): nessun appuntamento.
      expect(c.read(appointmentsProvider('000090000101')), isEmpty);
    });
  });
}
