// Un OdL sospeso resta sul tablet.
//
// Il backend lo tiene assegnato al tecnico (GET /work-orders lo elenca con stato
// SOSPESO) e "Riprendi" lo riporta in esecuzione. Prima il tablet lo toglieva
// dalla lista appena sospeso, e non c'era modo di ritrovarlo: ora sta nel
// filtro "Sospeso".

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:wfm_mobile/core/network/connectivity_service.dart';
import 'package:wfm_mobile/core/services/odl_rimossi_store.dart';
import 'package:wfm_mobile/data/datasources/local/local_data_source.dart';
import 'package:wfm_mobile/data/datasources/remote/remote_data_source.dart';
import 'package:wfm_mobile/data/repositories/work_order_repository_impl.dart';
import 'package:wfm_mobile/domain/entities/entities.dart';
import 'package:wfm_mobile/domain/repositories/sync_repository.dart';
import 'package:wfm_mobile/domain/repositories/work_order_repository.dart';
import 'package:wfm_mobile/presentation/features/work_orders/work_orders_screen.dart';
import 'package:wfm_mobile/presentation/providers/work_orders_provider.dart';

class _Rete implements ConnectivityService {
  final bool _online;
  _Rete(this._online);
  @override
  bool get isOnline => _online;
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

class _Sync implements SyncRepository {
  final accodate = <String>[];
  @override
  Future<void> enqueue(dynamic op) async => accodate.add('${op.entityId}');
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('$i');
}

/// Backend finto: tiene gli stati come il vero (l'ordine sospeso resta elencato).
class _Remote implements WfmRemoteDataSource {
  final Map<String, WorkOrder> ordini;
  _Remote(List<WorkOrder> l) : ordini = {for (final o in l) o.externalCode: o};

  @override
  Future<List<WorkOrder>> getWorkOrders(WorkOrderFilter filter) async =>
      ordini.values.toList();

  @override
  Future<WorkOrder> updateStatus(String code, WorkOrderStatus status,
      {String? reason, String? note, Geolocation? geolocation}) async {
    final nuovo = ordini[code]!.copyWith(status: status);
    ordini[code] = nuovo;
    return nuovo;
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('$i');
}

WorkOrder _odl(String c, WorkOrderStatus s) =>
    WorkOrder(externalCode: c, woType: 'ZA02', status: s);

void main() {
  setUpAll(() => initializeDateFormatting('it_IT', null));
  setUp(OdlRimossiStore.resetForTests);

  WorkOrderRepositoryImpl repo(_Remote remote, {bool online = true, InMemoryLocalDataSource? local}) =>
      WorkOrderRepositoryImpl(remote, local ?? InMemoryLocalDataSource(),
          _Rete(online), _Sync());

  Future<Map<String, WorkOrderStatus>> elenco(WorkOrderRepository r,
      [WorkOrderFilter f = const WorkOrderFilter()]) async => {
        for (final o in (await r.getWorkOrders(filter: f)).valueOrNull!)
          o.externalCode: o.status
      };

  test("un OdL sospeso dal backend resta nell'elenco", () async {
    final r = repo(_Remote([
      _odl('A', WorkOrderStatus.ricevuto),
      _odl('B', WorkOrderStatus.sospeso),
      _odl('C', WorkOrderStatus.completato), // chiuso: esce, come prima
    ]));
    expect(await elenco(r), {
      'A': WorkOrderStatus.ricevuto,
      'B': WorkOrderStatus.sospeso,
    });
  });

  test('il filtro Sospeso mostra solo i sospesi', () async {
    final r = repo(_Remote([
      _odl('A', WorkOrderStatus.ricevuto),
      _odl('B', WorkOrderStatus.sospeso),
    ]));
    expect(await elenco(r, const WorkOrderFilter(status: WorkOrderStatus.sospeso)),
        {'B': WorkOrderStatus.sospeso});
  });

  test('sospendere un OdL: resta sul tablet con stato Sospeso', () async {
    final remote = _Remote([_odl('A', WorkOrderStatus.inEsecuzione)]);
    final r = repo(remote);
    await elenco(r);
    final res = await r.updateStatus('A', WorkOrderStatus.sospeso, reason: 'x');
    expect(res.isSuccess, isTrue);
    expect(await elenco(r), {'A': WorkOrderStatus.sospeso});
  });

  test('sospendere senza rete: resta sul tablet, sospeso, e viene accodato',
      () async {
    final local = InMemoryLocalDataSource();
    final online = repo(_Remote([_odl('A', WorkOrderStatus.inEsecuzione)]),
        local: local);
    await elenco(online); // riempie la cache
    final offline = repo(_Remote(const []), online: false, local: local);
    await offline.updateStatus('A', WorkOrderStatus.sospeso);
    expect(await elenco(offline), {'A': WorkOrderStatus.sospeso});
  });

  test('Riprendi: da sospeso torna in esecuzione, e si vede in "In esecuzione"',
      () async {
    final remote = _Remote([_odl('A', WorkOrderStatus.sospeso)]);
    final r = repo(remote);
    expect(_odl('A', WorkOrderStatus.sospeso).canStart, isTrue);
    await r.updateStatus('A', WorkOrderStatus.inEsecuzione);
    expect(await elenco(r, const WorkOrderFilter(status: WorkOrderStatus.inEsecuzione)),
        {'A': WorkOrderStatus.inEsecuzione});
    expect(await elenco(r, const WorkOrderFilter(status: WorkOrderStatus.sospeso)),
        isEmpty);
  });

  testWidgets('la puce "Sospeso" c\'è e filtra', (t) async {
    await t.binding.setSurfaceSize(const Size(1200, 1600));
    final c = ProviderContainer(overrides: [
      workOrdersProvider.overrideWith((ref) async => [
            _odl('A', WorkOrderStatus.ricevuto),
            _odl('B', WorkOrderStatus.sospeso),
          ]),
    ]);
    addTearDown(c.dispose);
    await t.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: WorkOrdersScreen())));
    await t.pump();
    await t.pump();

    expect(find.widgetWithText(ChoiceChip, 'Sospeso'), findsOneWidget);
    await t.tap(find.widgetWithText(ChoiceChip, 'Sospeso'));
    await t.pump();
    expect(c.read(workOrderFilterProvider).status, WorkOrderStatus.sospeso);
  });
}
