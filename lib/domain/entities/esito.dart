// Esito dell'intervento (tecnico + economico).
import 'enums.dart';
import 'value_objects.dart';
import 'material.dart';

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

/// Ore lavorate su una singola operazione (fase) dell'OdL.
/// Inviate alla chiusura in `hoursWorked` con la forma attesa dal
/// backend/cruscotto: { operation, description, hours }.
class HoursWorked {
  final String operation; // codice operazione SAP (0010, 0040…)
  final String description; // testo breve (Trasferimento, Lavori Idraulici…)
  final num hours;
  const HoursWorked({
    this.operation = '',
    this.description = '',
    required this.hours,
  });
}

/// Esito dell'appuntamento/sopralluogo, inviato insieme all'esito finale
/// (POST /esiti, nodo `appointment`). Campi allineati al backend.
class EsitoAppuntamento {
  final String? esito; // OK / NO / ER / MN
  final String? causa; // codice causa (catalogo backend)
  final String? motivo; // testo libero
  final bool? clientePresente;
  final DateTime? sopralluogoData;
  final String? sopralluogoOra;
  final String? ritiro;
  final String? causaRitardo;
  final String? motivoRitardo;

  const EsitoAppuntamento({
    this.esito,
    this.causa,
    this.motivo,
    this.clientePresente,
    this.sopralluogoData,
    this.sopralluogoOra,
    this.ritiro,
    this.causaRitardo,
    this.motivoRitardo,
  });
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
  /// Materiali impegnati sul campo (inviati al backend con l'esito).
  final List<MaterialUsage> materials;
  /// Esito appuntamento/sopralluogo, inviato col nodo `appointment`.
  final EsitoAppuntamento? appointment;
  final List<HoursWorked> hoursWorked;
  /// Spostamento contatore deciso sul campo (nuova ubicazione). Inviato nel
  /// nodo `contatore` di POST /esiti. Vuoto = contatore non spostato.
  final String? newMeterLocation;
  final String? newMeterLocationAdditional;
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
    this.materials = const [],
    this.appointment,
    this.hoursWorked = const [],
    this.newMeterLocation,
    this.newMeterLocationAdditional,
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
    List<MaterialUsage>? materials,
    EsitoAppuntamento? appointment,
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
      materials: materials ?? this.materials,
      appointment: appointment ?? this.appointment,
      hoursWorked: hoursWorked ?? this.hoursWorked,
      newMeterLocation: newMeterLocation,
      newMeterLocationAdditional: newMeterLocationAdditional,
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
