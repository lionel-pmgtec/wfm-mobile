// (De)serializzazione LOCALE (Hive) di allegati, bozze esito e coda di sync.
//
// Non è il contratto col backend (quello sta in mappers.dart): serve solo a far
// sopravvivere al riavvio dell'app ciò che è ancora da inviare. Per questo
// contiene anche campi che il backend non vede (es. previousReading).

import '../../domain/entities/entities.dart';
import 'mappers.dart';

DateTime? _dt(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());

T? _byName<T extends Enum>(List<T> values, dynamic name) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return null;
}

// ─── ALLEGATO ────────────────────────────────────────────────────────────────

Map<String, dynamic> attachmentToLocalJson(Attachment a) => {
      'id': a.id,
      'workOrderCode': a.workOrderCode,
      'type': a.type.name,
      'filePath': a.filePath,
      'fileName': a.fileName,
      'mimeType': a.mimeType,
      'sizeBytes': a.sizeBytes,
      'geolocation': _geoToJson(a.geolocation),
      'capturedAt': a.capturedAt.toIso8601String(),
      'author': a.author,
      'uploadStatus': a.uploadStatus.name,
    };

Attachment attachmentFromLocalJson(Map<String, dynamic> j) => Attachment(
      id: j['id'].toString(),
      workOrderCode: j['workOrderCode'].toString(),
      type: _byName(AttachmentType.values, j['type']) ?? AttachmentType.documento,
      filePath: (j['filePath'] ?? '').toString(),
      fileName: (j['fileName'] ?? '').toString(),
      mimeType: (j['mimeType'] ?? 'image/jpeg').toString(),
      sizeBytes: (j['sizeBytes'] as num?)?.toInt() ?? 0,
      geolocation: _geoFromJson(j['geolocation']),
      capturedAt: _dt(j['capturedAt']) ?? DateTime.now(),
      author: (j['author'] ?? '').toString(),
      uploadStatus:
          _byName(UploadStatus.values, j['uploadStatus']) ?? UploadStatus.local,
    );

Map<String, dynamic>? _geoToJson(Geolocation? g) => g == null
    ? null
    : {
        'latitude': g.latitude,
        'longitude': g.longitude,
        'accuracy': g.accuracy,
        'capturedAt': g.capturedAt.toIso8601String(),
      };

Geolocation? _geoFromJson(dynamic v) {
  if (v is! Map) return null;
  return Geolocation(
    latitude: (v['latitude'] as num).toDouble(),
    longitude: (v['longitude'] as num).toDouble(),
    accuracy: (v['accuracy'] as num?)?.toDouble() ?? 0,
    capturedAt: _dt(v['capturedAt']) ?? DateTime.now(),
  );
}

// ─── BOZZA ESITO ─────────────────────────────────────────────────────────────

Map<String, dynamic> esitoToLocalJson(Esito e) => {
      'workOrderCode': e.workOrderCode,
      'technicianCid': e.technicianCid,
      'startDateTime': e.startDateTime.toIso8601String(),
      'endDateTime': e.endDateTime?.toIso8601String(),
      'result': e.result?.name,
      'causeCode': e.causeCode,
      'solutionCode': e.solutionCode,
      'notes': e.notes,
      'meterReadings': [
        for (final r in e.meterReadings)
          {
            'matricola': r.matricola,
            'previousReading': r.previousReading,
            'readingValue': r.readingValue,
            'readingDateTime': r.readingDateTime.toIso8601String(),
            'photoPath': r.photoPath,
          }
      ],
      'materials': e.materials.map(materialUsageToJson).toList(),
      'appointment': e.appointment == null
          ? null
          : {
              'esito': e.appointment!.esito,
              'causa': e.appointment!.causa,
              'motivo': e.appointment!.motivo,
              'clientePresente': e.appointment!.clientePresente,
              'sopralluogoData':
                  e.appointment!.sopralluogoData?.toIso8601String(),
              'sopralluogoOra': e.appointment!.sopralluogoOra,
              'ritiro': e.appointment!.ritiro,
              'causaRitardo': e.appointment!.causaRitardo,
              'motivoRitardo': e.appointment!.motivoRitardo,
            },
      'hoursWorked': [
        for (final h in e.hoursWorked)
          {
            'operation': h.operation,
            'description': h.description,
            'hours': h.hours,
          }
      ],
      'objects': [
        for (final o in e.objects)
          {'equipment': o.equipment, 'description': o.description}
      ],
      'newMeterLocation': e.newMeterLocation,
      'newMeterLocationAdditional': e.newMeterLocationAdditional,
      'newMeterPosition': e.newMeterPosition,
      'newMeterSerial': e.newMeterSerial,
      'newMeterManufacturer': e.newMeterManufacturer,
      'newMeterInstallReading': e.newMeterInstallReading,
      'newMeterInstallDate': e.newMeterInstallDate?.toIso8601String(),
      'extraCosts': e.extraCosts,
      'geolocation': _geoToJson(e.geolocation),
      'customerSigned': e.customerSigned,
      'localStatus': e.localStatus.name,
    };

