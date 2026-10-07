// "Ricerca contatore" (OdL senza contatore): la matricola è il numero di serie,
// quindi si può leggere col QR/barcode come già il campo Barcode.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:wfm_mobile/core/router/app_routes.dart';
import 'package:wfm_mobile/domain/entities/entities.dart';
import 'package:wfm_mobile/presentation/features/meter/meter_screen.dart';
import 'package:wfm_mobile/presentation/providers/work_orders_provider.dart';

const _code = '000090000006';

void main() {
  setUpAll(() => initializeDateFormatting('it_IT', null));

  Future<void> apri(WidgetTester t, {String letto = '000000000090000212'}) async {
    await t.binding.setSurfaceSize(const Size(1000, 1600));
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const MeterScreen(code: _code)),
      GoRoute(
        path: AppRoutes.scanner,
        // Scanner simulato: torna subito il codice letto.
        builder: (_, __) => Builder(builder: (context) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => Navigator.of(context).pop(letto));
          return const SizedBox.shrink();
        }),
      ),
    ]);
    await t.pumpWidget(ProviderScope(
      overrides: [
        workOrderDetailProvider(_code).overrideWith(
            (ref) async => const WorkOrder(externalCode: _code, woType: 'DISA')),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await t.pumpAndSettle();
  }

  Finder campo(String etichetta) => find.widgetWithText(TextField, etichetta);

  testWidgets('il campo Matricola ha l\'icona di scansione', (t) async {
    await apri(t);
    expect(
        find.descendant(
            of: campo('Matricola'), matching: find.byIcon(Icons.qr_code_scanner)),
        findsOneWidget);
  });

  testWidgets('il codice letto riempie la Matricola e non il Barcode',
      (t) async {
    await apri(t);
    await t.tap(find.descendant(
        of: campo('Matricola'), matching: find.byIcon(Icons.qr_code_scanner)));
    await t.pumpAndSettle();

    expect(
        t.widget<TextField>(campo('Matricola')).controller!.text,
        '000000000090000212');
    expect(t.widget<TextField>(campo('Barcode')).controller!.text, isEmpty);
  });

  testWidgets('lo scanner del Barcode funziona come prima', (t) async {
    await apri(t, letto: 'BC-777');
    // Il campo Barcode ha il suo pulsante (tonal) accanto.
    await t.tap(find.byTooltip('Scansiona'));
    await t.pumpAndSettle();

    expect(t.widget<TextField>(campo('Barcode')).controller!.text, 'BC-777');
    expect(t.widget<TextField>(campo('Matricola')).controller!.text, isEmpty);
  });
}
