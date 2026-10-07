// Scheda Materiali dell'OdL: si può eliminare un materiale preso sul tablet, e
// la quantità torna nel magazzino da cui era stata prelevata. I materiali
// pianificati da SAP non si possono eliminare.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:wfm_mobile/core/services/stock_impegnato_store.dart';
import 'package:wfm_mobile/domain/entities/entities.dart';
import 'package:wfm_mobile/domain/repositories/odl_extension_repository.dart';
import 'package:wfm_mobile/presentation/features/work_orders/work_order_detail_screen.dart';
import 'package:wfm_mobile/presentation/providers/core_providers.dart';
import 'package:wfm_mobile/presentation/providers/work_orders_provider.dart';

class _RepoExt implements OdlExtensionRepository {
  OdlExtension ext;
  _RepoExt(this.ext);
  @override
  Future<OdlExtension> get(String c) async => ext;
  @override
  Future<void> save(OdlExtension e) async => ext = e;
  @override
  Future<void> clear(String c) async {}
}

void main() {
  setUpAll(() => initializeDateFormatting('it_IT', null));
  setUp(StockImpegnatoStore.resetForTests);

  const preso = MaterialUsage(
      materialCode: 'M009',
      description: 'Valvola a sfera DN20',
      plannedQuantity: 7,
      usedQuantity: 7,
      warehouseCode: 'W02');

  Future<_RepoExt> apri(WidgetTester t, WorkOrder ordine) async {
    final repo = _RepoExt(OdlExtension.empty('X1').copyWith(materiali: [preso]));
    await t.binding.setSurfaceSize(const Size(1000, 3000));
    await t.pumpWidget(ProviderScope(
      overrides: [
        odlExtensionRepositoryProvider.overrideWithValue(repo),
        workOrderDetailProvider('X1').overrideWith((ref) async => ordine),
      ],
      child: const MaterialApp(home: WorkOrderDetailScreen(code: 'X1')),
    ));
    await t.pumpAndSettle();
    await t.tap(find.textContaining('Materiali ('));
    await t.pumpAndSettle();
    return repo;
  }

  testWidgets("elimina un materiale preso sul tablet: torna nel suo magazzino",
      (t) async {
    await StockImpegnatoStore.impegna('M009', 'W02', 7);
    expect(StockImpegnatoStore.residuo(10, 'M009', 'W02'), 3);
    final repo =
        await apri(t, const WorkOrder(externalCode: 'X1', woType: 'ZA02'));

    expect(find.text('Valvola a sfera DN20'), findsOneWidget);
    await t.tap(find.byTooltip('Elimina materiale'));
    await t.pumpAndSettle();
    expect(find.text('Eliminare il materiale?'), findsOneWidget);
    await t.tap(find.text('Elimina'));
    await t.pumpAndSettle();

    expect(find.text('Valvola a sfera DN20'), findsNothing);
    expect(repo.ext.materiali, isEmpty);
    expect(StockImpegnatoStore.residuo(10, 'M009', 'W02'), 10); // restituiti
  });

  testWidgets('annullando, il materiale resta', (t) async {
    await StockImpegnatoStore.impegna('M009', 'W02', 7);
    final repo =
        await apri(t, const WorkOrder(externalCode: 'X1', woType: 'ZA02'));
    await t.tap(find.byTooltip('Elimina materiale'));
    await t.pumpAndSettle();
    await t.tap(find.text('Annulla'));
    await t.pumpAndSettle();
    expect(repo.ext.materiali, hasLength(1));
    expect(StockImpegnatoStore.residuo(10, 'M009', 'W02'), 3);
  });

  testWidgets('un materiale pianificato da SAP non si elimina', (t) async {
    await apri(
        t,
        const WorkOrder(externalCode: 'X1', woType: 'ZA02', plannedMaterials: [
          MaterialUsage(
              materialCode: 'SAP1',
              description: 'Tubo SAP',
              plannedQuantity: 2,
              warehouseCode: 'W01'),
        ]));
    expect(find.text('Tubo SAP'), findsOneWidget);
    // Un solo cestino: quello del materiale preso sul tablet.
    expect(find.byTooltip('Elimina materiale'), findsOneWidget);
  });

  testWidgets('OdL chiuso: niente eliminazione', (t) async {
    await apri(
        t,
        const WorkOrder(
            externalCode: 'X1',
            woType: 'ZA02',
            status: WorkOrderStatus.completato));
    expect(find.text('Valvola a sfera DN20'), findsOneWidget);
    expect(find.byTooltip('Elimina materiale'), findsNothing);
  });
}
