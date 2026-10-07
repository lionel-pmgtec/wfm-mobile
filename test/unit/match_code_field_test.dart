// Campo "match code": mostra il valore scelto, il tocco apre l'elenco
// selezionabile (con ricerca oltre 5 voci), la selezione lo chiude e notifica.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wfm_mobile/core/widgets/match_code_field.dart';

void main() {
  Future<void> pump(WidgetTester t, {
    required List<MatchCodeOption<String>> options,
    String? value,
    required ValueChanged<String> onChanged,
    bool Function(MatchCodeOption<String> option)? isOptionEnabled,
  }) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MatchCodeField<String>(
          label: 'Tipo OdL',
          hint: 'Tocca per scegliere…',
          value: value,
          options: options,
          onChanged: onChanged,
          isOptionEnabled: isOptionEnabled,
        ),
      ),
    ));
    await t.pump();
  }

  const opzioni = [
    MatchCodeOption(value: 'SOST', code: 'SOST', label: 'Sostituzione contatore'),
    MatchCodeOption(value: 'ZF01', code: 'ZF01', label: 'Pronto Intervento Fognatura'),
    MatchCodeOption(value: 'ZMAV', code: 'ZMAV', label: 'Manutenzione varie'),
  ];

  testWidgets('senza valore mostra il suggerimento, non un codice a caso', (t) async {
    await pump(t, options: opzioni, value: null, onChanged: (_) {});
    expect(find.text('Tocca per scegliere…'), findsOneWidget);
    expect(find.text('SOST'), findsNothing);
  });

  testWidgets('con un valore scelto mostra "codice — etichetta"', (t) async {
    await pump(t, options: opzioni, value: 'SOST', onChanged: (_) {});
    expect(find.text('SOST — Sostituzione contatore'), findsOneWidget);
  });

  testWidgets('il tocco apre il pannello con tutte le opzioni', (t) async {
    await pump(t, options: opzioni, value: null, onChanged: (_) {});
    await t.tap(find.byType(InkWell));
    await t.pumpAndSettle();
    expect(find.text('Sostituzione contatore'), findsOneWidget);
    expect(find.text('Pronto Intervento Fognatura'), findsOneWidget);
    expect(find.text('Manutenzione varie'), findsOneWidget);
  });

  testWidgets('nessuna ricerca con 5 opzioni o meno', (t) async {
    await pump(t, options: opzioni, value: null, onChanged: (_) {});
    await t.tap(find.byType(InkWell));
    await t.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('con più di 5 opzioni compare la ricerca e filtra', (t) async {
    final tante = [
      for (var i = 0; i < 8; i++)
        MatchCodeOption(value: 'C$i', code: 'C$i', label: 'Tipo numero $i'),
    ];
    await pump(t, options: tante, value: null, onChanged: (_) {});
    await t.tap(find.byType(InkWell));
    await t.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Tipo numero 0'), findsOneWidget); // in cima, visibile

    await t.enterText(find.byType(TextField), 'numero 3');
    await t.pumpAndSettle();
    expect(find.text('Tipo numero 3'), findsOneWidget);
    expect(find.text('Tipo numero 4'), findsNothing);
  });

  testWidgets('selezionare un\'opzione chiude il pannello e notifica il valore giusto',
      (t) async {
    String? scelto;
    await pump(t, options: opzioni, value: null, onChanged: (v) => scelto = v);
    await t.tap(find.byType(InkWell));
    await t.pumpAndSettle();

    await t.tap(find.text('Pronto Intervento Fognatura'));
    await t.pumpAndSettle();

    expect(scelto, 'ZF01');
    expect(find.text('Pronto Intervento Fognatura'), findsNothing); // pannello chiuso
  });

  testWidgets('elenco vuoto: il tocco non apre nulla', (t) async {
    await pump(t, options: const [], value: null, onChanged: (_) {});
    await t.tap(find.byType(InkWell));
    await t.pumpAndSettle();
    expect(find.byType(DraggableScrollableSheet), findsNothing);
  });

  group('isOptionEnabled: blocca le altre voci dopo una scelta', () {
    testWidgets('un\'opzione disabilitata resta visibile ma il tocco non fa nulla',
        (t) async {
      String? scelto;
      await pump(
        t,
        options: opzioni,
        value: 'SOST',
        onChanged: (v) => scelto = v,
        isOptionEnabled: (o) => o.value == 'SOST',
      );
      await t.tap(find.byType(InkWell));
      await t.pumpAndSettle();

      // Ancora visibile (informativa), ma grigia.
      expect(find.text('Manutenzione varie'), findsOneWidget);
      await t.tap(find.text('Manutenzione varie'));
      await t.pumpAndSettle();

      expect(scelto, isNull); // il tocco non ha notificato nulla
      expect(find.text('Manutenzione varie'), findsOneWidget); // pannello ancora aperto
    });

    testWidgets('l\'opzione abilitata (quella già scelta) resta toccabile',
        (t) async {
      String? scelto;
      await pump(
        t,
        options: opzioni,
        value: 'SOST',
        onChanged: (v) => scelto = v,
        isOptionEnabled: (o) => o.value == 'SOST',
      );
      await t.tap(find.byType(InkWell));
      await t.pumpAndSettle();

      await t.tap(find.text('Sostituzione contatore'));
      await t.pumpAndSettle();

      expect(scelto, 'SOST');
    });

    testWidgets('senza predicato (default) tutte le opzioni restano toccabili',
        (t) async {
      String? scelto;
      await pump(t, options: opzioni, value: 'SOST', onChanged: (v) => scelto = v);
      await t.tap(find.byType(InkWell));
      await t.pumpAndSettle();

      await t.tap(find.text('Manutenzione varie'));
      await t.pumpAndSettle();

      expect(scelto, 'ZMAV');
    });
  });
}
