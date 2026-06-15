// Operazione in coda di sincronizzazione (offline-first).

import 'enums.dart';

class SyncOperation {
  final String id; // UUID
  final SyncOperationType type;
  final String entityId; // es. workOrderCode
  final Map<String, dynamic> payload;
  final SyncStatus status;
  final int retryCount;
  final DateTime? nextRetryAt;
  final String? lastError;
  final DateTime createdAt;

  const SyncOperation({
    required this.id,
    required this.type,
    required this.entityId,
    this.payload = const {},
    this.status = SyncStatus.pending,
    this.retryCount = 0,
    this.nextRetryAt,
    this.lastError,
    required this.createdAt,
  });

  /// Backoff esponenziale (specifiche §12.4).
  static const List<Duration> backoff = [
    Duration(seconds: 0),
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 5),
    Duration(minutes: 30),
    Duration(hours: 2),
  ];

  String get typeLabel => switch (type) {
        SyncOperationType.submitEsito => 'Invio esito',
        SyncOperationType.updateStatus => 'Aggiornamento stato',
        SyncOperationType.uploadAttachment => 'Caricamento allegato',
        SyncOperationType.submitMeterReading => 'Lettura contatore',
        SyncOperationType.submitMaterials => 'Impegno materiali',
        SyncOperationType.createWorkOrder => 'Creazione OdL',
        SyncOperationType.createNotification => 'Creazione avviso',
      };

  SyncOperation copyWith({
    SyncStatus? status,
    int? retryCount,
    DateTime? nextRetryAt,
    String? lastError,
  }) {
    return SyncOperation(
      id: id,
      type: type,
      entityId: entityId,
      payload: payload,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt,
    );
  }
}
