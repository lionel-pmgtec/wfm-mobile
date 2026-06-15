// Esito dell'intervento (tecnico + economico) — specifiche §5.5 / M5.

import 'enums.dart';
import 'value_objects.dart';

/// Lettura di un contatore registrata nell'esito.
class MeterReading {
  final String matricola;
  final num? previousReading;
  final num readingValue;
  final DateTime readingDateTime;
  final String? photoPath; // foto del contatore (obbligatoria)

  const MeterReading({
    required this.matricola,
    this.previousReading,
    required this.readingValue,
    required this.readingDateTime,
    this.photoPath,
  });
}

/// Ore lavorate (per tecnico, in caso di squadra).
class HoursWorked {
  final String technicianCid;
  final num hours;
  const HoursWorked({required this.technicianCid, required this.hours});
}

/// Esito completo dell'intervento.
class Esito {
  final String workOrderCode;
  final String technicianCid;
  final DateTime startDateTime;
  final DateTime? endDateTime;
  final EsitoResult? result;
  final String? causeCode; // motivo
  final String? solutionCode; // soluzione
  final String notes;
  final List<MeterReading> meterReadings;
  final List<HoursWorked> hoursWorked;
  final num? extraCosts; // km, pedaggi
  final Geolocation? geolocation;
  final bool customerSigned;
  final LocalSyncStatus localStatus;

  const Esito({
    required this.workOrderCode,
    required this.technicianCid,
    required this.startDateTime,
    this.endDateTime,
    this.result,
    this.causeCode,
    this.solutionCode,
    this.notes = '',
    this.meterReadings = const [],
    this.hoursWorked = const [],
    this.extraCosts,
    this.geolocation,
    this.customerSigned = false,
    this.localStatus = LocalSyncStatus.pendingUpload,
  });

  Esito copyWith({
    DateTime? endDateTime,
    EsitoResult? result,
    String? causeCode,
    String? solutionCode,
    String? notes,
    List<MeterReading>? meterReadings,
    List<HoursWorked>? hoursWorked,
    num? extraCosts,
    bool? customerSigned,
    LocalSyncStatus? localStatus,
  }) {
    return Esito(
      workOrderCode: workOrderCode,
      technicianCid: technicianCid,
      startDateTime: startDateTime,
      endDateTime: endDateTime ?? this.endDateTime,
      result: result ?? this.result,
      causeCode: causeCode ?? this.causeCode,
      solutionCode: solutionCode ?? this.solutionCode,
      notes: notes ?? this.notes,
      meterReadings: meterReadings ?? this.meterReadings,
      hoursWorked: hoursWorked ?? this.hoursWorked,
      extraCosts: extraCosts ?? this.extraCosts,
      geolocation: geolocation,
      customerSigned: customerSigned ?? this.customerSigned,
      localStatus: localStatus ?? this.localStatus,
    );
  }
}

/// Coppia codice/etichetta per i dropdown (motivo, soluzione).
class CodeLabel {
  final String code;
  final String label;
  const CodeLabel(this.code, this.label);
}
