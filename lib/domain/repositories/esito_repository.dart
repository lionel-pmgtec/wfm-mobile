import '../../core/network/result.dart';
import '../entities/esito.dart';

abstract interface class EsitoRepository {
  /// Bozza locale dell'esito per un OdL (se esiste).
  Future<Esito?> getDraft(String workOrderCode);

  /// Salvataggio locale della bozza (offline-first).
  Future<void> saveDraft(Esito esito);

  /// Invio definitivo dell'esito (EF-M5.4). In offline viene accodato.
  Future<Result<String>> submitEsito(Esito esito);
}
