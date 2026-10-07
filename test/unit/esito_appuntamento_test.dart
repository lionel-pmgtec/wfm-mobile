// Esito appuntamento: lo stato mostrato segue l'esito registrato, e l'esito
// sopravvive alla chiusura dell'app (prima era solo in memoria).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:wfm_mobile/domain/entities/entities.dart';
import 'package:wfm_mobile/presentation/features/appointments/appointments_screen.dart';
import 'package:wfm_mobile/presentation/providers/appointments_provider.dart';

EsitoAppuntamentoData _esito(String codice) => EsitoAppuntamentoData(
      dataSopralluogo: DateTime(2026, 9, 24),
      oraSopralluogo: '11:00',
      esito: codice,
    );

void main() {
  setUpAll(() => initializeDateFormatting('it_IT', null));

  group('etichette di stato', () {
    test('ogni codice ha la sua etichetta', () {
      expect(_esito('OK').statoLabel, 'Effettuato');
      expect(_esito('OK').effettuato, isTrue);
      expect(_esito('NO').statoLabel, 'Esito negativo');
      expect(_esito('ER').statoLabel, 'Errore inserimento');
      expect(_esito('MN').statoLabel, 'Mancato accesso');
      expect(_esito('NO').effettuato, isFalse);
    });
  });

  group('persistenza', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('wfm_esitoap_'));
    tearDown(() async {
      await Hive.close();
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    test('l\'esito salvato torna dopo il riavvio', () async {
      await EsitoAppuntamentoStore.open(hivePath: tmp.path);
      final c = EsitoAppuntamentoController('X1');
      expect(c.state, isNull);
      c.save(EsitoAppuntamentoData(
        dataSopralluogo: DateTime(2026, 9, 24),
        oraSopralluogo: '11:00',
        esito: 'OK',
        motivo: 'tutto ok',
        causaCode: 'C1',
        presenzaCliente: false,
      ));
      await Hive.close(); // app chiusa
      await EsitoAppuntamentoStore.open(hivePath: tmp.path); // app riaperta

      final again = EsitoAppuntamentoController('X1').state!;
      expect(again.esito, 'OK');
      expect(again.motivo, 'tutto ok');
      expect(again.causaCode, 'C1');
      expect(again.presenzaCliente, isFalse);
      expect(again.dataSopralluogo, DateTime(2026, 9, 24));
      // un altro OdL non eredita nulla
      expect(EsitoAppuntamentoController('ALTRO').state, isNull);
    });
  });

  group('badge nella schermata Appuntamenti', () {
    const code = '000090000004';
    final appuntamento = Appointment(
      id: 'seed',
      workOrderCode: code,
      date: DateTime(2026, 9, 24),
      startTime: '11:00',
      endTime: '12:00',
    );

    Future<void> pump(WidgetTester t, EsitoAppuntamentoData? esito) async {
      await t.pumpWidget(ProviderScope(
        overrides: [
          appointmentsProvider(code).overrideWith(
              (ref) => AppointmentsController(code, [appuntamento])),
          esitoAppuntamentoProvider(code).overrideWith((ref) {
            final c = EsitoAppuntamentoController(code);
            if (esito != null) c.state = esito;
            return c;
          }),
        ],
        child: const MaterialApp(home: AppointmentsScreen(code: code)),
      ));
      await t.pump();
    }

    testWidgets('senza esito: "Da effettuare"', (t) async {
      await pump(t, null);
      expect(find.text('Da effettuare'), findsOneWidget);
    });

    testWidgets('con esito OK: "Effettuato" e non piu\' "Da effettuare"',
        (t) async {
      await pump(t, _esito('OK'));
      expect(find.text('Effettuato'), findsOneWidget);
      expect(find.text('Da effettuare'), findsNothing);
    });

    testWidgets('con esito MN: "Mancato accesso"', (t) async {
      await pump(t, _esito('MN'));
      expect(find.text('Mancato accesso'), findsOneWidget);
      expect(find.text('Da effettuare'), findsNothing);
    });
  });
}
