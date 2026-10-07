// Allineamento al backend del 6/10 (inizio cardine all'assegnazione).
//
// Verificato sul backend: un OdL creato dal tablet senza data arriva con
//   - nessun appuntamento (datiSap.APPUNTAMENTO assente),
//   - inizio cardine = giorno dell'assegnazione (testata.date.inizioCardine),
//   - fine cardine vuota (dataEsec assente).
// Il tablet data e ordina un OdL senza appuntamento con l'inizio cardine.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:wfm_mobile/data/models/mappers.dart';
import 'package:wfm_mobile/domain/entities/entities.dart';
import 'package:wfm_mobile/presentation/features/work_orders/work_order_detail_screen.dart';
import 'package:wfm_mobile/presentation/features/work_orders/widgets/work_order_card.dart';
import 'package:wfm_mobile/presentation/providers/work_orders_provider.dart';

Map<String, dynamic> _json({
  String? inizio,
  Map<String, dynamic>? appuntamentoSap,
  String? dataEsec,
  String createdAt = '2026-10-05',
}) =>
    {
      'externalCode': 'TMP-ODL-1',
      'woType': 'ZA02',
      'status': 'RICEVUTO',
      'createdAt': createdAt,
      // Il backend manda comunque il giorno dell'assegnazione qui.
      'appointmentDate': '2026-10-07',
      'appointmentStartTime': '',
      if (dataEsec != null) 'dataEsec': dataEsec,
      'address': {'street': 'VIA FERMO', 'streetNumber': '19', 'city': 'Ancona'},
      'testata': {
        'date': {'inizioCardine': inizio, 'fineCardine': null}
      },
      'datiSap': {'APPUNTAMENTO': appuntamentoSap},
    };

void main() {
  setUpAll(() => initializeDateFormatting('it_IT', null));

  group('inizio cardine dal backend', () {
    test('senza appuntamento: data di riferimento = inizio cardine', () {
      final o = workOrderFromJson(_json(inizio: '2026-10-07'));
      expect(o.appointmentDate, isNull); // nessun appuntamento inventato
      expect(o.dataInizio, DateTime(2026, 10, 7));
      expect(o.dataEsec, isNull); // fine cardine vuota
      expect(o.dataRiferimento, DateTime(2026, 10, 7));
    });

    test("con l'appuntamento del cliente: vince l'appuntamento", () {
      final o = workOrderFromJson(_json(
          inizio: '2026-10-20',
          appuntamentoSap: {'FISSATO_DATA': '20261022', 'FISSATO_ORA': '093000'}));
      expect(o.appointmentDate, DateTime(2026, 10, 22));
      expect(o.dataInizio, DateTime(2026, 10, 20));
      expect(o.dataRiferimento, DateTime(2026, 10, 22));
    });

    test('senza cardine né appuntamento: la data di esecuzione, poi la creazione',
        () {
      expect(
          workOrderFromJson(_json(dataEsec: '2026-10-09')).dataRiferimento,
          DateTime(2026, 10, 9));
      expect(workOrderFromJson(_json()).dataRiferimento, DateTime(2026, 10, 5));
    });

    test('copia salvata sul tablet: l\'inizio cardine resta', () {
      final salvato =
          workOrderToJson(workOrderFromJson(_json(inizio: '2026-10-07')));
      expect(salvato.containsKey('testata'), isFalse);
      final riletto = workOrderFromJson(salvato);
      expect(riletto.dataInizio, DateTime(2026, 10, 7));
      expect(riletto.appointmentDate, isNull);
    });
  });

  group('lista e fiche', () {
    testWidgets('la card mostra l\'inizio cardine se non c\'è appuntamento',
        (t) async {
      final o = workOrderFromJson(_json(inizio: '2026-10-07'));
      await t.pumpWidget(ProviderScope(
          child: MaterialApp(
              home: Scaffold(body: WorkOrderCard(order: o, onTap: () {})))));
      expect(find.textContaining('07/10/2026'), findsOneWidget);
    });

    test('ordinamento: per data di riferimento, senza data in fondo', () {
      final a = workOrderFromJson(_json(inizio: '2026-10-12'));
      final b = workOrderFromJson(_json(inizio: '2026-10-08'));
      final lista = [a, b]
        ..sort((x, y) => (x.dataRiferimento ?? DateTime(2100))
            .compareTo(y.dataRiferimento ?? DateTime(2100)));
      expect(lista.first.dataInizio, DateTime(2026, 10, 8));
    });

    testWidgets('la fiche mostra "Data Inizio" e nessun appuntamento',
        (t) async {
      final o = workOrderFromJson(_json(inizio: '2026-10-07'));
      await t.binding.setSurfaceSize(const Size(1000, 3000));
      await t.pumpWidget(ProviderScope(
        overrides: [
          workOrderDetailProvider('TMP-ODL-1').overrideWith((ref) async => o),
        ],
        child: const MaterialApp(
            home: WorkOrderDetailScreen(code: 'TMP-ODL-1')),
      ));
      await t.pumpAndSettle();
      expect(find.text('DATA INIZIO'), findsOneWidget);
      expect(find.textContaining('07/10/2026'), findsWidgets);
      // Senza appuntamento il campo mostra "—", mai una data inventata.
      expect(o.appointmentDate, isNull);
      expect(find.text('DATA ESECUZIONE'), findsNothing); // fine cardine vuota
    });
  });
}
