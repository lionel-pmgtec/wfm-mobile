// Entità centrale — Ordine di Lavoro (OdL).

import 'enums.dart';
import 'value_objects.dart';
import 'meter.dart';
import 'operation.dart';
import 'material.dart';

class WorkOrder {
  // ── DATI ORDINE (spec) ────────────────────────────────────────────
  final String externalCode; // numero OdL (es. 50674709)
  final String? notificationNumberSap; // avviso origine
  final String woType; // ATTI, DISA, ZA01, ZA02, PA
  final String woTypeDescription; // descrizione tipo ordine
  final String tam; // codice tipo attività
  final String subTam; // sotto-tipo attività (ADS...)
  final String? tipoAttivitaCodice; // codice attività SAP (spec)
  final String? tipoAttivitaNome; // nome attività
  final WorkOrderStatus status;
  final String priorita; // Alta / Media / Bassa
  final String? creatoDa; // utente SAP creatore
  final String? avvisoOrigine; // riferimento avviso (back-compat con notificationNumberSap)
  final String centroPianificazione;
  final String centroLavoro;

  final DateTime? appointmentDate;
  final String appointmentStartTime;
  final String appointmentEndTime;

  // ── CLIENTE (spec) ────────────────────────────────────────────────
  final Address address;
  final Customer customer;
  final String? codiceCliente; // se non presente in customer
  final String? referente;
  final String? telefonoCliente;

  // ── INDIRIZZI (spec) ──────────────────────────────────────────────
  final Address? indirizzoOggetto;
  final Address? indirizzoIntervento;

  // ── DATI TECNICI (spec) ───────────────────────────────────────────
  final String sedeTecnica;
  final String equipment;
  final String? matricola;
  final String ubicazione; // ubicazione tecnica
  final String aggUbicazione;
  final String impianto;
  final Meter? meter;

  // ── OPERAZIONI E MATERIALI ────────────────────────────────────────
  final List<Operation> operations;
  final List<MaterialUsage> plannedMaterials;

  // ── RISORSE (spec) ────────────────────────────────────────────────
  final String? cidAssegnato; // tecnico assegnato — modificabile
  final String squadra;
  final String? responsabile;
  final String? fornitoreEsterno;
  final bool reperibilita;

  // ── AMPLIAMENTO (spec) ────────────────────────────────────────────
  final String? impiantoDis; // impianto disattivazione
  final String? contratto;

  // ── PIANIFICAZIONE (spec) ─────────────────────────────────────────
  final String? ultimoCicloManutenzione;
  final String? postManut;
  final DateTime? dataEsec;

  // ── ALTRI ─────────────────────────────────────────────────────────
  final String accountingSector; // POT, FOG...
  final String notes;
  final int attachmentsCount;
  final LocalSyncStatus localStatus;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const WorkOrder({
    required this.externalCode,
    this.notificationNumberSap,
    required this.woType,
    this.woTypeDescription = '',
    this.tam = '',
    this.subTam = '',
    this.tipoAttivitaCodice,
    this.tipoAttivitaNome,
    this.status = WorkOrderStatus.ricevuto,
    this.priorita = '',
    this.creatoDa,
    this.avvisoOrigine,
    this.centroPianificazione = '',
    this.centroLavoro = '',
    this.appointmentDate,
    this.appointmentStartTime = '',
    this.appointmentEndTime = '',
    this.address = const Address(),
    this.customer = const Customer(),
    this.codiceCliente,
    this.referente,
    this.telefonoCliente,
    this.indirizzoOggetto,
    this.indirizzoIntervento,
    this.sedeTecnica = '',
    this.equipment = '',
    this.matricola,
    this.ubicazione = '',
    this.aggUbicazione = '',
    this.impianto = '',
    this.meter,
    this.operations = const [],
    this.plannedMaterials = const [],
    this.cidAssegnato,
    this.squadra = '',
    this.responsabile,
    this.fornitoreEsterno,
    this.reperibilita = false,
    this.impiantoDis,
    this.contratto,
    this.ultimoCicloManutenzione,
    this.postManut,
    this.dataEsec,
    this.accountingSector = '',
    this.notes = '',
    this.attachmentsCount = 0,
    this.localStatus = LocalSyncStatus.synced,
    this.createdAt,
    this.updatedAt,
  });

  // ─── Logica di categoria (campi condizionali del form dinamico) ─────────────

  bool get hasDettagliCliente =>
      woType.startsWith('ATTI') || woType.startsWith('SOST');

  bool get hasNormativa655 =>
      woType.startsWith('ZA') ||
      woTypeDescription.toLowerCase().contains('interruzione');

  bool get hasDatiRqti =>
      woType.startsWith('ZA') ||
      woTypeDescription.toLowerCase().contains('perdita') ||
      woTypeDescription.toLowerCase().contains('riparazione');