Esito esitoFromLocalJson(Map<String, dynamic> j) {
  final ap = j['appointment'];
  return Esito(
    workOrderCode: j['workOrderCode'].toString(),
    technicianCid: (j['technicianCid'] ?? '').toString(),
    startDateTime: _dt(j['startDateTime']) ?? DateTime.now(),
    endDateTime: _dt(j['endDateTime']),
    result: _byName(EsitoResult.values, j['result']),
    causeCode: j['causeCode']?.toString(),
    solutionCode: j['solutionCode']?.toString(),
    notes: (j['notes'] ?? '').toString(),
    meterReadings: [
      for (final r in (j['meterReadings'] as List? ?? const []))
        MeterReading(
          matricola: (r['matricola'] ?? '').toString(),
          previousReading: r['previousReading'] as num?,
          readingValue: (r['readingValue'] as num?) ?? 0,
          readingDateTime: _dt(r['readingDateTime']) ?? DateTime.now(),
          photoPath: r['photoPath']?.toString(),
        )
    ],
    materials: [
      for (final m in (j['materials'] as List? ?? const []))
        materialUsageFromJson(Map<String, dynamic>.from(m as Map))
    ],
    appointment: ap is! Map
        ? null
        : EsitoAppuntamento(
            esito: ap['esito']?.toString(),
            causa: ap['causa']?.toString(),
            motivo: ap['motivo']?.toString(),
            clientePresente: ap['clientePresente'] as bool?,
            sopralluogoData: _dt(ap['sopralluogoData']),
            sopralluogoOra: ap['sopralluogoOra']?.toString(),
            ritiro: ap['ritiro']?.toString(),
            causaRitardo: ap['causaRitardo']?.toString(),
            motivoRitardo: ap['motivoRitardo']?.toString(),
          ),
    hoursWorked: [
      for (final h in (j['hoursWorked'] as List? ?? const []))
        HoursWorked(
          operation: (h['operation'] ?? '').toString(),
          description: (h['description'] ?? '').toString(),
          hours: (h['hours'] as num?) ?? 0,
        )
    ],
    objects: [
      for (final o in (j['objects'] as List? ?? const []))
        EsitoObject(
          equipment: (o['equipment'] ?? '').toString(),
          description: (o['description'] ?? '').toString(),
        )
    ],
    newMeterLocation: j['newMeterLocation']?.toString(),
    newMeterLocationAdditional: j['newMeterLocationAdditional']?.toString(),
    newMeterPosition: j['newMeterPosition']?.toString(),
    newMeterSerial: j['newMeterSerial']?.toString(),
    newMeterManufacturer: j['newMeterManufacturer']?.toString(),
    newMeterInstallReading: j['newMeterInstallReading'] as num?,
    newMeterInstallDate: _dt(j['newMeterInstallDate']),
    extraCosts: j['extraCosts'] as num?,
    geolocation: _geoFromJson(j['geolocation']),
    customerSigned: j['customerSigned'] == true,
    localStatus: _byName(LocalSyncStatus.values, j['localStatus']) ??
        LocalSyncStatus.pendingUpload,
  );
}

// ─── CODA DI SINCRONIZZAZIONE ────────────────────────────────────────────────

Map<String, dynamic> syncOperationToJson(SyncOperation o) => {
      'id': o.id,
      'type': o.type.name,
      'entityId': o.entityId,
      'payload': o.payload,
      'status': o.status.name,
      'retryCount': o.retryCount,
      'nextRetryAt': o.nextRetryAt?.toIso8601String(),
      'lastError': o.lastError,
      'createdAt': o.createdAt.toIso8601String(),
    };

SyncOperation? syncOperationFromJson(Map<String, dynamic> j) {
  final type = _byName(SyncOperationType.values, j['type']);
  if (type == null) return null; // tipo sconosciuto (versione diversa): si scarta
  return SyncOperation(
    id: j['id'].toString(),
    type: type,
    entityId: (j['entityId'] ?? '').toString(),
    payload: Map<String, dynamic>.from((j['payload'] as Map?) ?? const {}),
    // Un'operazione rimasta "in corso" a app chiusa va ritentata.
    status: (_byName(SyncStatus.values, j['status']) ?? SyncStatus.pending) ==
            SyncStatus.inProgress
        ? SyncStatus.pending
        : (_byName(SyncStatus.values, j['status']) ?? SyncStatus.pending),
    retryCount: (j['retryCount'] as num?)?.toInt() ?? 0,
    nextRetryAt: _dt(j['nextRetryAt']),
    lastError: j['lastError']?.toString(),
    createdAt: _dt(j['createdAt']) ?? DateTime.now(),
  );
}
