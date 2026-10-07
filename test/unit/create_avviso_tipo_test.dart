// "Nuovo Avviso".
// - Tipo avviso (match code): per la demo sono cliccabili solo IS e ZI, con
//   l'etichetta del backend; gli altri tipi del cruscotto (es. ZH) sono grigi.
// - Priorità: codice dello schema del TIPO (GET /anagrafica/priorities?type=):
//   IS 1 Non programmata / 2 Programmata; ZI 1/2/4/6. Senza tipo non si sceglie.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wfm_mobile/core/widgets/match_code_field.dart';
import 'package:wfm_mobile/domain/entities/esito.dart';
import 'package:wfm_mobile/presentation/features/create_order/create_avviso_screen.dart';
import 'package:wfm_mobile/presentation/providers/anagrafica_provider.dart';

void main() {
  Future<void> apri(WidgetTester t) async {
    await t.binding.setSurfaceSize(const Size(1200, 3000));
    await t.pumpWidget(ProviderScope(
      overrides: [
        lookupProvider('avviso-types').overrideWith((ref) async => const [
              CodeLabel('ZH', 'Pronto Intervento H2O'),
            ]),
        // Come GET /anagrafica/priorities?type=IS|ZI del backend (verificato).
        orderPrioritiesProvider('IS').overrideWith((ref) async => const [
              CodeLabel('1', 'Non programmata'),
              CodeLabel('2', 'Programmata'),
            ]),
        orderPrioritiesProvider('ZI').overrideWith((ref) async => const [
              CodeLabel('1', 'Guasto semplice'),
              CodeLabel('2', 'Disservizio'),
              CodeLabel('4', 'Problema non aziend.'),
              CodeLabel('6', 'Altro'),
            ]),
      ],
      child: const MaterialApp(home: CreateAvvisoScreen()),
    ));
    await t.pumpAndSettle();
  }

  Future<void> scegliTipo(WidgetTester t, String code) async {
    await t.tap(find.byType(MatchCodeField<String>));
    await t.pumpAndSettle();
    await t.tap(find.text(code));
    await t.pumpAndSettle();
  }

  testWidgets('IS e ZI con l\'etichetta del backend, niente "per il test"',
      (t) async {
    await apri(t);
    await t.tap(find.text('Tocca per scegliere il tipo di avviso…'));
    await t.pumpAndSettle();

    expect(find.text('Interruzione di servizio'), findsOneWidget);
    expect(find.text('Investimento H2O'), findsOneWidget);
    expect(find.textContaining('per il test'), findsNothing);
  });

  testWidgets('IS è cliccabile e seleziona il tipo', (t) async {
    await apri(t);
    await scegliTipo(t, 'IS');
    expect(find.text('IS — Interruzione di servizio'), findsOneWidget);
  });

  testWidgets('ZI è cliccabile e seleziona il tipo', (t) async {
    await apri(t);
    await scegliTipo(t, 'ZI');
    expect(find.text('ZI — Investimento H2O'), findsOneWidget);
  });

  testWidgets('ZH (dal cruscotto) compare grigio: il tocco non seleziona nulla',
      (t) async {
    await apri(t);
    await t.tap(find.text('Tocca per scegliere il tipo di avviso…'));
    await t.pumpAndSettle();

    expect(find.text('Pronto Intervento H2O'), findsOneWidget);
    await t.tap(find.text('Pronto Intervento H2O'));
    await t.pumpAndSettle();

    // Pannello ancora aperto: nessuna selezione avvenuta.
    expect(find.text('Pronto Intervento H2O'), findsOneWidget);
    expect(find.text('Tocca per scegliere il tipo di avviso…'), findsOneWidget);
  });

  testWidgets('priorità: senza tipo non si sceglie', (t) async {
    await apri(t);
    expect(find.text('Scegli prima il tipo avviso'), findsOneWidget);
  });

  testWidgets('priorità di un IS: schema IS (1 / 2)', (t) async {
    await apri(t);
    await scegliTipo(t, 'IS');

    await t.tap(find.text('Priorità'));
    await t.pumpAndSettle();
    expect(find.text('1 — Non programmata'), findsWidgets);
    expect(find.text('2 — Programmata'), findsWidgets);
    expect(find.text('4 — Problema non aziend.'), findsNothing);
  });

  testWidgets('cambiando tipo, la priorità scelta si azzera', (t) async {
    await apri(t);
    await scegliTipo(t, 'IS');
    await t.tap(find.text('Priorità'));
    await t.pumpAndSettle();
    await t.tap(find.text('2 — Programmata').last);
    await t.pumpAndSettle();
    expect(find.text('2 — Programmata'), findsOneWidget);

    await scegliTipo(t, 'ZI');
    // "2" in ZI sarebbe "Disservizio": non deve restare selezionato.
    expect(find.text('2 — Disservizio'), findsNothing);
    expect(find.text('2 — Programmata'), findsNothing);
  });
}
