// Novità in cima alla lista e "2 min fa" accanto alla priorità.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:wfm_mobile/core/services/arrival_store.dart';
import 'package:wfm_mobile/core/widgets/tempo_fa.dart';
import 'package:wfm_mobile/domain/entities/entities.dart';
import 'package:wfm_mobile/presentation/features/work_orders/widgets/work_order_card.dart';

void main() {
  setUpAll(() => initializeDateFormatting('it_IT', null));
  setUp(ArrivalStore.resetForTests);

  group('formato del tempo', () {
    test('secondi, minuti, ore, giorni', () {
      expect(formatTempoFa(Duration.zero), 'adesso');
      expect(formatTempoFa(const Duration(seconds: 1)), 'adesso');
      expect(formatTempoFa(const Duration(seconds: 2)), '2 sec fa');
      expect(formatTempoFa(const Duration(seconds: 59)), '59 sec fa');
      expect(formatTempoFa(const Duration(seconds: 60)), '1 min fa');
      expect(formatTempoFa(const Duration(minutes: 5, seconds: 40)), '5 min fa');
      expect(formatTempoFa(const Duration(minutes: 59)), '59 min fa');
      expect(formatTempoFa(const Duration(hours: 3)), '3 h fa');
      expect(formatTempoFa(const Duration(hours: 50)), '2 g fa');
      expect(formatTempoFa(const Duration(seconds: -5)), 'adesso');
    });
  });

  group('registro arrivi', () {
    test('il primo elenco fa da riferimento: nessuna ora, ordine del backend', () async {
      await ArrivalStore.seen('odl', ['A', 'B', 'C']);
      expect(ArrivalStore.of('odl', 'A'), isNull);
      expect(ArrivalStore.sortNewestFirst(['A', 'B', 'C'], 'odl', (x) => x),
          ['A', 'B', 'C']);
    });

    test('un oggetto arrivato dopo il riferimento risulta nuovo e va in CIMA', () async {
      await ArrivalStore.seen('odl', ['A', 'B', 'C']); // riferimento
      await ArrivalStore.seen('odl', ['A', 'B', 'C', 'D']); // D è nuovo
      expect(ArrivalStore.of('odl', 'D'), isNotNull);
      expect(ArrivalStore.of('odl', 'D')!.difference(DateTime.now()).inSeconds.abs(), lessThan(5));
      // Il backend lo dà in FONDO (ordine di arrivo): deve salire in cima.
      expect(ArrivalStore.sortNewestFirst(['A', 'B', 'C', 'D'], 'odl', (x) => x),
          ['D', 'A', 'B', 'C']);
    });

    test('due arrivi: il più recente per primo', () async {
      await ArrivalStore.seen('odl', ['A']);
      await ArrivalStore.seen('odl', ['A', 'B']);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await ArrivalStore.seen('odl', ['A', 'B', 'C']);
      expect(ArrivalStore.sortNewestFirst(['A', 'B', 'C'], 'odl', (x) => x),
          ['C', 'B', 'A']);
    });

    test('un OdL creato sulla tablet è subito in cima', () async {
      await ArrivalStore.seen('odl', ['A', 'B']);
      await ArrivalStore.arrivedNow('odl', 'TMP-1');
      expect(ArrivalStore.sortNewestFirst(['A', 'B', 'TMP-1'], 'odl', (x) => x).first,
          'TMP-1');
    });

    test('OdL e avvisi non si mescolano', () async {
      await ArrivalStore.seen('odl', ['A']);
      await ArrivalStore.seen('avv', ['A']); // riferimento anche per gli avvisi
      await ArrivalStore.seen('avv', ['A', 'N']);
      expect(ArrivalStore.of('avv', 'N'), isNotNull);
      expect(ArrivalStore.of('odl', 'N'), isNull);
    });

    test('un oggetto già registrato non "ringiovanisce"', () async {
      await ArrivalStore.seen('odl', ['A']);
      await ArrivalStore.seen('odl', ['A', 'B']);
      final t1 = ArrivalStore.of('odl', 'B');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await ArrivalStore.seen('odl', ['A', 'B']);
      expect(ArrivalStore.of('odl', 'B'), t1);
    });

    test('sopravvive alla chiusura dell\'app', () async {
      final tmp = Directory.systemTemp.createTempSync('wfm_arr_');
      try {
        await ArrivalStore.open(hivePath: tmp.path);
        await ArrivalStore.seen('odl', ['A']);
        await ArrivalStore.seen('odl', ['A', 'B']);
        final t = ArrivalStore.of('odl', 'B');
        await Hive.close();
        ArrivalStore.resetForTests();
        await ArrivalStore.open(hivePath: tmp.path);
        expect(ArrivalStore.of('odl', 'B'), t);
        expect(ArrivalStore.of('odl', 'A'), isNull); // era il riferimento
        // il riferimento resta tale: un nuovo elenco non lo rende "nuovo"
        await ArrivalStore.seen('odl', ['A', 'B', 'C']);
        expect(ArrivalStore.of('odl', 'C'), isNotNull);
        expect(ArrivalStore.of('odl', 'A'), isNull);
      } finally {
        await Hive.close();
        tmp.deleteSync(recursive: true);
      }
    });
  });

  group('widget TempoFa', () {
    Future<void> pump(WidgetTester t, Duration eta) async {
      await t.pumpWidget(MaterialApp(
          home: Scaffold(
              body: TempoFa(since: DateTime.now().subtract(eta)))));
      await t.pump();
    }

    testWidgets('secondi', (t) async {
      await pump(t, const Duration(seconds: 12));
      expect(find.text('12 sec fa'), findsOneWidget);
    });

    testWidgets('minuti', (t) async {
      await pump(t, const Duration(minutes: 5, seconds: 20));
      expect(find.text('5 min fa'), findsOneWidget);
    });

    testWidgets('ore e giorni (senza timer)', (t) async {
      await pump(t, const Duration(hours: 3));
      expect(find.text('3 h fa'), findsOneWidget);
      await pump(t, const Duration(days: 2));
      expect(find.text('2 g fa'), findsOneWidget);
    });
  });

  group('carta OdL', () {
    Future<void> pump(WidgetTester t, WorkOrder o) async {
      await t.pumpWidget(ProviderScope(
        child: MaterialApp(home: Scaffold(body: WorkOrderCard(order: o, onTap: () {}))),
      ));
      await t.pump();
    }

    const order = WorkOrder(externalCode: 'X1', woType: 'SOST', priorita: 'Programmato');

    testWidgets('mostra "min fa" accanto alla priorità per un OdL arrivato', (t) async {
      await ArrivalStore.seen('odl', ['ALTRO']); // riferimento
      await ArrivalStore.seen('odl', ['ALTRO', 'X1']);
      await pump(t, order);
      expect(find.text('Programmato'), findsOneWidget);
      expect(find.text('adesso'), findsOneWidget);
    });

    testWidgets('senza ora di arrivo (riferimento) non mostra nulla', (t) async {
      await ArrivalStore.seen('odl', ['X1']); // X1 era già presente
      await pump(t, order);
      expect(find.text('Programmato'), findsOneWidget);
      expect(find.textContaining(' fa'), findsNothing);
      expect(find.text('adesso'), findsNothing);
    });
  });
}
