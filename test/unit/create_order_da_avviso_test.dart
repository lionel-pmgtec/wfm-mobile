// "SOST da un avviso": il modulo di creazione si apre precompilato con i dati
// dell'avviso (indirizzo, cliente, sede, matricola) e col legame all'avviso.

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

  const numero = '000400090202';
  const avviso = NotificationAvviso(
    numeroAvviso: numero,
    descrizione: 'Contatore fermo - richiesta sostituzione',
    tipo: 'ZH',
    sedeTecnica: '10021650',
    matricola: '000000000090000212',
    cellulare: '3391000212',
    address: Address(
        street: 'VIA DELLE QUERCE', streetNumber: '4', city: 'OSIMO'),
    customer: Customer(nome: 'Elena', cognome: 'Viola'),
  );

  Future<void> apri(WidgetTester t, {String? avvisoOrigine}) async {
    await t.binding.setSurfaceSize(const Size(1200, 3000));
    await t.pumpWidget(ProviderScope(
      overrides: [
        avvisoDetailProvider(numero).overrideWith((ref) async => avviso),
        workOrderTypesProvider.overrideWith((ref) async => const [
              WorkOrderTypeOption(code: 'SOST', label: 'Sostituzione contatore'),
            ]),
        workOrderFieldsProvider('SOST').overrideWith((ref) async => const [
              DynFieldSpec(
                  key: 'matricola',
                  label: 'Matricola contatore da sostituire',
                  required: true),
            ]),
        workOrderTemplatesProvider('SOST').overrideWith((ref) async => const []),
        orderPrioritiesProvider('SOST').overrideWith((ref) async => const []),
      ],
      child: MaterialApp(
        home: CreateOrderScreen(initialWoType: 'SOST', originAvviso: avvisoOrigine),
      ),
    ));
    await t.pumpAndSettle();
  }

  testWidgets('da avviso: precompila indirizzo, cliente, sede, matricola e legame',
      (t) async {
    await apri(t, avvisoOrigine: numero);

    // Legame all'avviso (sola lettura) e descrizione dell'avviso.
    expect(find.text('Notifica Precedente'), findsOneWidget);
    expect(find.text(numero), findsOneWidget);
    expect(find.text('Contatore fermo - richiesta sostituzione'), findsOneWidget);
    // Indirizzo, cliente, sede.
    expect(find.text('VIA DELLE QUERCE'), findsOneWidget);
    expect(find.text('OSIMO'), findsOneWidget);
    expect(find.text('Elena'), findsOneWidget);
    expect(find.text('Viola'), findsOneWidget);
    expect(find.text('3391000212'), findsOneWidget);
    expect(find.text('10021650'), findsOneWidget);
    // La matricola che il backend pretende per la SOST.
    expect(find.text('000000000090000212'), findsOneWidget);
  });

  testWidgets('creazione libera: nessun legame né precompilazione', (t) async {
    await apri(t);
    expect(find.text('Notifica Precedente'), findsNothing);
    expect(find.text('VIA DELLE QUERCE'), findsNothing);
    expect(find.text('000000000090000212'), findsNothing);
  });
}
