// Indirizzi nella fiche dell'OdL.
//
// Verificato sul backend (toMobile.ts):
//   address (principale) = indirizzoLavoro ?? indirizzo  -> è l'indirizzo di
//   INTERVENTO, non un indirizzo del cliente.
//   - OdL creato dal tablet: i tre campi sono lo stesso indirizzo;
//   - OdL SAP con solo INDIRIZZO: principale = oggetto, intervento = null;
//   - OdL SAP con INDIRIZZO e INDIRIZZO_LAVORO diversi: principale = intervento.
// La fiche mostra "Indirizzo intervento" e ripete oggetto/intervento solo se
// sono diversi.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:wfm_mobile/domain/entities/entities.dart';
import 'package:wfm_mobile/presentation/features/work_orders/work_order_detail_screen.dart';
import 'package:wfm_mobile/presentation/providers/work_orders_provider.dart';

const _oggetto = Address(street: 'VIA OGGETTO', streetNumber: '1', city: 'ANCONA');
const _lavoro = Address(street: 'VIA LAVORO', streetNumber: '9', city: 'ANCONA');
const _tablet = Address(street: 'huhj', streetNumber: 'hhhj', city: 'hhhj');

WorkOrder _odl(
        {required Address principale, Address? oggetto, Address? intervento}) =>
    WorkOrder(
      externalCode: 'X1',
      woType: 'ZA02',
      address: principale,
      indirizzoOggetto: oggetto,
      indirizzoIntervento: intervento,
    );

void main() {
  setUpAll(() => initializeDateFormatting('it_IT', null));

  test('stessoIndirizzo: ignora maiuscole e spazi', () {
    expect(
        stessoIndirizzo(
            const Address(street: 'Via Roma', streetNumber: '1', city: 'Ancona'),
            const Address(street: 'VIA  ROMA', streetNumber: '1', city: 'ANCONA')),
        isTrue);
    expect(stessoIndirizzo(_oggetto, _lavoro), isFalse);
  });

  Future<void> apri(WidgetTester t, WorkOrder o) async {
    await t.binding.setSurfaceSize(const Size(1000, 3000));
    await t.pumpWidget(ProviderScope(
      overrides: [
        workOrderDetailProvider('X1').overrideWith((ref) async => o),
      ],
      child: const MaterialApp(home: WorkOrderDetailScreen(code: 'X1')),
    ));
    await t.pumpAndSettle();
  }

  testWidgets('OdL creato dal tablet: un solo indirizzo, "Indirizzo intervento"',
      (t) async {
    await apri(t,
        _odl(principale: _tablet, oggetto: _tablet, intervento: _tablet));
    expect(find.text('INDIRIZZO INTERVENTO'), findsOneWidget);
    expect(find.text('INDIRIZZO CLIENTE'), findsNothing);
    expect(find.text('INDIRIZZO OGGETTO'), findsNothing);
    expect(find.text('ALTRO INDIRIZZO DI INTERVENTO'), findsNothing);
    expect(find.textContaining('huhj hhhj'), findsOneWidget);
  });

  testWidgets('OdL SAP con solo INDIRIZZO: nessun doppione', (t) async {
    await apri(t, _odl(principale: _oggetto, oggetto: _oggetto));
    expect(find.text('INDIRIZZO INTERVENTO'), findsOneWidget);
    expect(find.text('INDIRIZZO OGGETTO'), findsNothing);
    expect(find.textContaining('VIA OGGETTO 1'), findsOneWidget);
  });

  testWidgets('OdL SAP con oggetto e intervento diversi: oggetto separato',
      (t) async {
    await apri(t,
        _odl(principale: _lavoro, oggetto: _oggetto, intervento: _lavoro));
    expect(find.text('INDIRIZZO INTERVENTO'), findsOneWidget);
    expect(find.textContaining('VIA LAVORO 9'), findsOneWidget);
    expect(find.text('INDIRIZZO OGGETTO'), findsOneWidget);
    expect(find.textContaining('VIA OGGETTO 1'), findsOneWidget);
    expect(find.text('ALTRO INDIRIZZO DI INTERVENTO'), findsNothing);
  });
}
