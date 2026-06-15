import '../../core/error/failures.dart';
import '../../core/network/result.dart';
import '../../domain/entities/entities.dart';
import '../../domain/repositories/notification_repository.dart';
import '../datasources/remote/remote_data_source.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  final WfmRemoteDataSource remote;
  NotificationRepositoryImpl(this.remote);

  @override
  Future<Result<List<NotificationAvviso>>> getAvvisi({String? query}) async {
    try {
      return Success(await remote.getAvvisi(query: query));
    } catch (e) {
      return const Err(NetworkFailure());
    }
  }

  @override
  Future<Result<NotificationAvviso>> getAvvisoDetail(String numeroAvviso) async {
    try {
      return Success(await remote.getAvvisoDetail(numeroAvviso));
    } catch (e) {
      return Err(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<NotificationAvviso>> createAvviso(
      NotificationAvviso avviso) async {
    try {
      return Success(await remote.createAvviso(avviso));
    } catch (e) {
      return Err(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<WorkOrder>> generateWorkOrder(String numeroAvviso) async {
    try {
      return Success(await remote.generateWorkOrderFromAvviso(numeroAvviso));
    } catch (e) {
      return Err(ServerFailure(e.toString()));
    }
  }
}
