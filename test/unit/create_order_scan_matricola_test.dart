// "Matricola contatore da sostituire" (Dati specifici, SOST): deve poter
// essere letta col QR/barcode, come il "Numero di serie" in Gestione contatore
// (è lo stesso dato: la matricola È il numero di serie del contatore).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:wfm_mobile/core/router/app_routes.dart';
import 'package:wfm_mobile/domain/entities/entities.dart';
import 'package:wfm_mobile/presentation/features/create_order/create_order_screen.dart';
import 'package:wfm_mobile/presentation/providers/anagrafica_provider.dart';

void main() {
  setUpAll(() => initializeDateFormatting('it_IT', null));

  Future<void> apri(WidgetTester t, {required String codiceScannerizzato}) async {
    await t.binding.setSurfaceSize(const Size(1200, 3000));
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const CreateOrderScreen()),
      // Sostituisce lo scanner reale (fotocamera): simula una lettura riuscita.
      GoRoute(
        path: AppRoutes.scanner,
        builder: (_, __) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: null, // il tap avviene sul bottone stesso più sotto
              child: const Text('scan'),
            ),
          ),
        ),
      ),
    ]);
    await t.pumpWidget(ProviderScope(
      overrides: [
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
      child: MaterialApp.router(routerConfig: router),
    ));
    await t.pumpAndSettle();

    // Seleziona SOST (match code) per far comparire "Dati specifici".
    await t.tap(find.byType(InkWell).first);
    await t.pumpAndSettle();
    await t.tap(find.text('Sostituzione contatore'));
    await t.pumpAndSettle();
  }

  testWidgets('compare l\'icona di scansione sul campo matricola', (t) async {
    await apri(t, codiceScannerizzato: '12345678');
    expect(
        find.descendant(
            of: find.widgetWithText(
                TextFormField, 'Matricola contatore da sostituire *'),
            matching: find.byIcon(Icons.qr_code_scanner)),
        findsOneWidget);
  });

  testWidgets('il codice letto dallo scanner riempie il campo matricola', (t) async {
    await t.binding.setSurfaceSize(const Size(1200, 3000));
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const CreateOrderScreen()),
      GoRoute(
        path: AppRoutes.scanner,
        // Simula lo scanner: torna subito il codice letto.
        builder: (_, state) => Builder(builder: (context) {
          WidgetsBinding.instance.addPostFrameCallback(
              (_) => Navigator.of(context).pop('000000000090000212'));
          return const SizedBox.shrink();
        }),
      ),
    ]);
    await t.pumpWidget(ProviderScope(
      overrides: [
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
      child: MaterialApp.router(routerConfig: router),
    ));
    await t.pumpAndSettle();
    await t.tap(find.byType(InkWell).first);
    await t.pumpAndSettle();
    await t.tap(find.text('Sostituzione contatore'));
    await t.pumpAndSettle();

    await t.tap(find.byIcon(Icons.qr_code_scanner));
    await t.pumpAndSettle();

    expect(find.text('000000000090000212'), findsOneWidget);
  });
}
