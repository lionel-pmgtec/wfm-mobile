import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/entities.dart';
import 'core_providers.dart';

final attachmentsProvider =
    FutureProvider.family<List<Attachment>, String>((ref, code) async {
  final res = await ref.watch(attachmentRepositoryProvider).getAttachments(code);
  return res.valueOrNull ?? const [];
});

class AttachmentActions {
  final Ref ref;
  AttachmentActions(this.ref);

  Future<void> add(Attachment a) async {
    await ref.read(attachmentRepositoryProvider).addAttachment(a);
    ref.invalidate(attachmentsProvider(a.workOrderCode));
  }

  Future<void> remove(String workOrderCode, String id) async {
    await ref.read(attachmentRepositoryProvider).deleteAttachment(id);
    ref.invalidate(attachmentsProvider(workOrderCode));
  }

  /// Sostituisce un allegato esistente con uno nuovo (stesso workOrderCode).
  Future<void> replace(String workOrderCode, String oldId, Attachment newAttachment) async {
    await ref.read(attachmentRepositoryProvider).deleteAttachment(oldId);
    await ref.read(attachmentRepositoryProvider).addAttachment(newAttachment);
    ref.invalidate(attachmentsProvider(workOrderCode));
  }
}

final attachmentActionsProvider =
    Provider<AttachmentActions>((ref) => AttachmentActions(ref));
