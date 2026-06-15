import '../../core/network/result.dart';
import '../entities/notification_avviso.dart';
import '../entities/work_order.dart';

abstract interface class NotificationRepository {
  Future<Result<List<NotificationAvviso>>> getAvvisi({String? query});

  Future<Result<NotificationAvviso>> getAvvisoDetail(String numeroAvviso);

  /// Creazione di un nuovo avviso.
  Future<Result<NotificationAvviso>> createAvviso(NotificationAvviso avviso);

  /// Generazione di un OdL a partire da un avviso (EF-M9.3).
  Future<Result<WorkOrder>> generateWorkOrder(String numeroAvviso);
}
