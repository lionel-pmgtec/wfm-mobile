// "Storico appuntamenti" non è ancora implementato: nel menu ⋮ dell'OdL resta
// visibile ma spento (non selezionabile), come le altre voci restano attive.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wfm_mobile/domain/entities/entities.dart';
import 'package:wfm_mobile/presentation/features/work_orders/widgets/odl_actions_menu.dart';

void main() {
  const odl = WorkOrder(
      externalCode: '000090000006',
      woType: 'SOST',
      status: WorkOrderStatus.inEsecuzione);

  Future<List<String>> apri(WidgetTester t) async {
    final aperte = <String>[];
    final router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const Scaffold(
          body: Align(
              alignment: Alignment.topRight,
              child: OdlActionsMenu(code: '000090000006', order: odl)),
        ),
      ),
      GoRoute(
        path: '/work-orders/:id/storico-appuntamenti',
        builder: (_, s) {
          aperte.add('storico');
          return const Scaffold(body: Text('SCHERMATA STORICO'));
        },
      ),
      GoRoute(
        path: '/work-orders/:id/appointments',
        builder: (_, s) => const Scaffold(body: Text('SCHERMATA APPUNTAMENTI')),
      ),
    ]);
    await t.pumpWidget(
        ProviderScope(child: MaterialApp.router(routerConfig: router)));
    await t.pumpAndSettle();
    await t.tap(find.byType(PopupMenuButton<String>));
    await t.pumpAndSettle();
    return aperte;
  }

  testWidgets('la voce Storico è presente ma grigia', (t) async {
    await apri(t);

    final voce = find.ancestor(
        of: find.text('Storico appuntamenti (non ancora disponibile)'),
        matching: find.byType(PopupMenuItem<String>));
    expect(voce, findsOneWidget);
    expect(t.widget<PopupMenuItem<String>>(voce).enabled, isFalse);
  });

  testWidgets('toccarla non apre nessuna schermata', (t) async {
    final aperte = await apri(t);

    await t.tap(find.text('Storico appuntamenti (non ancora disponibile)'),
        warnIfMissed: false);
    await t.pumpAndSettle();

    expect(find.text('SCHERMATA STORICO'), findsNothing);
    expect(aperte, isEmpty);
  });

  testWidgets('le altre voci restano attive (es. Sospensioni)', (t) async {
    await apri(t);

    final voce = find.ancestor(
        of: find.text('Sospensioni'),
        matching: find.byType(PopupMenuItem<String>));
    expect(t.widget<PopupMenuItem<String>>(voce).enabled, isTrue);
  });
}
