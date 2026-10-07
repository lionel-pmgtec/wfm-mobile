// La lista reale degli OdL: un OdL nuovo, che il backend dà IN FONDO, sale in cima.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wfm_mobile/core/network/result.dart';
import 'package:wfm_mobile/core/services/arrival_store.dart';
import 'package:wfm_mobile/domain/entities/entities.dart';
import 'package:wfm_mobile/domain/repositories/work_order_repository.dart';
import 'package:wfm_mobile/presentation/providers/connectivity_provider.dart';
import 'package:wfm_mobile/presentation/providers/core_providers.dart';
import 'package:wfm_mobile/presentation/providers/creation_provider.dart';
import 'package:wfm_mobile/presentation/providers/work_orders_provider.dart';

class _FakeRepo implements WorkOrderRepository {
  List<WorkOrder> risposta = [];

  @override
  Future<Result<List<WorkOrder>>> getWorkOrders(
          {WorkOrderFilter filter = const WorkOrderFilter()}) async =>
      Success(risposta);

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('${i.memberName}');
}

class _Online extends StateNotifier<bool> implements ConnectivityNotifier {
  _Online() : super(true);
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

WorkOrder _o(String code) => WorkOrder(externalCode: code, woType: 'SOST');

void main() {
  setUp(ArrivalStore.resetForTests);

  test('un OdL nuovo dato in fondo dal backend compare in cima', () async {
    final repo = _FakeRepo()..risposta = [_o('A'), _o('B'), _o('C')];
    final c = ProviderContainer(overrides: [
      workOrderRepositoryProvider.overrideWithValue(repo),
      connectivityStatusProvider.overrideWith((ref) => _Online()),
      createdWorkOrdersProvider.overrideWith((ref) async => <WorkOrder>[]),
    ]);
    addTearDown(c.dispose);

    // Primo caricamento: riferimento, ordine del backend.
    var l = await c.read(workOrdersProvider.future);
    expect(l.map((o) => o.externalCode), ['A', 'B', 'C']);

    // Arriva D: il backend lo mette in fondo.
    repo.risposta = [_o('A'), _o('B'), _o('C'), _o('D')];
    c.invalidate(workOrdersProvider);
    l = await c.read(workOrdersProvider.future);
    expect(l.map((o) => o.externalCode), ['D', 'A', 'B', 'C']);

    // Poi arriva E: sta sopra D.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    repo.risposta = [_o('A'), _o('B'), _o('C'), _o('D'), _o('E')];
    c.invalidate(workOrdersProvider);
    l = await c.read(workOrdersProvider.future);
    expect(l.map((o) => o.externalCode), ['E', 'D', 'A', 'B', 'C']);
  });

  test('un OdL creato sulla tablet e poi sincronizzato resta in cima', () async {
    final repo = _FakeRepo()..risposta = [_o('A'), _o('B')];
    final c = ProviderContainer(overrides: [
      workOrderRepositoryProvider.overrideWithValue(repo),
      connectivityStatusProvider.overrideWith((ref) => _Online()),
      createdWorkOrdersProvider.overrideWith((ref) async => <WorkOrder>[]),
    ]);
    addTearDown(c.dispose);
    await c.read(workOrdersProvider.future); // riferimento
    await ArrivalStore.arrivedNow('odl', 'TMP-1'); // creato sul tablet

    // Dopo la sincronizzazione il backend lo restituisce in fondo.
    repo.risposta = [_o('A'), _o('B'), _o('TMP-1')];
    c.invalidate(workOrdersProvider);
    final l = await c.read(workOrdersProvider.future);
    expect(l.first.externalCode, 'TMP-1');
  });

  test('da una lista FILTRATA non si registra nulla (niente falsi "nuovi")', () async {
    final repo = _FakeRepo()..risposta = [_o('A')];
    final c = ProviderContainer(overrides: [
      workOrderRepositoryProvider.overrideWithValue(repo),
      connectivityStatusProvider.overrideWith((ref) => _Online()),
      createdWorkOrdersProvider.overrideWith((ref) async => <WorkOrder>[]),
    ]);
    addTearDown(c.dispose);
    c.read(workOrderFilterProvider.notifier).state =
        const WorkOrderFilter(status: WorkOrderStatus.inEsecuzione);
    await c.read(workOrdersProvider.future);
    // Nessun riferimento è stato stabilito: il primo elenco COMPLETO lo farà.
    repo.risposta = [_o('A'), _o('B')];
    c.read(workOrderFilterProvider.notifier).state = const WorkOrderFilter();
    final l = await c.read(workOrdersProvider.future);
    expect(l.map((o) => o.externalCode), ['A', 'B']);
    expect(ArrivalStore.of('odl', 'B'), isNull); // riferimento, non "nuovo"
  });
}
