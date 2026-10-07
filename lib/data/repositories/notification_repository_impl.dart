import '../../core/error/failures.dart';
import '../../core/network/result.dart';
import '../../core/services/avvisi_rimossi_store.dart';
import '../../domain/entities/entities.dart';
import '../../domain/repositories/notification_repository.dart';
import '../datasources/remote/remote_data_source.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  final WfmRemoteDataSource remote;
  NotificationRepositoryImpl(this.remote);

  @override
  Future<Result<List<NotificationAvviso>>> getAvvisi({String? query}) async {
    try {
      // Gli avvisi il cui OdL è stato chiuso non tornano sul tablet.
      return Success(AvvisiRimossiStore.filtra(
          await remote.getAvvisi(query: query), (a) => a.numeroAvviso));
    } catch (e) {
      return const Err(NetworkFailure());
    }
  }

  @override
  Future<Result<NotificationAvviso>> getAvvisoDetail(String numeroAvviso) async {
    try {
      return Success(await remote.getAvvisoDetail(numeroAvviso));
    } catch (e) {
      return Err(ServerFailure(_messaggioPulito(e)));
    }
  }

  @override
  Future<Result<NotificationAvviso>> createAvviso(
      NotificationAvviso avviso) async {
    try {
      return Success(await remote.createAvviso(avviso));
    } catch (e) {
      return Err(ServerFailure(_messaggioPulito(e)));
    }
  }

  @override
  Future<Result<WorkOrder>> generateWorkOrder(String numeroAvviso) async {
    try {
      return Success(await remote.generateWorkOrderFromAvviso(numeroAvviso));
    } catch (e) {
      return Err(ServerFailure(_messaggioPulito(e)));
    }
  }

  /// Traduce QUALSIASI eccezione in un messaggio comprensibile: la stringa
  /// tecnica di Dio (DioException, status code…) non deve MAI arrivare
  /// all'utente, nemmeno quando il backend non ha ancora implementato la logica.
  String _messaggioPulito(Object e,
      {String fallback = 'Operazione non riuscita. Riprova più tardi.'}) {
    final s = e.toString();
    if (s.contains('501')) {
      return 'Funzione non ancora disponibile sul cruscotto.';
    }
    if (s.contains('404')) return 'Elemento non trovato sul cruscotto.';
    if (s.contains('SocketException') ||
        s.contains('connection') ||
        s.contains('timeout')) {
      return 'Cruscotto non raggiungibile. Controlla la connessione.';
    }
    return fallback;
  }

  @override
  Future<Result<void>> deleteAvviso(String numeroAvviso) async {
    try {
      await remote.deleteAvviso(numeroAvviso);
      return const Success<void>(null);
    } catch (e) {
      // Mai la stringa tecnica di Dio all'utente. La cancellazione lato
      // cruscotto non è ancora implementata (501): messaggio chiaro.
      final s = e.toString();
      final msg = s.contains('501')
          ? 'La cancellazione degli avvisi non è ancora disponibile sul cruscotto.'
          : 'Eliminazione non riuscita. Riprova più tardi.';
      return Err(ServerFailure(msg));
    }
  }
}
