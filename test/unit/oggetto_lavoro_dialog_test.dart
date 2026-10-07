// Dialogo "Oggetto del lavoro" (esito): targa obbligatoria con errore in linea,
// descrizione con microfono, i due bottoni restano affiancati.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wfm_mobile/domain/entities/entities.dart';
import 'package:wfm_mobile/presentation/features/esito/esito_screen.dart';

void main() {
  Future<EsitoObject?> Function() apri(WidgetTester t) {
    EsitoObject? risultato;
    var chiuso = false;
    return () async {
      await t.pumpWidget(MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  risultato = await showDialog<EsitoObject>(
                      context: ctx,
                      builder: (_) => const OggettoLavoroDialog());
                  chiuso = true;
                },
                child: const Text('apri'),
              ),
            ),
          ),
        ),
      ));
      await t.tap(find.text('apri'));
      await t.pumpAndSettle();
      return chiuso ? risultato : null;
    };
  }

  testWidgets('senza targa: errore in linea, il dialogo resta aperto',
      (t) async {
    await apri(t)();
    await t.tap(find.text('Aggiungi'));
    await t.pumpAndSettle();

    expect(find.text('Indica la targa o l\'equipment'), findsOneWidget);
    expect(find.text('Oggetto del lavoro'), findsOneWidget);
  });

  testWidgets('la descrizione ha il microfono', (t) async {
    await apri(t)();
    expect(find.byIcon(Icons.mic_none_outlined), findsOneWidget);
    expect(find.byIcon(Icons.qr_code_scanner), findsOneWidget);
  });

  testWidgets('Annulla e Aggiungi stanno sulla stessa riga', (t) async {
    await apri(t)();
    final annulla = t.getCenter(find.text('Annulla')).dy;
    final aggiungi = t.getCenter(find.text('Aggiungi')).dy;
    expect((annulla - aggiungi).abs(), lessThan(4));
  });

  testWidgets('targa + descrizione: restituisce l\'oggetto (targa maiuscola)',
      (t) async {
    EsitoObject? ottenuto;
    await t.pumpWidget(MaterialApp(
      home: Builder(
        builder: (ctx) => Scaffold(
          body: ElevatedButton(
            onPressed: () async => ottenuto = await showDialog<EsitoObject>(
                context: ctx, builder: (_) => const OggettoLavoroDialog()),
            child: const Text('apri'),
          ),
        ),
      ),
    ));
    await t.tap(find.text('apri'));
    await t.pumpAndSettle();

    await t.enterText(find.widgetWithText(TextFormField, 'Targa / Equipment *'),
        'cr812ep');
    await t.enterText(find.widgetWithText(TextFormField, 'Descrizione'),
        '  159 - Fiat Doblò ');
    await t.tap(find.text('Aggiungi'));
    await t.pumpAndSettle();

    expect(ottenuto?.equipment, 'CR812EP');
    expect(ottenuto?.description, '159 - Fiat Doblò');
  });

  testWidgets('Annulla restituisce null', (t) async {
    EsitoObject? ottenuto = const EsitoObject(equipment: 'X');
    await t.pumpWidget(MaterialApp(
      home: Builder(
        builder: (ctx) => Scaffold(
          body: ElevatedButton(
            onPressed: () async => ottenuto = await showDialog<EsitoObject>(
                context: ctx, builder: (_) => const OggettoLavoroDialog()),
            child: const Text('apri'),
          ),
        ),
      ),
    ));
    await t.tap(find.text('apri'));
    await t.pumpAndSettle();
    await t.tap(find.text('Annulla'));
    await t.pumpAndSettle();

    expect(ottenuto, isNull);
  });
}
