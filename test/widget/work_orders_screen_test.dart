// Test widget — elenco OdL con provider sovrascritto (dati deterministici).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:wfm_mobile/domain/entities/entities.dart';
import 'package:wfm_mobile/presentation/features/work_orders/work_orders_screen.dart';
import 'package:wfm_mobile/presentation/providers/work_orders_provider.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('it_IT', null);
  });

  final sample = WorkOrder(
    externalCode: '12345678',
    woType: 'ATTI',
    woTypeDescription: 'Apertura contatore di test',
    status: WorkOrderStatus.ricevuto,
    appointmentDate: DateTime(2026, 5, 28),
    appointmentStartTime: '10:00',
    address: const Address(city: 'ANCONA', street: 'VIA TEST', streetNumber: '1'),
  );

  testWidgets('mostra gli OdL forniti dal provider', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workOrdersProvider.overrideWith((ref) async => [sample]),
        ],
        child: const MaterialApp(home: WorkOrdersScreen()),
      ),
    );
    // Risolve il future e ricostruisce.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Ordini di Lavoro'), findsOneWidget);
    expect(find.text('12345678'), findsOneWidget);
    expect(find.text('Apertura contatore di test'), findsOneWidget);
  });

  testWidgets('stato vuoto quando non ci sono OdL', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workOrdersProvider.overrideWith((ref) async => <WorkOrder>[]),
        ],
        child: const MaterialApp(home: WorkOrdersScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Nessun OdL trovato'), findsOneWidget);
  });
}
