// Selezione dei materiali e del magazzino.
//
// - Elenco a tendina con caselle da spuntare;
// - per ogni materiale spuntato: i magazzini in cui è disponibile, con la
//   quantità rimanente di ciascuno, e la scelta di quello da cui prelevare;
// - la giacenza è separata per magazzino: prelevare da uno scala solo quello.
//
// Giacenze: `stockPerMagazzino` del backend se c'è; altrimenti lo stock unico
// nel magazzino predefinito (come in anagrafiche.json). I numeri qui sotto sono
// valori di prova dei test (come gli esempi della specifica).

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:wfm_mobile/core/services/giacenze_magazzini_service.dart';
import 'package:wfm_mobile/core/services/stock_impegnato_store.dart';
import 'package:wfm_mobile/data/models/mappers.dart';
import 'package:wfm_mobile/core/network/result.dart';
import 'package:wfm_mobile/domain/entities/entities.dart';
import 'package:wfm_mobile/domain/repositories/anagrafica_repository.dart';
import 'package:wfm_mobile/domain/repositories/odl_extension_repository.dart';
import 'package:wfm_mobile/presentation/features/work_orders/sub_screens/add_componente_screen.dart';
import 'package:wfm_mobile/presentation/providers/anagrafica_provider.dart';
import 'package:wfm_mobile/presentation/providers/core_providers.dart';
import 'package:wfm_mobile/presentation/providers/odl_extension_provider.dart';
import 'package:wfm_mobile/presentation/providers/work_orders_provider.dart';

class _RepoExt implements OdlExtensionRepository {
  final salvati = <OdlExtension>[];
  @override
  Future<OdlExtension> get(String c) async =>
      salvati.isEmpty ? OdlExtension.empty(c) : salvati.last;
  @override
  Future<void> save(OdlExtension e) async => salvati.add(e);
  @override
  Future<void> clear(String c) async {}
}

// Materiali di prova: X in due magazzini (30 e 20), Y in due (30 e 20),
// Z come dà oggi il backend (stock unico nel magazzino predefinito).
const _x = MaterialItem(
    materialCode: 'X',
    description: 'MATERIALE X',
    defaultWarehouseCode: 'W01',
    stockDisponibile: 50,
    stockPerMagazzino: {'W01': 30, 'W02': 20});
const _y = MaterialItem(
    materialCode: 'Y',
    description: 'MATERIALE Y',
    defaultWarehouseCode: 'W01',
    stockPerMagazzino: {'W01': 30, 'W02': 20});
const _z = MaterialItem(
    materialCode: 'Z',
    description: 'MATERIALE Z',
    defaultWarehouseCode: 'W02',
    stockDisponibile: 12);

/// Anagrafica come risponde oggi il backend: stock unico, magazzino predefinito.
class _AnagraficaBackend implements AnagraficaRepository {
  @override
  Future<Result<List<MaterialItem>>> getMaterials({String? query}) async =>
      const Success([
        MaterialItem(
            materialCode: 'M001',
            description: 'Contatore acqua DN15 Maddalena',
            defaultWarehouseCode: 'W01',
            stockDisponibile: 25),
      ]);

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('$i');
}

const _magazzini = [
  Warehouse(code: 'W01', name: 'Magazzino 1'),
  Warehouse(code: 'W02', name: 'Magazzino 2'),
];

