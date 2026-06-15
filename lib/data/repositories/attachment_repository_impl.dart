import '../../core/error/failures.dart';
import '../../core/network/connectivity_service.dart';
import '../../core/network/result.dart';
import '../../domain/entities/entities.dart';
import '../../domain/repositories/attachment_repository.dart';
import '../datasources/local/local_data_source.dart';
import '../datasources/remote/remote_data_source.dart';

class AttachmentRepositoryImpl implements AttachmentRepository {
  final WfmRemoteDataSource remote;
  final WfmLocalDataSource local;
  final ConnectivityService connectivity;

  AttachmentRepositoryImpl(this.remote, this.local, this.connectivity);

  @override
  Future<Result<List<Attachment>>> getAttachments(String workOrderCode) async {
    // Unione cache locale + (se online) eventuali allegati remoti.
    final localList = local.attachments(workOrderCode);
    if (!connectivity.isOnline) return Success(localList);
    try {
      final remoteList = await remote.getAttachments(workOrderCode);
      final ids = localList.map((e) => e.id).toSet();
      return Success([...localList, ...remoteList.where((e) => !ids.contains(e.id))]);
    } catch (_) {
      return Success(localList);
    }
  }

  @override
  Future<Result<Attachment>> addAttachment(Attachment attachment) async {
    await local.addAttachment(attachment);
    if (!connectivity.isOnline) return Success(attachment);
    try {
      final uploaded = await remote.uploadAttachment(attachment);
      await local.removeAttachment(attachment.id);
      await local.addAttachment(uploaded);
      return Success(uploaded);
    } catch (e) {
      // Resta locale, sarà caricato dalla coda di sync.
      return Success(attachment);
    }
  }

  @override
  Future<Result<void>> deleteAttachment(String attachmentId) async {
    try {
      await local.removeAttachment(attachmentId);
      return const Success(null);
    } catch (e) {
      return Err(CacheFailure(e.toString()));
    }
  }
}
