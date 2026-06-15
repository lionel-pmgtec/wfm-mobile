import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/result.dart';
import '../../core/services/geolocation_service.dart';
import '../../domain/entities/entities.dart';
import 'core_providers.dart';
import 'work_orders_provider.dart';

/// Controller di salvataggio/invio esito (M5).
class EsitoController {
  final Ref ref;
  EsitoController(this.ref);

  Future<Esito?> draft(String workOrderCode) =>
      ref.read(esitoRepositoryProvider).getDraft(workOrderCode);

  Future<void> saveDraft(Esito esito) =>
      ref.read(esitoRepositoryProvider).saveDraft(esito);

  Future<Result<String>> submit(Esito esito) async {
    final res = await ref.read(esitoRepositoryProvider).submitEsito(esito);
    if (res.isSuccess) {
      // Cattura posizione di chiusura (Stop OdL — timbratura di campo).
      final geo = await GeolocationService.instance.getCurrentPosition();
      // Alla validazione l'OdL passa a COMPLETATO (EF-M5.4).
      await ref.read(workOrderActionsProvider).changeStatus(
            esito.workOrderCode,
            WorkOrderStatus.completato,
            geolocation: geo,
          );
    }
    return res;
  }
}

final esitoControllerProvider =
    Provider<EsitoController>((ref) => EsitoController(ref));
