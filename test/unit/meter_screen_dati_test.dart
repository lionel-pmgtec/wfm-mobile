// Scheda "Dati" del contatore: lettura precedente (storico SAP) distinta
// dall'ultima lettura, e ubicazione modificabile a mano (SAP non sempre la manda).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:wfm_mobile/domain/entities/entities.dart';
import 'package:wfm_mobile/presentation/features/meter/meter_screen.dart';
import 'package:wfm_mobile/presentation/providers/work_orders_provider.dart';

const _code = '000090000004';

Future<void> _pump(WidgetTester t, WorkOrder order) async {
  await t.binding.setSurfaceSize(const Size(1000, 1600));
  await t.pumpWidget(ProviderScope(
    overrides: [
      workOrderDetailProvider(_code).overrideWith((ref) async => order),
    ],
    child: const MaterialApp(home: MeterScreen(code: _code)),
  ));
  await t.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('it_IT', null));

  const meter = Meter(
    matricola: '000000000090000004',
    brand: 'ABB',
    ubicazione: 'A0144',
    location: '10021650',
    lastReading: 6100,
    lastReadingDate: null,
    previousReading: 5980,
    previousReadingTime: '08:30:00',
    previousReadingStatus: 'OK',
  );

  const orderDisa = WorkOrder(
    externalCode: _code,
    woType: 'DISA',
    meter: meter,
  );

  testWidgets(
      'mostra "Lettura precedente" con il dato storico (previousReading), non ripetuto',
      (t) async {
    await _pump(t, orderDisa);

    // L'ultima lettura (sull'ordine) e la lettura precedente (storico) sono
    // DUE valori diversi e devono comparire entrambi, non confusi fra loro.
    expect(find.text('6100'), findsOneWidget); // ultima lettura
    expect(find.text('5980'), findsOneWidget); // lettura precedente (storico)
    // FieldRow mostra l'etichetta in maiuscolo (qui coincide anche col
    // titolo della sezione: SectionHeader + FieldRow, due widget).
    expect(find.text('ULTIMA LETTURA'), findsNWidgets(2));
    expect(find.text('LETTURA PRECEDENTE'), findsOneWidget);
    expect(find.text('DATA LETTURA PRECEDENTE'), findsOneWidget);
    expect(find.text('08:30:00'), findsOneWidget);
    expect(find.text('OK'), findsOneWidget);
  });

  testWidgets('senza lettura precedente dal backend, niente sezione (nessun dato inventato)',
      (t) async {
    const meterSenzaStorico = Meter(
      matricola: '000000000090000004',
      lastReading: 100,
    );
    await _pump(t, WorkOrder(externalCode: _code, woType: 'DISA', meter: meterSenzaStorico));
    expect(find.text('LETTURA PRECEDENTE (STORICO)'), findsNothing);
  });

  testWidgets('l\'ubicazione è un campo EDITABILE, precompilato dal dato SAP',
      (t) async {
    await _pump(t, orderDisa);
    // Non più un FieldRow di sola lettura: un TextFormField che si può correggere.
    final field = find.widgetWithText(TextFormField, 'A0144');
    expect(field, findsOneWidget);
  });

  testWidgets('l\'ubicazione digitata a mano resta visibile mentre si scrive',
      (t) async {
    const meterSenzaUbicazione = Meter(
      matricola: '000000000090000004',
      location: '10021650',
    );
    await _pump(t, WorkOrder(externalCode: _code, woType: 'DISA', meter: meterSenzaUbicazione));
    final campo = find.byType(TextFormField).first;
    await t.enterText(campo, 'B0200');
    await t.pump();
    expect(find.text('B0200'), findsOneWidget);
  });
}
