// "Data e ora appuntamento" = il rendez-vous preso col CLIENTE. Non è la data
// di esecuzione dell'OdL, e il tablet non le confonde:
// - l'inizio dell'intervento (chiusura) è quando il tecnico preme "Avvia", mai
//   la data/ora dell'appuntamento né una data di pianificazione;
// - nella lista la data dice cos'è: "Appuntamento …" solo se il cliente ne ha
//   uno, altrimenti "Inizio …" (pianificazione).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:wfm_mobile/core/utils/formatters.dart';
import 'package:wfm_mobile/domain/entities/entities.dart';
import 'package:wfm_mobile/domain/repositories/odl_extension_repository.dart';
import 'package:wfm_mobile/presentation/features/esito/esito_screen.dart';
import 'package:wfm_mobile/presentation/features/work_orders/widgets/work_order_card.dart';
import 'package:wfm_mobile/presentation/providers/anagrafica_provider.dart';
import 'package:wfm_mobile/presentation/providers/core_providers.dart';
import 'package:wfm_mobile/presentation/providers/work_orders_provider.dart';

class _RepoExt implements OdlExtensionRepository {
  final OdlExtension ext;
  _RepoExt(this.ext);
  @override
  Future<OdlExtension> get(String c) async => ext;
  @override
  Future<void> save(OdlExtension e) async {}
  @override
  Future<void> clear(String c) async {}
}

// Appuntamento col cliente il 22/10/2026 alle 09:30; inizio cardine 20/10;
// fine cardine (data esecuzione SAP) 25/10.
final _conAppuntamento = WorkOrder(
  externalCode: 'X1',
  woType: 'ZA02',
  appointmentDate: DateTime(2026, 10, 22),
  appointmentStartTime: '09:30',
  dataInizio: DateTime(2026, 10, 20),
  dataEsec: DateTime(2026, 10, 25),
  createdAt: DateTime(2026, 10, 1),
);

void main() {
  setUpAll(() => initializeDateFormatting('it_IT', null));

  group('card della lista', () {
    Future<void> mostra(WidgetTester t, WorkOrder o) => t.pumpWidget(
        ProviderScope(
            child: MaterialApp(
                home: Scaffold(body: WorkOrderCard(order: o, onTap: () {})))));

    testWidgets('con appuntamento del cliente: "Appuntamento" con data e ora',
        (t) async {
      await mostra(t, _conAppuntamento);
      expect(find.textContaining('Appuntamento 22/10/2026 09:30'),
          findsOneWidget);
    });

    testWidgets('senza appuntamento: "Inizio" (pianificazione), non "Appuntamento"',
        (t) async {
      await mostra(
          t,
          WorkOrder(
              externalCode: 'X2',
              woType: 'ZA02',
              dataInizio: DateTime(2026, 10, 7)));
      expect(find.textContaining('Inizio 07/10/2026'), findsOneWidget);
      expect(find.textContaining('Appuntamento'), findsNothing);
    });

    testWidgets('senza altre date: la creazione, con la sua etichetta',
        (t) async {
      await mostra(
          t,
          WorkOrder(
              externalCode: 'X3',
              woType: 'ZA02',
              createdAt: DateTime(2026, 10, 1)));
      expect(find.textContaining('Creato 01/10/2026'), findsOneWidget);
    });
  });

  group("inizio dell'intervento alla chiusura", () {
    Future<void> apri(WidgetTester t, OdlExtension ext) async {
      await t.binding.setSurfaceSize(const Size(1200, 3000));
      await t.pumpWidget(ProviderScope(
        overrides: [
          odlExtensionRepositoryProvider.overrideWithValue(_RepoExt(ext)),
          workOrderDetailProvider('X1')
              .overrideWith((ref) async => _conAppuntamento),
          causeCodesProvider.overrideWith((ref) async => const []),
          solutionCodesProvider.overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(home: Scaffold(body: EsitoScreen(code: 'X1'))),
      ));
      await t.pumpAndSettle();
    }

    testWidgets("non parte dall'appuntamento né dalle date di pianificazione",
        (t) async {
      await apri(t, OdlExtension.empty('X1')); // mai premuto "Avvia"
      // Né il rendez-vous (22/10), né l'inizio cardine (20/10), né la fine (25/10).
      expect(find.textContaining('22/10/2026'), findsNothing);
      expect(find.textContaining('20/10/2026'), findsNothing);
      expect(find.textContaining('25/10/2026'), findsNothing);
      // Parte da adesso (oggi), che l'operatore può correggere.
      expect(find.textContaining(Fmt.date(DateTime.now())), findsWidgets);
    });

    testWidgets('con "Avvia" premuto: l\'inizio è quell\'ora', (t) async {
      final avvio = DateTime(2026, 10, 6, 8, 15);
      await apri(
          t, OdlExtension.empty('X1').copyWith(avviatoIl: avvio));
      expect(find.textContaining('06/10/2026 08:15'), findsOneWidget);
      expect(find.textContaining('22/10/2026'), findsNothing);
    });
  });
}
