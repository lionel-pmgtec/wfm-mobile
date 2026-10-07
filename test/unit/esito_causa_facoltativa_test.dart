// Chiusura dell'OdL: "Motivo intervento" e "Soluzione fornita" sono facoltativi.
// Il backend (POST /esiti) richiede solo il codice dell'OdL, e non per ogni tipo
// di OdL (es. ZA02) questi campi hanno senso.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:wfm_mobile/core/error/failures.dart';
import 'package:wfm_mobile/core/network/result.dart';
import 'package:wfm_mobile/domain/entities/entities.dart';
import 'package:wfm_mobile/domain/repositories/esito_repository.dart';
import 'package:wfm_mobile/presentation/features/esito/esito_screen.dart';
import 'package:wfm_mobile/presentation/providers/anagrafica_provider.dart';
import 'package:wfm_mobile/presentation/providers/core_providers.dart';
import 'package:wfm_mobile/presentation/providers/work_orders_provider.dart';
import 'package:wfm_mobile/presentation/providers/esito_provider.dart';
import 'package:wfm_mobile/domain/entities/esito.dart';
import 'package:wfm_mobile/core/widgets/match_code_field.dart';

class _Repo implements EsitoRepository {
  final inviati = <Esito>[];
  @override
  Future<Result<String>> submitEsito(Esito e) async {
    inviati.add(e);
    return const Err(ServerFailure('prova'));
  }

  @override
  Future<Esito?> getDraft(String c) async => null;
  @override
  Future<void> saveDraft(Esito e) async {}
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('$i');
}

void main() {
  setUpAll(() => initializeDateFormatting('it_IT', null));

  testWidgets('senza motivo né soluzione si può inviare l\'esito', (t) async {
    final repo = _Repo();
    await t.binding.setSurfaceSize(const Size(1200, 3000));
    await t.pumpWidget(ProviderScope(
      overrides: [
        esitoRepositoryProvider.overrideWithValue(repo),
        workOrderDetailProvider('5001').overrideWith(
            (ref) async => const WorkOrder(externalCode: '5001', woType: 'ZA02')),
        causeCodesProvider.overrideWith((ref) async => const [CodeLabel('C01', 'Usura')]),
        solutionCodesProvider
            .overrideWith((ref) async => const [CodeLabel('S01', 'Sostituzione')]),
      ],
      child: const MaterialApp(home: Scaffold(body: EsitoScreen(code: '5001'))),
    ));
    await t.pumpAndSettle();

    // Nessun asterisco/obbligo sul motivo.
    expect(find.text('Motivo intervento'), findsOneWidget);
    await t.tap(find.text('Riuscito'));
    await t.pump();
    await t.ensureVisible(find.text('Convalida e invia esito'));
    await t.tap(find.text('Convalida e invia esito'));
    await t.pumpAndSettle();

    // Nessun errore di validazione sul motivo: si arriva alla conferma.
    expect(find.text('Selezionare un motivo'), findsNothing);
    expect(find.text('Convalida esito'), findsOneWidget);
  });
}