  bool get hasPreventivo => woType.startsWith('PA');

  /// DISA — Disattivazione fornitura: lettura finale + conferma disattivazione.
  bool get hasDisattivazione => woType.startsWith('DISA');

  /// ATTI — Apertura/attivazione fornitura: sigillo, lettura iniziale.
  bool get hasAttivazione => woType.startsWith('ATTI');

  /// SOST — Sostituzione contatore: matricola vecchio/nuovo, letture, calibro.
  bool get hasSostituzione => woType.startsWith('SOST');

  /// ZA — Interventi rete (perdite, interruzioni): tipo perdita, pressione.
  bool get hasInterventoRete => woType.startsWith('ZA');

  bool get hasMeter => meter != null;

  /// Etichetta leggibile della categoria, per le sezioni dei form dinamici.
  String get typeCategoryLabel {
    if (hasAttivazione) return 'Attivazione fornitura';
    if (hasSostituzione) return 'Sostituzione contatore';
    if (hasDisattivazione) return 'Disattivazione fornitura';
    if (hasInterventoRete) return 'Intervento rete';
    if (hasPreventivo) return 'Preventivo';
    return 'Intervento generico';
  }

  // ─── Transizioni del ciclo di vita (specifiche EF-M4.1) ────────────────────

  bool get canStart =>
      status == WorkOrderStatus.ricevuto || status == WorkOrderStatus.sospeso;
  bool get canPause => status == WorkOrderStatus.inEsecuzione;
  bool get canResumeFromPause => status == WorkOrderStatus.inPausa;
  bool get canSuspend =>
      status == WorkOrderStatus.inEsecuzione || status == WorkOrderStatus.inPausa;
  bool get canComplete =>
      status == WorkOrderStatus.inEsecuzione || status == WorkOrderStatus.inPausa;
  bool get canCancel =>
      status != WorkOrderStatus.completato &&
      status != WorkOrderStatus.annullato &&
      status != WorkOrderStatus.inviatoSAP;
  bool get isClosed =>
      status == WorkOrderStatus.completato ||
      status == WorkOrderStatus.annullato ||
      status == WorkOrderStatus.inviatoSAP;

  /// Icona indicativa in base alla tipologia.
  String get typeEmoji {
    if (woType.startsWith('ATTI')) return '🔓';
    if (woType.startsWith('SOST')) return '🔄';
    if (woType.startsWith('DISA')) return '🚱';
    if (woType.startsWith('ZA')) return '🔧';
    if (woType.startsWith('PA')) return '📋';
    return '⚙️';
  }

  WorkOrder copyWith({
    WorkOrderStatus? status,
    String? notes,
    String? aggUbicazione,
    String? cidAssegnato,
    List<Operation>? operations,
    List<MaterialUsage>? plannedMaterials,
    LocalSyncStatus? localStatus,
    int? attachmentsCount,
    DateTime? updatedAt,
  }) {
    return WorkOrder(
      externalCode: externalCode,
      notificationNumberSap: notificationNumberSap,
      woType: woType,
      woTypeDescription: woTypeDescription,
      tam: tam,
      subTam: subTam,
      tipoAttivitaCodice: tipoAttivitaCodice,
      tipoAttivitaNome: tipoAttivitaNome,
      status: status ?? this.status,
      priorita: priorita,
      creatoDa: creatoDa,
      avvisoOrigine: avvisoOrigine,
      centroPianificazione: centroPianificazione,
      centroLavoro: centroLavoro,
      appointmentDate: appointmentDate,
      appointmentStartTime: appointmentStartTime,
      appointmentEndTime: appointmentEndTime,
      address: address,
      customer: customer,
      codiceCliente: codiceCliente,
      referente: referente,
      telefonoCliente: telefonoCliente,
      indirizzoOggetto: indirizzoOggetto,
      indirizzoIntervento: indirizzoIntervento,
      sedeTecnica: sedeTecnica,
      equipment: equipment,
      matricola: matricola,
      ubicazione: ubicazione,
      aggUbicazione: aggUbicazione ?? this.aggUbicazione,
      impianto: impianto,
      meter: meter,
      operations: operations ?? this.operations,
      plannedMaterials: plannedMaterials ?? this.plannedMaterials,
      cidAssegnato: cidAssegnato ?? this.cidAssegnato,
      squadra: squadra,
      responsabile: responsabile,
      fornitoreEsterno: fornitoreEsterno,
      reperibilita: reperibilita,
      impiantoDis: impiantoDis,
      contratto: contratto,
      ultimoCicloManutenzione: ultimoCicloManutenzione,
      postManut: postManut,
      dataEsec: dataEsec,
      accountingSector: accountingSector,
      notes: notes ?? this.notes,
      attachmentsCount: attachmentsCount ?? this.attachmentsCount,
      localStatus: localStatus ?? this.localStatus,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
