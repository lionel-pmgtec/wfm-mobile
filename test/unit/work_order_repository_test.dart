// Test unitari del repository OdL con datasource mock + cache locale.

import 'package:flutter_test/flutter_test.dart';
import 'package:wfm_mobile/core/network/connectivity_service.dart';
import 'package:wfm_mobile/core/network/result.dart';
import 'package:wfm_mobile/data/datasources/local/local_data_source.dart';
import 'package:wfm_mobile/data/datasources/remote/mock_remote_data_source.dart';
import 'package:wfm_mobile/data/repositories/work_order_repository_impl.dart';
import 'package:wfm_mobile/domain/entities/enums.dart';
import 'package:wfm_mobile/domain/repositories/work_order_repository.dart';

void main() {
  late WorkOrderRepositoryImpl repo;
  late ConnectivityService connectivity;

  setUp(() {
    connectivity = ConnectivityService();
    repo = WorkOrderRepositoryImpl(
      MockRemoteDataSource(),
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
    final res =
        await repo.updateStatus(code, WorkOrderStatus.inEsecuzione);
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
