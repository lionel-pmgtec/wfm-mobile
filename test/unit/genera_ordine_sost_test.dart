// "Genera OdL" da un avviso: SOST e ZA02 portano al modulo di creazione
// standard (matricola / tipo attività e ciclo); gli altri tipi restano sul
// percorso a 3 passi. Dall'avviso ZI si propone ZA02 (regola del backend).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:wfm_mobile/domain/entities/entities.dart';
import 'package:wfm_mobile/presentation/features/avvisi/sub_screens/genera_ordine_screen.dart';
import 'package:wfm_mobile/presentation/providers/anagrafica_provider.dart';
import 'package:wfm_mobile/presentation/providers/avvisi_provider.dart';

void main() {
  setUpAll(() => initializeDateFormatting('it_IT', null));

  const numero = '000400090202';

  Future<void> apri(WidgetTester t,
      {String tipoAvviso = 'ZH',
      List<WorkOrderTypeOption> tipi = const [
        WorkOrderTypeOption(code: 'SOST', label: 'Sostituzione contatore'),
        WorkOrderTypeOption(code: 'ZF01', label: 'Pronto Intervento Fognatura'),
        WorkOrderTypeOption(code: 'ZA02', label: 'Attività Ordinarie Potabile'),
      ]}) async {
    await t.binding.setSurfaceSize(const Size(1000, 1600));
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const GeneraOrdineScreen(numero: numero)),
      GoRoute(
        path: '/create-order',
        builder: (_, s) => Scaffold(
            body: Text('FORM tipo=${s.uri.queryParameters['type']} '
                'avviso=${s.uri.queryParameters['avviso']}')),
      ),
    ]);
    await t.pumpWidget(ProviderScope(
      overrides: [
        avvisoDetailProvider(numero).overrideWith((ref) async =>
            NotificationAvviso(
                numeroAvviso: numero,
                descrizione: 'Perdita su PEAD 90',
                tipo: tipoAvviso)),
        workOrderTypesProvider.overrideWith((ref) async => tipi),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await t.pumpAndSettle();
  }

  bool selezionato(WidgetTester t, String code) => find
      .ancestor(of: find.text(code), matching: find.byType(InkWell))
      .evaluate()
      .any((e) => find
          .descendant(
              of: find.byWidget(e.widget),
              matching: find.byIcon(Icons.check_circle))
          .evaluate()
          .isNotEmpty);

  testWidgets('SOST + Avanti apre il modulo standard con l\'avviso d\'origine',
      (t) async {
    await apri(t);
    await t.tap(find.text('SOST'));
    await t.pump();
    await t.tap(find.text('Avanti'));
    await t.pumpAndSettle();
    expect(find.text('FORM tipo=SOST avviso=$numero'), findsOneWidget);
  });

  testWidgets('solo SOST e ZA02 sono scegliibili: gli altri sono grigi',
      (t) async {
    await apri(t, tipi: const [
      WorkOrderTypeOption(code: 'SOST', label: 'Sostituzione contatore'),
      WorkOrderTypeOption(code: 'ZF01', label: 'Pronto Intervento Fognatura'),
      WorkOrderTypeOption(code: 'ZMAV', label: 'Manutenzione varie'),
      WorkOrderTypeOption(code: 'ZA02', label: 'Attività Ordinarie Potabile'),
    ]);

    // Tutti restano visibili.
    for (final c in ['SOST', 'ZF01', 'ZMAV', 'ZA02']) {
      expect(find.text(c), findsOneWidget, reason: c);
    }
    // Grigi (opacità ridotta, lucchetto) solo ZF01 e ZMAV.
    double opacita(String code) => t
        .widget<Opacity>(find
            .ancestor(of: find.text(code), matching: find.byType(Opacity))
            .first)
        .opacity;
    expect(opacita('SOST'), 1);
    expect(opacita('ZA02'), 1);
    expect(opacita('ZF01'), lessThan(1));
    expect(opacita('ZMAV'), lessThan(1));
    expect(find.byIcon(Icons.lock_outline), findsNWidgets(2));
  });

  testWidgets('toccare un tipo grigio non lo seleziona', (t) async {
    await apri(t);
    await t.tap(find.text('ZF01'));
    await t.pump();
    expect(selezionato(t, 'ZF01'), isFalse);

    // Senza un tipo abilitato Avanti non porta da nessuna parte.
    await t.tap(find.text('Avanti'));
    await t.pumpAndSettle();
    expect(find.textContaining('FORM tipo='), findsNothing);
    expect(find.text('ATTIVITÀ'), findsNothing);
  });

  testWidgets('avviso ZI: ZA02 già proposto, Avanti apre il modulo ZA02',
      (t) async {
    await apri(t, tipoAvviso: 'ZI');
    expect(selezionato(t, 'ZA02'), isTrue);

    await t.tap(find.text('Avanti'));
    await t.pumpAndSettle();
    expect(find.text('FORM tipo=ZA02 avviso=$numero'), findsOneWidget);
  });

  testWidgets('avviso ZH: nessun tipo proposto (si sceglie a mano)',
      (t) async {
    await apri(t, tipoAvviso: 'ZH');
    expect(selezionato(t, 'ZA02'), isFalse);
    expect(selezionato(t, 'SOST'), isFalse);
  });

  testWidgets('avviso ZI ma il backend non offre ZA02: nessuna proposta',
      (t) async {
    await apri(t, tipoAvviso: 'ZI', tipi: const [
      WorkOrderTypeOption(code: 'SOST', label: 'Sostituzione contatore'),
    ]);
    expect(find.text('ZA02'), findsNothing);
    expect(selezionato(t, 'SOST'), isFalse);
  });
}
