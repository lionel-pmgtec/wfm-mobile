// Sezione "Indirizzo intervento" del modulo di creazione: Provincia e CAP,
// prima assenti (l'Address li supporta, ma il modulo non li chiedeva).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:wfm_mobile/domain/entities/entities.dart';
import 'package:wfm_mobile/presentation/features/create_order/create_order_screen.dart';
import 'package:wfm_mobile/presentation/providers/anagrafica_provider.dart';
import 'package:wfm_mobile/presentation/providers/avvisi_provider.dart';

void main() {
  setUpAll(() => initializeDateFormatting('it_IT', null));

  Future<void> apri(WidgetTester t, {String? avvisoOrigine}) async {
    await t.binding.setSurfaceSize(const Size(1200, 3000));
    await t.pumpWidget(ProviderScope(
      overrides: [
        avvisoDetailProvider('000400090202').overrideWith((ref) async =>
            const NotificationAvviso(
              numeroAvviso: '000400090202',
              descrizione: 'Guasto contatore',
              tipo: 'ZH',
              address: Address(
                street: 'VIA DELLE QUERCE',
                streetNumber: '4',
                city: 'OSIMO',
                provincia: 'AN',
                cap: '60027',
              ),
              customer: Customer(nome: 'Elena', cognome: 'Viola'),
            )),
        workOrderTypesProvider.overrideWith((ref) async => const [
              WorkOrderTypeOption(code: 'SOST', label: 'Sostituzione contatore'),
              WorkOrderTypeOption(code: 'ZMAV', label: 'Manutenzione varie'),
            ]),
        workOrderFieldsProvider('SOST').overrideWith((ref) async => const []),
        workOrderTemplatesProvider('SOST').overrideWith((ref) async => const []),
        orderPrioritiesProvider('SOST').overrideWith((ref) async => const []),
      ],
      child: MaterialApp(
        home: CreateOrderScreen(
            initialWoType: 'SOST', originAvviso: avvisoOrigine),
      ),
    ));
    await t.pumpAndSettle();
  }

  testWidgets('i campi Provincia e CAP esistono nel modulo', (t) async {
    await apri(t);
    expect(find.widgetWithText(TextFormField, 'Provincia'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'CAP'), findsOneWidget);
  });

  testWidgets('da un avviso: Provincia e CAP si precompilano dall\'indirizzo',
      (t) async {
    await apri(t, avvisoOrigine: '000400090202');
    expect(find.text('AN'), findsOneWidget);
    expect(find.text('60027'), findsOneWidget);
  });

  testWidgets('creazione libera: si possono digitare a mano', (t) async {
    await apri(t);
    await t.enterText(
        find.widgetWithText(TextFormField, 'Provincia'), 'PU');
    await t.enterText(find.widgetWithText(TextFormField, 'CAP'), '61121');
    await t.pump();
    expect(find.text('PU'), findsOneWidget);
    expect(find.text('61121'), findsOneWidget);
  });

  testWidgets('il tipo OdL è un match code: tocca il campo per scegliere SOST',
      (t) async {
    await t.binding.setSurfaceSize(const Size(1200, 3000));
    await t.pumpWidget(ProviderScope(
      overrides: [
        workOrderTypesProvider.overrideWith((ref) async => const [
              WorkOrderTypeOption(code: 'SOST', label: 'Sostituzione contatore'),
              WorkOrderTypeOption(code: 'ZMAV', label: 'Manutenzione varie'),
            ]),
      ],
      child: const MaterialApp(home: CreateOrderScreen()),
    ));
    await t.pumpAndSettle();

    // Niente più griglia di riquadri: un campo "match code" da toccare.
    expect(find.text('Tocca per scegliere il tipo di ordine…'), findsOneWidget);
    await t.tap(find.byType(InkWell).first);
    await t.pumpAndSettle();
    await t.tap(find.text('Sostituzione contatore'));
    await t.pumpAndSettle();

    expect(find.text('SOST — Sostituzione contatore'), findsOneWidget);
  });

  testWidgets('ZF01 e SOST sono in testa alla lista dei tipi OdL (i più usati)',
      (t) async {
    await t.binding.setSurfaceSize(const Size(1200, 3000));
    await t.pumpWidget(ProviderScope(
      overrides: [
        // Ordine "sbagliato" in arrivo dal cruscotto: l'app deve riordinarlo.
        workOrderTypesProvider.overrideWith((ref) async => const [
              WorkOrderTypeOption(code: 'ZMAV', label: 'Manutenzione varie'),
              WorkOrderTypeOption(code: 'SOST', label: 'Sostituzione contatore'),
              WorkOrderTypeOption(
                  code: 'ZF01', label: 'Pronto Intervento Fognatura'),
            ]),
      ],
      child: const MaterialApp(home: CreateOrderScreen()),
    ));
    await t.pumpAndSettle();

    await t.tap(find.byType(InkWell).first);
    await t.pumpAndSettle();

    // Verifichiamo l'ordine verticale confrontando la posizione Y dei codici.
    final posZf01 = t.getTopLeft(find.text('ZF01')).dy;
    final posSost = t.getTopLeft(find.text('SOST')).dy;
    final posZmav = t.getTopLeft(find.text('ZMAV')).dy;
    expect(posZf01, lessThan(posSost));
    expect(posSost, lessThan(posZmav));
  });

  testWidgets(
      'simulazione riduttore di pressione: ZA02 e SOST cliccabili, ZF01/ZMAV grigi',
      (t) async {
    await t.binding.setSurfaceSize(const Size(1200, 3000));
    await t.pumpWidget(ProviderScope(
      overrides: [
        // Come GET /anagrafica/wo-types del backend (TIPI_CREABILI).
        workOrderTypesProvider.overrideWith((ref) async => const [
              WorkOrderTypeOption(code: 'SOST', label: 'Sostituzione contatore'),
              WorkOrderTypeOption(code: 'ZF01', label: 'Pronto Intervento Fognatura'),
              WorkOrderTypeOption(code: 'ZMAV', label: 'Manutenzione varie'),
              WorkOrderTypeOption(
                  code: 'ZA02', label: 'Attività Ordinarie Potabile'),
            ]),
      ],
      child: const MaterialApp(home: CreateOrderScreen()),
    ));
    await t.pumpAndSettle();

    await t.tap(find.byType(InkWell).first);
    await t.pumpAndSettle();

    // ZA02 è cliccabile: sceglierlo chiude il pannello e valorizza il campo.
    expect(find.text('ZA02'), findsOneWidget);
    await t.tap(find.text('ZA02'));
    await t.pumpAndSettle();
    expect(find.text('ZA02 — Attività Ordinarie Potabile'), findsOneWidget);

    // ZF01/ZMAV sono grigi: il tocco non cambia la selezione fatta.
    await t.tap(find.byType(InkWell).first);
    await t.pumpAndSettle();
    await t.tap(find.text('Pronto Intervento Fognatura'));
    await t.pumpAndSettle();
    await t.tap(find.byIcon(Icons.close)); // chiudo il pannello (tocco a vuoto)
    await t.pumpAndSettle();
    expect(find.textContaining('ZA02'), findsOneWidget); // ancora ZA02

    // SOST resta cliccabile: sceglierlo funziona.
    await t.tap(find.byType(InkWell).first);
    await t.pumpAndSettle();
    await t.tap(find.text('Sostituzione contatore'));
    await t.pumpAndSettle();
    expect(find.text('SOST — Sostituzione contatore'), findsOneWidget);
  });

  testWidgets('ZA02 non viene inventato se il backend non lo restituisce',
      (t) async {
    await t.binding.setSurfaceSize(const Size(1200, 3000));
    await t.pumpWidget(ProviderScope(
      overrides: [
        workOrderTypesProvider.overrideWith((ref) async => const [
              WorkOrderTypeOption(code: 'SOST', label: 'Sostituzione contatore'),
            ]),
      ],
      child: const MaterialApp(home: CreateOrderScreen()),
    ));
    await t.pumpAndSettle();

    await t.tap(find.byType(InkWell).first);
    await t.pumpAndSettle();

    expect(find.text('ZA02'), findsNothing);
  });

  testWidgets(
      'ZA02: le due righe DST si distinguono dal ciclo (CONRCO1 / CONRID1)',
      (t) async {
    await t.binding.setSurfaceSize(const Size(1200, 3000));
    await t.pumpWidget(ProviderScope(
      overrides: [
        workOrderTypesProvider.overrideWith((ref) async => const [
              WorkOrderTypeOption(
                  code: 'ZA02', label: 'Attività Ordinarie Potabile'),
            ]),
        // Come GET /anagrafica/wo-templates?type=ZA02 (tipiOrdine.ts).
        workOrderTemplatesProvider('ZA02').overrideWith((ref) async => const [
              WorkOrderActivityTemplate(
                  woType: 'ZA02',
                  tipoAttivita: 'DST',
                  gruppoCicli: 'CONRCO1',
                  settoreContabile: 'POT',
                  settoreContabileDesc: 'Servizio acqua potabile',
                  predefinita: true),
              WorkOrderActivityTemplate(
                  woType: 'ZA02',
                  tipoAttivita: 'DST',
                  gruppoCicli: 'CONRID1',
                  settoreContabile: 'POT',
                  settoreContabileDesc: 'Servizio acqua potabile'),
            ]),
        workOrderFieldsProvider('ZA02').overrideWith((ref) async => const []),
        orderPrioritiesProvider('ZA02').overrideWith((ref) async => const []),
      ],
      child: const MaterialApp(home: CreateOrderScreen(initialWoType: 'ZA02')),
    ));
    await t.pumpAndSettle();

    await t.tap(find.text('Tipo attività'));
    await t.pumpAndSettle();

    expect(find.text('DST · CONRCO1'), findsWidgets);
    expect(find.text('DST · CONRID1'), findsWidgets);

    await t.tap(find.text('DST · CONRID1').last);
    await t.pumpAndSettle();
    expect(find.textContaining('Ciclo/settore: CONRID1'), findsOneWidget);
  });
}
