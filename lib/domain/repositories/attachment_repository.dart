import '../../core/network/result.dart';
import '../entities/attachment.dart';

abstract interface class AttachmentRepository {
  Future<Result<List<Attachment>>> getAttachments(String workOrderCode);

  Future<Result<Attachment>> addAttachment(Attachment attachment);

  Future<Result<void>> deleteAttachment(String attachmentId);
}
