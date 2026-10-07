// Centro di sincronizzazione: ogni elemento si invia al Cruscotto, che poi lo
// propaga a SAP. Non c'è più un pulsante "SAP" separato (l'invio diretto a SAP
// non è implementato).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:wfm_mobile/domain/entities/entities.dart';
import 'package:wfm_mobile/presentation/features/sync/sync_center_screen.dart';
import 'package:wfm_mobile/presentation/providers/creation_provider.dart';
import 'package:wfm_mobile/presentation/providers/sync_provider.dart';

void main() {
  setUpAll(() => initializeDateFormatting('it_IT', null));

  Future<void> apri(WidgetTester t) async {
    await t.binding.setSurfaceSize(const Size(1000, 1600));
    await t.pumpWidget(ProviderScope(
      overrides: [
        createdWorkOrdersProvider.overrideWith((ref) async => [
              WorkOrder(
                  externalCode: 'TMP-ODL-1',
                  woType: 'SOST',
                  woTypeDescription: 'test',
                  createdAt: DateTime(2026, 9, 29)),
            ]),
        createdAvvisiProvider
            .overrideWith((ref) async => <NotificationAvviso>[]),
        syncQueueProvider.overrideWith((ref) async => <SyncOperation>[]),
      ],
      child: const MaterialApp(home: SyncCenterScreen()),
    ));
    await t.pumpAndSettle();
  }

  testWidgets('solo "Cruscotto": nessun pulsante "SAP" e l\'invio è attivo',
      (t) async {
    await apri(t);
    expect(find.text('SAP'), findsNothing);
    expect(find.text('Invio tramite il Cruscotto.'), findsOneWidget);
    final cruscotto = t.widget<ButtonStyleButton>(find.ancestor(
        of: find.text('Sincronizza'),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton)));
    expect(cruscotto.enabled, isTrue);
  });
}
