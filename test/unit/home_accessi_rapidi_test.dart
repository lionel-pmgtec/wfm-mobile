// Accessi rapidi della Home: Crea OdL, Crea avviso, Standalone (il pulsante
// Scanner è stato tolto; lo scanner resta nei campi matricola).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:wfm_mobile/core/router/app_routes.dart';
import 'package:wfm_mobile/presentation/features/home/home_screen.dart';
import 'package:wfm_mobile/presentation/providers/avvisi_provider.dart';
import 'package:wfm_mobile/presentation/providers/work_orders_provider.dart';

void main() {
  setUpAll(() => initializeDateFormatting('it_IT', null));

  Future<List<String>> apri(WidgetTester t) async {
    final aperti = <String>[];
    await t.binding.setSurfaceSize(const Size(1000, 1800));
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
      GoRoute(
          path: AppRoutes.createAvviso,
          builder: (_, __) {
            aperti.add('avviso');
            return const Text('nuovo avviso');
          }),
      GoRoute(
          path: AppRoutes.createOrder,
          builder: (_, __) {
            aperti.add('odl');
            return const Text('nuovo odl');
          }),
    ]);
    await t.pumpWidget(ProviderScope(
      overrides: [
        dashboardStatsProvider.overrideWith((ref) async => {}),
        prontoInterventoAvvisiProvider.overrideWith((ref) async => []),
        prontoInterventoWorkOrdersProvider.overrideWith((ref) async => []),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await t.pump();
    await t.pump();
    return aperti;
  }

  testWidgets('Scanner non c\'è più, al suo posto Crea avviso', (t) async {
    await apri(t);
    expect(find.text('Scanner'), findsNothing);
    expect(find.text('Crea avviso'), findsOneWidget);
    expect(find.text('Crea OdL'), findsOneWidget);
    expect(find.text('Standalone'), findsOneWidget);
  });

  testWidgets('Crea avviso apre il modulo di creazione avviso', (t) async {
    final aperti = await apri(t);
    await t.tap(find.text('Crea avviso'));
    await t.pumpAndSettle();
    expect(aperti, ['avviso']);
  });
}
