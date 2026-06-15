// Allegato (foto / firma / documento) — specifiche §9.1 + M8.

import 'enums.dart';
import 'value_objects.dart';

class Attachment {
  final String id; // UUID
  final String workOrderCode;
  final AttachmentType type;
  final String filePath; // percorso locale
  final String fileName;
  final String mimeType;
  final int sizeBytes;
  final Geolocation? geolocation;
  final DateTime capturedAt;
  final String author; // CID tecnico
  final UploadStatus uploadStatus;

  const Attachment({
    required this.id,
    required this.workOrderCode,
    required this.type,
    required this.filePath,
    required this.fileName,
    this.mimeType = 'image/jpeg',
    this.sizeBytes = 0,
    this.geolocation,
    required this.capturedAt,
    required this.author,
    this.uploadStatus = UploadStatus.local,
  });

  Attachment copyWith({UploadStatus? uploadStatus}) => Attachment(
        id: id,
        workOrderCode: workOrderCode,
        type: type,
        filePath: filePath,
        fileName: fileName,
        mimeType: mimeType,
        sizeBytes: sizeBytes,
        geolocation: geolocation,
        capturedAt: capturedAt,
        author: author,
        uploadStatus: uploadStatus ?? this.uploadStatus,
      );

  bool get isImage => mimeType.startsWith('image/');
}