void main() {
  setUpAll(() => initializeDateFormatting('it_IT', null));
  setUp(StockImpegnatoStore.resetForTests);

  group('giacenze del materiale', () {
    test('con stockPerMagazzino: quelle del backend', () {
      expect(_x.giacenze, {'W01': 30, 'W02': 20});
    });

    test('solo stock unico (anagrafiche.json): nel magazzino predefinito', () {
      expect(_z.giacenze, {'W02': 12});
    });

    test('mapper: lista [{warehouseCode, quantity}] o mappa {W01: 30}', () {
      final daLista = materialItemFromJson({
        'materialCode': 'X',
        'description': 'x',
        'defaultWarehouseCode': 'W01',
        'stockDisponibile': 50,
        'stockPerMagazzino': [
          {'warehouseCode': 'W01', 'quantity': 30},
          {'warehouseCode': 'W02', 'quantity': 20},
        ],
      });
      expect(daLista.giacenze, {'W01': 30, 'W02': 20});
      final daMappa = materialItemFromJson({
        'materialCode': 'X',
        'description': 'x',
        'stockPerMagazzino': {'W01': 30, 'W03': 5}
      });
      expect(daMappa.giacenze, {'W01': 30, 'W03': 5});
    });

    test('mapper: come manda oggi il backend (stock unico)', () {
      final m = materialItemFromJson({
        'materialCode': 'M001',
        'description': 'Contatore',
        'unitOfMeasure': 'PZ',
        'defaultWarehouseCode': 'W01',
        'stockDisponibile': 25,
      });
      expect(m.giacenze, {'W01': 25});
    });
  });

  group('giacenze per magazzino dal file di anagrafiche.json', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    test('il backend ha la precedenza: stockPerMagazzino non si tocca', () {
      final r = GiacenzeMagazziniService.completa(
          [_x, _z], {'X': {'W03': 99}, 'Z': {'W01': 5, 'W02': 12, 'W03': 3}});
      expect(r[0].giacenze, {'W01': 30, 'W02': 20}); // del backend
      expect(r[1].giacenze, {'W01': 5, 'W02': 12, 'W03': 3}); // completato
    });

    test('senza il file: resta lo stock unico del backend', () {
      expect(GiacenzeMagazziniService.completa([_z], const {})[0].giacenze,
          {'W02': 12});
    });

    test('il file generato copre i 15 materiali, ognuno in più magazzini',
        () async {
      final file = await GiacenzeMagazziniService().carica();
      expect(file.length, 15);
      for (final e in file.entries) {
        expect(e.value.length, greaterThanOrEqualTo(3), reason: e.key);
        expect(e.value.values.every((q) => q >= 1), isTrue, reason: e.key);
      }
    });

    // Il backend è un altro repository: se non è accanto all'app il confronto
    // non si può fare (e non è un errore dell'app).
    final anagrafiche = File('Backend-WFM-VIVA/data/anagrafiche.json');
    test("nel magazzino predefinito c'è lo stock vero del backend", () async {
      final file = await GiacenzeMagazziniService().carica();
      final anag = jsonDecode(anagrafiche.readAsStringSync()) as Map;
      for (final m in (anag['materials'] as List).cast<Map>()) {
        expect(file[m['materialCode']]![m['defaultWarehouseCode']],
            m['stockDisponibile'],
            reason: '${m['materialCode']}');
      }
    }, skip: !anagrafiche.existsSync()
        ? "Backend-WFM-VIVA non presente accanto all'app"
        : false);
  });

  group('registro dei prelievi per magazzino', () {
    test('esempio della specifica: 2 da Magazzino 1, poi 1 da Magazzino 2',
        () async {
      num m1() => StockImpegnatoStore.residuo(30, 'X', 'W01');
      num m2() => StockImpegnatoStore.residuo(20, 'X', 'W02');
      expect((m1(), m2()), (30, 20));

      await StockImpegnatoStore.impegna('X', 'W01', 2);
      expect((m1(), m2()), (28, 20)); // solo il Magazzino 1

      await StockImpegnatoStore.impegna('X', 'W02', 1);
      expect((m1(), m2()), (28, 19)); // solo il Magazzino 2
    });

    test('un materiale non scala quello di un altro', () async {
      await StockImpegnatoStore.impegna('X', 'W01', 5);
      expect(StockImpegnatoStore.residuo(30, 'Y', 'W01'), 30);
    });

    test('rilascia restituisce al magazzino, mai sotto zero né oltre', () async {
      await StockImpegnatoStore.impegna('X', 'W01', 5);
      await StockImpegnatoStore.rilascia('X', 'W01', 2);
      expect(StockImpegnatoStore.residuo(30, 'X', 'W01'), 27);
      await StockImpegnatoStore.rilascia('X', 'W01', 99);
      expect(StockImpegnatoStore.residuo(30, 'X', 'W01'), 30);
      expect(StockImpegnatoStore.residuo(3, 'X', 'W01'), 3);
    });

    test('residuo mai negativo', () async {
      await StockImpegnatoStore.impegna('X', 'W01', 40);
      expect(StockImpegnatoStore.residuo(30, 'X', 'W01'), 0);
    });
  });

  group('schermata Aggiungi componenti', () {
    late _RepoExt repo;

    GoRouter nuovoRouter() => GoRouter(routes: [
          GoRoute(path: '/', builder: (_, __) => const Text('lista OdL')),
          GoRoute(
              path: '/aggiungi',
              builder: (_, __) => const AddComponenteScreen(code: '5001')),
        ]);

    Future<GoRouter> apri(WidgetTester t,
        {List<MaterialItem> materiali = const [_x, _y],
        _RepoExt? repoEsistente}) async {
      repo = repoEsistente ?? _RepoExt();
      await t.binding.setSurfaceSize(const Size(1000, 2200));
      // Albero nuovo a ogni apertura (altrimenti resta il toast della precedente).
      await t.pumpWidget(const SizedBox.shrink());
      final router = nuovoRouter();
      await t.pumpWidget(ProviderScope(
        overrides: [
          odlExtensionRepositoryProvider.overrideWithValue(repo),
          workOrderDetailProvider('5001').overrideWith((ref) async =>
              const WorkOrder(externalCode: '5001', woType: 'ZA02')),
          materialSearchProvider('').overrideWith((ref) async => materiali),
          warehousesProvider.overrideWith((ref) async => _magazzini),
        ],
        child: MaterialApp.router(routerConfig: router),
      ));
      await t.pumpAndSettle();
      router.push('/aggiungi'); // sopra la lista: la schermata si può chiudere
      await t.pumpAndSettle();
      return router;
    }

    Future<void> spunta(WidgetTester t, String descrizione) async {
      await t.tap(find.descendant(
          of: find.ancestor(
              of: find.text(descrizione), matching: find.byType(InkWell)).first,
          matching: find.byType(Checkbox)));
      await t.pumpAndSettle();
    }

    testWidgets(
        'con i dati del backend (stock unico) un materiale è in più magazzini',
        (t) async {
      // Il file si legge dal disco (I/O vero): si carica fuori dal tempo
      // simulato dei test e lo si passa al provider. Il contenuto è quello
      // vero di assets/anagrafica/giacenze_magazzini.json.
      final file = (await t.runAsync(() => GiacenzeMagazziniService().carica()))!;
      repo = _RepoExt();
      await t.binding.setSurfaceSize(const Size(1000, 2200));
      final router = nuovoRouter();
      await t.pumpWidget(ProviderScope(
        overrides: [
          odlExtensionRepositoryProvider.overrideWithValue(repo),
          anagraficaRepositoryProvider.overrideWithValue(_AnagraficaBackend()),
          giacenzeMagazziniProvider.overrideWith((ref) async => file),
          workOrderDetailProvider('5001').overrideWith((ref) async =>
              const WorkOrder(externalCode: '5001', woType: 'ZA02')),
          warehousesProvider.overrideWith((ref) async => const [
                Warehouse(code: 'W01', name: 'Magazzino Centrale Ancona'),
                Warehouse(code: 'W02', name: 'Deposito Senigallia'),
                Warehouse(code: 'W03', name: 'Punto di raccolta Jesi'),
              ]),
        ],
        child: MaterialApp.router(routerConfig: router),
      ));
      await t.pumpAndSettle();
      router.push('/aggiungi');
      await t.pumpAndSettle();

      await spunta(t, 'Contatore acqua DN15 Maddalena');
      // 25 è il vero stock del backend nel magazzino predefinito (scelto di
      // default, 1 pezzo -> 24); gli altri vengono dal file di anagrafiche.json.
      expect(find.text('Magazzino Centrale Ancona (pezzi rimanenti: 24)'),
          findsOneWidget);
      expect(find.text('Deposito Senigallia (pezzi rimanenti: 18)'),
          findsOneWidget);
      expect(find.text('Punto di raccolta Jesi (pezzi rimanenti: 10)'),
          findsOneWidget);

      // Si preleva da Senigallia: scala solo Senigallia, Ancona torna a 25.
      await t.tap(find.text('Deposito Senigallia (pezzi rimanenti: 18)'));
      await t.pump();
      expect(find.text('Magazzino Centrale Ancona (pezzi rimanenti: 25)'),
          findsOneWidget);
      expect(find.text('Deposito Senigallia (pezzi rimanenti: 17)'),
          findsOneWidget);
      await t.tap(find.textContaining('Aggiungi 1 all'));
      await t.pumpAndSettle();
      expect(StockImpegnatoStore.residuo(25, 'M001', 'W01'), 25);
      expect(StockImpegnatoStore.residuo(18, 'M001', 'W02'), 17);
      expect(StockImpegnatoStore.residuo(10, 'M001', 'W03'), 10);
      expect(repo.salvati.last.materiali.single.warehouseCode, 'W02');
    });

    testWidgets('elenco a tendina con caselle da spuntare', (t) async {
      await apri(t);
      expect(find.text('Materiali disponibili'), findsOneWidget);
      expect(find.byType(ExpansionTile), findsOneWidget);
      expect(find.byType(Checkbox), findsNWidgets(2));
      // Si può chiudere e riaprire.
      await t.tap(find.text('Materiali disponibili'));
      await t.pumpAndSettle();
      expect(find.byType(Checkbox), findsNothing);
    });

    testWidgets('materiale spuntato: i suoi magazzini con la quantità rimanente',
        (t) async {
      await apri(t);
      await spunta(t, 'MATERIALE X');
      // Il magazzino scelto (il primo) mostra quanto resterà con 1 pezzo.
      expect(find.text('Magazzino 1 (pezzi rimanenti: 29)'), findsOneWidget);
      expect(find.text('Magazzino 2 (pezzi rimanenti: 20)'), findsOneWidget);
    });

    testWidgets('due materiali: ognuno con i propri magazzini', (t) async {
      await apri(t);
      await spunta(t, 'MATERIALE X');
      await spunta(t, 'MATERIALE Y');
      expect(find.textContaining('(pezzi rimanenti: 29)'), findsNWidgets(2));
      expect(find.textContaining('(pezzi rimanenti: 20)'), findsNWidgets(2));
    });

    testWidgets(
        'senza stockPerMagazzino: solo il magazzino in cui c\'è (dati di anagrafiche.json)',
        (t) async {
      await apri(t, materiali: const [_z]);
      await spunta(t, 'MATERIALE Z');
      expect(find.text('Magazzino 2 (pezzi rimanenti: 11)'), findsOneWidget);
      expect(find.textContaining('Magazzino 1'), findsNothing);
    });

    testWidgets('la quantità tra parentesi scende insieme alla quantità scelta',
        (t) async {
      await apri(t);
      await spunta(t, 'MATERIALE X');
      expect(find.text('Magazzino 1 (pezzi rimanenti: 29)'), findsOneWidget);
      await t.tap(find.byIcon(Icons.add_rounded)); // 2
      await t.pump();
      expect(find.text('Magazzino 1 (pezzi rimanenti: 28)'), findsOneWidget);
      await t.tap(find.byIcon(Icons.add_rounded)); // 3
      await t.pump();
      expect(find.text('Magazzino 1 (pezzi rimanenti: 27)'), findsOneWidget);
      // L'altro magazzino non cambia.
      expect(find.text('Magazzino 2 (pezzi rimanenti: 20)'), findsOneWidget);
      await t.tap(find.byIcon(Icons.remove_rounded)); // 2
      await t.pump();
      expect(find.text('Magazzino 1 (pezzi rimanenti: 28)'), findsOneWidget);
    });

    testWidgets("anche il totale dell'elenco scende con la quantità nel carrello",
        (t) async {
      await apri(t);
      expect(find.text('50 PZ'), findsNWidgets(2)); // X e Y: 30 + 20
      await spunta(t, 'MATERIALE X');
      expect(find.text('49 PZ'), findsOneWidget); // X scende, Y no
      expect(find.text('50 PZ'), findsOneWidget);
      await t.tap(find.byIcon(Icons.add_rounded));
      await t.pump();
      expect(find.text('48 PZ'), findsOneWidget);
    });

    testWidgets('2 pezzi da Magazzino 1: si scala solo quello (30 → 28)',
        (t) async {
      await apri(t);
      await spunta(t, 'MATERIALE X');
      await t.tap(find.byIcon(Icons.add_rounded)); // quantità 2
      await t.pump();
      expect(find.text('Magazzino 1 (pezzi rimanenti: 28)'), findsOneWidget);

      await t.tap(find.textContaining('Aggiungi 1 all'));
      await t.pumpAndSettle();

      expect(StockImpegnatoStore.residuo(30, 'X', 'W01'), 28);
      expect(StockImpegnatoStore.residuo(20, 'X', 'W02'), 20);
      final salvato = repo.salvati.last.materiali.single;
      expect(salvato.warehouseCode, 'W01');
      expect(salvato.usedQuantity, 2);
    });

    testWidgets('1 pezzo da Magazzino 2 dopo: 28 e 19, ognuno separato',
        (t) async {
      await StockImpegnatoStore.impegna('X', 'W01', 2); // già prelevati 2 da M1
      await apri(t);
      await spunta(t, 'MATERIALE X');
      expect(find.text('Magazzino 1 (pezzi rimanenti: 27)'), findsOneWidget);

      await t.tap(find.text('Magazzino 2 (pezzi rimanenti: 20)'));
      await t.pump();
      expect(find.text('Magazzino 1 (pezzi rimanenti: 28)'), findsOneWidget);
      expect(find.text('Magazzino 2 (pezzi rimanenti: 19)'), findsOneWidget);
      await t.tap(find.textContaining('Aggiungi 1 all'));
      await t.pumpAndSettle();

      expect(StockImpegnatoStore.residuo(30, 'X', 'W01'), 28);
      expect(StockImpegnatoStore.residuo(20, 'X', 'W02'), 19);
      expect(repo.salvati.last.materiali.single.warehouseCode, 'W02');
    });

    testWidgets('più del residuo del magazzino scelto: non si può prelevare',
        (t) async {
      await StockImpegnatoStore.impegna('X', 'W02', 19);
      await apri(t);
      await spunta(t, 'MATERIALE X');
      await t.tap(find.text('Magazzino 2 (pezzi rimanenti: 1)'));
      await t.pump();
      expect(find.text('Magazzino 2 (pezzi rimanenti: 0)'), findsOneWidget);
      await t.tap(find.byIcon(Icons.add_rounded)); // 2 > 1
      await t.pump();
      expect(find.text('Stock insufficiente in questo magazzino'),
          findsOneWidget);
      await t.tap(find.textContaining('Aggiungi 1 all'));
      await t.pumpAndSettle();
      expect(find.text('Stock insufficiente'), findsOneWidget); // finestra
      expect(repo.salvati, isEmpty);
      expect(StockImpegnatoStore.residuo(20, 'X', 'W02'), 1);
    });

    testWidgets('un magazzino esaurito non si può scegliere', (t) async {
      await StockImpegnatoStore.impegna('X', 'W01', 30);
      await apri(t);
      await spunta(t, 'MATERIALE X');
      // Proposto di default il primo che ne ha ancora (Magazzino 2: 20 - 1).
      expect(find.text('Magazzino 1 (pezzi rimanenti: 0)'), findsOneWidget);
      expect(find.text('Magazzino 2 (pezzi rimanenti: 19)'), findsOneWidget);
    });

    testWidgets(
        'lo stesso materiale aggiunto di nuovo: una sola riga, quantità sommata',
        (t) async {
      final condiviso = _RepoExt();
      // Prima aggiunta: 2 pezzi di X dal Magazzino 1.
      await apri(t, repoEsistente: condiviso);
      await spunta(t, 'MATERIALE X');
      await t.tap(find.byIcon(Icons.add_rounded));
      await t.pump();
      await t.tap(find.textContaining('Aggiungi 1 all'));
      await t.pumpAndSettle();
      expect(condiviso.salvati.last.materiali.single.usedQuantity, 2);

      // Seconda aggiunta: altri 3 pezzi di X dallo stesso magazzino.
      await apri(t, repoEsistente: condiviso);
      await spunta(t, 'MATERIALE X');
      await t.tap(find.byIcon(Icons.add_rounded));
      await t.tap(find.byIcon(Icons.add_rounded));
      await t.pump();
      await t.tap(find.textContaining('Aggiungi 1 all'));
      await t.pumpAndSettle();

      final righe = condiviso.salvati.last.materiali;
      expect(righe, hasLength(1)); // niente seconda riga per lo stesso materiale
      expect(righe.single.usedQuantity, 5);
      expect(righe.single.plannedQuantity, 5);
      expect(righe.single.warehouseCode, 'W01');
      expect(StockImpegnatoStore.residuo(30, 'X', 'W01'), 25);
    });

    testWidgets('lo stesso materiale da un altro magazzino: righe separate',
        (t) async {
      final condiviso = _RepoExt();
      await apri(t, repoEsistente: condiviso);
      await spunta(t, 'MATERIALE X');
      await t.tap(find.textContaining('Aggiungi 1 all'));
      await t.pumpAndSettle();

      await apri(t, repoEsistente: condiviso);
      await spunta(t, 'MATERIALE X');
      await t.tap(find.textContaining('Magazzino 2 (pezzi rimanenti'));
      await t.pump();
      await t.tap(find.textContaining('Aggiungi 1 all'));
      await t.pumpAndSettle();

      final righe = condiviso.salvati.last.materiali;
      expect(righe.map((m) => m.warehouseCode).toSet(), {'W01', 'W02'});
    });
  });

  group("togliere un materiale dall'OdL", () {
    test('la quantità torna nel magazzino da cui era stata prelevata', () async {
      final repo = _RepoExt();
      final c = ProviderContainer(overrides: [
        odlExtensionRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(c.dispose);
      final n = c.read(odlExtensionProvider('5001').notifier);
      await Future<void>.delayed(Duration.zero);

      await n.addMateriali(const [
        MaterialUsage(
            materialCode: 'X',
            plannedQuantity: 4,
            usedQuantity: 4,
            warehouseCode: 'W01'),
        MaterialUsage(
            materialCode: 'X',
            plannedQuantity: 3,
            usedQuantity: 3,
            warehouseCode: 'W02'),
      ]);
      await StockImpegnatoStore.impegna('X', 'W01', 4);
      await StockImpegnatoStore.impegna('X', 'W02', 3);

      await n.removeRiga('X', 'W01');
      expect(
          c.read(odlExtensionProvider('5001')).materiali.single.warehouseCode,
          'W02'); // l'altra riga resta
      expect(StockImpegnatoStore.residuo(30, 'X', 'W01'), 30); // restituito
      expect(StockImpegnatoStore.residuo(20, 'X', 'W02'), 17); // invariato
    });
  });
}
