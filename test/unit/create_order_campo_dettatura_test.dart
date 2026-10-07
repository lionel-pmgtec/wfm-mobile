// "Dati specifici" del modulo di creazione: i campi di testo libero
// (multiline, es. "Lavoro da eseguire" di ZA02/ZMAV) si possono dettare; la
// matricola resta col suo scanner, e i campi brevi non cambiano.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:wfm_mobile/domain/entities/entities.dart';
import 'package:wfm_mobile/presentation/features/create_order/create_order_screen.dart';
import 'package:wfm_mobile/presentation/providers/anagrafica_provider.dart';

void main() {
  setUpAll(() => initializeDateFormatting('it_IT', null));

  Future<void> apri(WidgetTester t, String tipo, List<DynFieldSpec> campi) async {
    await t.binding.setSurfaceSize(const Size(1200, 3000));
    await t.pumpWidget(ProviderScope(
      overrides: [
        workOrderTypesProvider.overrideWith((ref) async => [
              WorkOrderTypeOption(code: tipo, label: 'Tipo di prova'),
            ]),
        workOrderFieldsProvider(tipo).overrideWith((ref) async => campi),
        workOrderTemplatesProvider(tipo).overrideWith((ref) async => const []),
        orderPrioritiesProvider(tipo).overrideWith((ref) async => const []),
      ],
      child: MaterialApp(home: CreateOrderScreen(initialWoType: tipo)),
    ));
    await t.pumpAndSettle();
  }

  Finder micIn(String etichetta) => find.descendant(
      of: find.widgetWithText(TextFormField, etichetta),
      matching: find.byIcon(Icons.mic_none_outlined));

  testWidgets('"Lavoro da eseguire" (multiline) ha il microfono', (t) async {
    await apri(t, 'ZA02', const [
      DynFieldSpec(
          key: 'attivita',
          label: 'Lavoro da eseguire',
          type: DynFieldType.multiline),
    ]);
    expect(micIn('Lavoro da eseguire'), findsOneWidget);
  });

  testWidgets('la matricola ha lo scanner e nessun microfono (invariato)',
      (t) async {
    await apri(t, 'SOST', const [
      DynFieldSpec(
          key: 'matricola',
          label: 'Matricola contatore da sostituire',
          required: true),
    ]);
    final campo =
        find.widgetWithText(TextFormField, 'Matricola contatore da sostituire *');
    expect(
        find.descendant(of: campo, matching: find.byIcon(Icons.qr_code_scanner)),
        findsOneWidget);
    expect(
        find.descendant(of: campo, matching: find.byIcon(Icons.mic_none_outlined)),
        findsNothing);
  });

  testWidgets('un campo breve (testo/numero) resta senza microfono', (t) async {
    await apri(t, 'ZMAV', const [
      DynFieldSpec(key: 'sigillo', label: 'Numero sigillo'),
      DynFieldSpec(
          key: 'lettura', label: 'Lettura', type: DynFieldType.number),
    ]);
    expect(micIn('Numero sigillo'), findsNothing);
    expect(micIn('Lettura'), findsNothing);
  });
}
