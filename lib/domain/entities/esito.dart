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

/// Oggetto del lavoro (mezzo o apparecchiatura impegnata), inviato in
/// POST /esiti nel nodo `objects`. Per un automezzo [equipment] è la targa e la
/// descrizione comincia col numero del mezzo, come nella lista oggetti di SAP.
class EsitoObject {
  final String equipment;
  final String description;
  const EsitoObject({required this.equipment, this.description = ''});
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
  /// Oggetti del lavoro (mezzi/apparecchiature), nodo `objects` di POST /esiti.
  final List<EsitoObject> objects;
  /// Spostamento contatore deciso sul campo (nuova ubicazione). Inviato nel
  /// nodo `contatore` di POST /esiti. Vuoto = contatore non spostato.
  final String? newMeterLocation;
  final String? newMeterLocationAdditional;
  final String? newMeterPosition; // posizione in batteria (contatore.newPosition)
  /// NUOVO contatore posato (SOST): nodo `newMeter` di POST /esiti.
  final String? newMeterSerial; // serialNumber
  final String? newMeterManufacturer; // manufacturer (produttore)
  final num? newMeterInstallReading; // installReading (lettura di posa)
  final DateTime? newMeterInstallDate; // installDate (data di posa)
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
    this.objects = const [],
    this.newMeterLocation,
    this.newMeterLocationAdditional,
    this.newMeterPosition,
    this.newMeterSerial,
    this.newMeterManufacturer,
    this.newMeterInstallReading,
    this.newMeterInstallDate,
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
    List<EsitoObject>? objects,
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
      objects: objects ?? this.objects,
      newMeterLocation: newMeterLocation,
      newMeterLocationAdditional: newMeterLocationAdditional,
      newMeterPosition: newMeterPosition,
      newMeterSerial: newMeterSerial,
      newMeterManufacturer: newMeterManufacturer,
      newMeterInstallReading: newMeterInstallReading,
      newMeterInstallDate: newMeterInstallDate,
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
