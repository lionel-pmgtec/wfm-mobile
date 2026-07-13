// Test unitari del repository OdL con un datasource fake (test double) + cache
// locale. Nessun dato mock nel codice dell'app: il fake vive solo nel test.

import 'package:flutter_test/flutter_test.dart';
import 'package:wfm_mobile/core/network/connectivity_service.dart';
import 'package:wfm_mobile/core/network/result.dart';
import 'package:wfm_mobile/data/datasources/local/local_data_source.dart';
import 'package:wfm_mobile/data/datasources/remote/remote_data_source.dart';
import 'package:wfm_mobile/data/repositories/work_order_repository_impl.dart';
import 'package:wfm_mobile/domain/entities/entities.dart';
import 'package:wfm_mobile/domain/repositories/work_order_repository.dart';

/// Datasource fake che serve un piccolo set di OdL in memoria e replica il
/// filtraggio lato server (stato + ricerca testuale).
class _FakeRemoteDataSource implements WfmRemoteDataSource {
  final List<WorkOrder> _orders = const [
    WorkOrder(
      externalCode: '50557262',
      woType: 'DISA',
      woTypeDescription: 'Misuratori - Chiusura (sigillo)',
      status: WorkOrderStatus.ricevuto,
      address: Address(street: 'VIA TEST', streetNumber: '10', city: 'ANCONA'),
    ),
    WorkOrder(
      externalCode: '50557263',
      woType: 'ATTI',
      woTypeDescription: 'Attivazione fornitura',
      status: WorkOrderStatus.inEsecuzione,
      address: Address(street: 'VIA ROMA', streetNumber: '5', city: 'JESI'),
    ),
    WorkOrder(
      externalCode: '50557264',
      woType: 'SOST',
      woTypeDescription: 'Sostituzione contatore',
      status: WorkOrderStatus.ricevuto,
      address: Address(street: 'CORSO ITALIA', streetNumber: '1', city: 'ANCONA'),
    ),
  ];

  @override
  Future<List<WorkOrder>> getWorkOrders(WorkOrderFilter filter) async {
    Iterable<WorkOrder> r = _orders;
    if (filter.status != null) {
      r = r.where((o) => o.status == filter.status);
    }
    if (filter.query != null && filter.query!.isNotEmpty) {
      final q = filter.query!.toLowerCase();
      r = r.where((o) =>
          o.externalCode.toLowerCase().contains(q) ||
          o.woTypeDescription.toLowerCase().contains(q) ||
          o.address.city.toLowerCase().contains(q));
    }
    return r.toList();
  }

  @override
  Future<WorkOrder> getWorkOrderDetail(String externalCode) async =>
      _orders.firstWhere((o) => o.externalCode == externalCode);

  @override
  Future<WorkOrder> updateStatus(String code, WorkOrderStatus status,
          {String? reason, String? note, Geolocation? geolocation}) async =>
      _orders.firstWhere((o) => o.externalCode == code).copyWith(status: status);

  // Gli altri metodi dell'interfaccia non sono usati da questi test.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late WorkOrderRepositoryImpl repo;
  late ConnectivityService connectivity;

  setUp(() {
    connectivity = ConnectivityService();
    repo = WorkOrderRepositoryImpl(
      _FakeRemoteDataSource(),
      InMemoryLocalDataSource(),
      connectivity,
    );
  });

  test('carica la lista degli OdL', () async {
    final res = await repo.getWorkOrders();
    expect(res, isA<Success>());
    expect(res.valueOrNull, isNotEmpty);
  });

  test('filtra per stato Ricevuto', () async {
    final res = await repo.getWorkOrders(
        filter: const WorkOrderFilter(status: WorkOrderStatus.ricevuto));
    final list = res.valueOrNull!;
    expect(list, isNotEmpty);
    expect(list.every((o) => o.status == WorkOrderStatus.ricevuto), isTrue);
  });

  test('ricerca testuale per indirizzo', () async {
    final res =
        await repo.getWorkOrders(filter: const WorkOrderFilter(query: 'ANCONA'));
    expect(res.valueOrNull!.isNotEmpty, isTrue);
  });

  test('aggiorna lo stato di un OdL', () async {
    final list = (await repo.getWorkOrders()).valueOrNull!;
    final code = list.first.externalCode;
    final res = await repo.updateStatus(code, WorkOrderStatus.inEsecuzione);
    expect(res.valueOrNull!.status, WorkOrderStatus.inEsecuzione);
  });

  test('calcola le statistiche dashboard', () async {
    final res = await repo.getStats();
    final stats = res.valueOrNull!;
    expect(stats.keys.length, WorkOrderStatus.values.length);
  });

  test('offline: usa la cache locale', () async {
    await repo.getWorkOrders(); // popola la cache
    connectivity.setOnline(false);
    final res = await repo.getWorkOrders();
    expect(res, isA<Success>());
    expect(res.valueOrNull, isNotEmpty);
  });
}
