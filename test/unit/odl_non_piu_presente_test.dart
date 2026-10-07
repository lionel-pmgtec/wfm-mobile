// OdL che il backend non ha più ("Ordine … non più presente in SAP", 404):
// messaggio chiaro, copia locale scartata, ritorno alla lista rinfrescata.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:wfm_mobile/core/error/failures.dart';
import 'package:wfm_mobile/core/network/connectivity_service.dart';
import 'package:wfm_mobile/data/datasources/local/local_data_source.dart';
import 'package:wfm_mobile/data/datasources/remote/remote_data_source.dart';
import 'package:wfm_mobile/data/repositories/work_order_repository_impl.dart';
import 'package:wfm_mobile/domain/entities/entities.dart';
import 'package:wfm_mobile/domain/repositories/sync_repository.dart';
import 'package:wfm_mobile/presentation/features/work_orders/work_order_detail_screen.dart';
import 'package:wfm_mobile/presentation/providers/creation_provider.dart';
import 'package:wfm_mobile/presentation/providers/work_orders_provider.dart';

const _code = '000060000471';
const _msg = 'Ordine 000060000471 non più presente in SAP.';

DioException _http404(Map<String, dynamic> body) => DioException(
      requestOptions: RequestOptions(path: '/work-orders/$_code'),
      response: Response(
          requestOptions: RequestOptions(path: '/work-orders/$_code'),
          statusCode: 404,
          data: body),
      type: DioExceptionType.badResponse,
    );

class _Remote implements WfmRemoteDataSource {
  Object? errore;
  @override
  Future<WorkOrder> getWorkOrderDetail(String externalCode) async =>
      throw errore!;
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('${i.memberName}');
}

class _Sync implements SyncRepository {
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

void main() {
  setUpAll(() => initializeDateFormatting('it_IT', null));

  group('repository', () {
    late _Remote remote;
    late InMemoryLocalDataSource local;
    late WorkOrderRepositoryImpl repo;

    setUp(() {
      remote = _Remote();
      local = InMemoryLocalDataSource();
      repo = WorkOrderRepositoryImpl(remote, local, ConnectivityService(), _Sync());
    });

    test('404 "non più presente": messaggio del server, copia locale SCARTATA', () async {
      await local.upsertWorkOrder(const WorkOrder(externalCode: _code, woType: 'SOST'));
      remote.errore = _http404({'error': _msg});

      final r = await repo.getWorkOrderDetail(_code);

      final f = r.failureOrNull;
      expect(f, isA<NonTrovatoFailure>());
      expect(f!.message, _msg); // il testo vero, non "DioException [bad response]…"
      expect(local.cachedWorkOrder(_code), isNull); // niente OdL fantasma in cache
    });

    test('404 revocato: comportamento invariato', () async {
      remote.errore = _http404({'error': 'Revocato dal pianificatore.', 'revocato': true});
      final r = await repo.getWorkOrderDetail(_code);
      expect(r.failureOrNull, isA<RevocatoFailure>());
    });

    test('altro errore del server (500): mai il testo tecnico di Dio', () async {
      remote.errore = DioException(
        requestOptions: RequestOptions(path: '/x'),
        response: Response(
            requestOptions: RequestOptions(path: '/x'),
            statusCode: 500,
            data: {'error': 'Servizio momentaneamente non disponibile.'}),
        type: DioExceptionType.badResponse,
      );
      final r = await repo.getWorkOrderDetail(_code);
      expect(r.failureOrNull!.message, 'Servizio momentaneamente non disponibile.');
      expect(r.failureOrNull!.message.contains('DioException'), isFalse);
    });
  });

  group('schermata dettaglio', () {
    testWidgets('OdL non più presente: toast chiaro, torna alla lista, niente errore tecnico',
        (t) async {
      await t.binding.setSurfaceSize(const Size(900, 1400));
      var listaRinfrescata = 0;
      final router = GoRouter(initialLocation: '/work-orders/$_code', routes: [
        GoRoute(
          path: '/work-orders',
          builder: (_, __) => const Scaffold(body: Text('LISTA ORDINI')),
        ),
        GoRoute(
          path: '/work-orders/:id',
          builder: (_, s) => WorkOrderDetailScreen(code: s.pathParameters['id']!),
        ),
      ]);
      await t.pumpWidget(ProviderScope(
        overrides: [
          createdWorkOrdersProvider.overrideWith((ref) async => <WorkOrder>[]),
          workOrderDetailProvider(_code)
              .overrideWith((ref) async => throw const NonTrovatoFailure(_msg)),
          workOrdersProvider.overrideWith((ref) async {
            listaRinfrescata++;
            return <WorkOrder>[];
          }),
          dashboardStatsProvider.overrideWith((ref) async => {}),
        ],
        child: MaterialApp.router(routerConfig: router),
      ));
      // Tiene viva la lista, come farebbe la schermata Ordini.
      final container = ProviderScope.containerOf(t.element(find.byType(MaterialApp)));
      container.listen(workOrdersProvider, (_, __) {});
      await t.pumpAndSettle();

      expect(find.text('LISTA ORDINI'), findsOneWidget); // tornato alla lista
      expect(find.text(_msg), findsOneWidget); // messaggio chiaro
      expect(find.textContaining('DioException'), findsNothing);
      expect(listaRinfrescata, greaterThan(0)); // lista ricaricata
    });
  });
}
