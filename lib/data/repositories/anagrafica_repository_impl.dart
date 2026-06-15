import '../../core/error/failures.dart';
import '../../core/network/result.dart';
import '../../domain/entities/entities.dart';
import '../../domain/repositories/anagrafica_repository.dart';
import '../datasources/remote/remote_data_source.dart';

class AnagraficaRepositoryImpl implements AnagraficaRepository {
  final WfmRemoteDataSource remote;
  AnagraficaRepositoryImpl(this.remote);

  Future<Result<T>> _guard<T>(Future<T> Function() fn) async {
    try {
      return Success(await fn());
    } catch (e) {
      return const Err(NetworkFailure());
    }
  }

  @override
  Future<Result<List<MaterialItem>>> getMaterials({String? query}) =>
      _guard(() => remote.getMaterials(query: query));

  @override
  Future<Result<List<Warehouse>>> getWarehouses() =>
      _guard(() => remote.getWarehouses());

  @override
  Future<Result<List<String>>> getMeterBrands() =>
      _guard(() => remote.getMeterBrands());

  @override
  Future<Result<List<String>>> getTamCodes() =>
      _guard(() => remote.getTamCodes());

  @override
  Future<Result<List<CodeLabel>>> getCauseCodes() =>
      _guard(() => remote.getCauseCodes());

  @override
  Future<Result<List<CodeLabel>>> getSolutionCodes() =>
      _guard(() => remote.getSolutionCodes());
}
