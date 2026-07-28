// Entità centrale — Ordine di Lavoro (OdL).

import 'enums.dart';
import 'value_objects.dart';
import 'meter.dart';
import 'operation.dart';
import 'material.dart';

/// Categoria funzionale di un OdL: decide quali sezioni del form dinamico
/// compaiono. Non è un dato SAP — è una nostra lettura del tipo ordine (AUFART).
enum WorkOrderCategory {
  attivazione,
  sostituzione,
  disattivazione,
  interventoRete,
  lettura,
  preventivo,
  generico,
}

/// Tipo ordine SAP (AUFART) → categoria funzionale dell'app.
///
/// **SAP è la fonte di verità.** Le chiavi qui sono i codici veri letti da DG1,
/// non i tipi ipotizzati in fase di specifica: quelli erano in parte sbagliati.
/// Rilevati sul centro **SP1 il 2026-07-17**, finestra 90 giorni, 15 ordini —
/// e 9 su 15 avevano un tipo che l'app non conosceva.
///
/// Aggiungere un codice qui è l'unico posto da toccare quando SAP ne introduce
/// uno nuovo. Un codice assente non rompe nulla: ricade su [generico].
const Map<String, WorkOrderCategory> kWorkOrderCategoryBySapType = {
  // ── Confermati dai dati reali di SP1 ──────────────────────────────────────
  'ATTI': WorkOrderCategory.attivazione, // "Misuratori - Apertura (sigillo)"
  'DISA': WorkOrderCategory.disattivazione, // "Misuratori - Chiusura (sigillo)"
  'SOST': WorkOrderCategory.sostituzione, // "Sostituzione per vetustità"
  'ZA02': WorkOrderCategory.interventoRete, // "Perdite idriche", "SOPRALLUOGO ACQUEDOTTO"

  // ── Da specifica, non ancora osservati su SP1 ─────────────────────────────
  'ZA01': WorkOrderCategory.interventoRete,
  'PA': WorkOrderCategory.preventivo,

  // ── Dedotti dalle descrizioni reali — DA CONFERMARE con il metodo/SAP ─────
  // SOPA: 6 ordini su 6 con descrizione "Perdite Idriche", identica a quella
  // degli ZA02 di perdita, e stesse operazioni (Assistenza Tecnica, Automezzi).
  'SOPA': WorkOrderCategory.interventoRete,
  // LEAP: 2 ordini su 2, "Letture aperiodiche acqua". Rilevazione contatore.
  'LEAP': WorkOrderCategory.lettura,
  // ZDE2: 1 ordine, "Ispezione depurazione". Non è né rete idrica né contatore:
  // in assenza di indicazioni resta generico, che è il default prudente.
  'ZDE2': WorkOrderCategory.generico,

  // ── Famiglia ZF = fognatura (dai dati reali di SP1, 2026-07-23) ───────────
  // ZF04 osservato come "RETI STANDARD FOGNATURA" con operazioni di scavo,
  // rinterro, ripristino e asfaltatura: è un intervento su rete fognaria.
  // ZF01/ZF02 condividono il prefisso ZF (fognatura) e la stessa natura di
  // rete. Dedotto, DA CONFERMARE col metodo/SAP.
  'ZF01': WorkOrderCategory.interventoRete,
  'ZF02': WorkOrderCategory.interventoRete, // 10 ordini su SP1
  'ZF04': WorkOrderCategory.interventoRete,

  // ── Osservati su SP1 ma semantica NON confermata → generico consapevole ───
  // Pochi ordini ciascuno, natura non chiara: lasciati a generico DI PROPOSITO
  // (mappati esplicitamente, non per fallback) finché SAP non conferma.
  'ZI04': WorkOrderCategory.generico, // investimento H2O?
  'ZLIM': WorkOrderCategory.generico,
  'DMOR': WorkOrderCategory.generico,
};

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
  final String? statoSap; // CO_STTXT — stringa stato grezza SAP (es. "RIL. CALP EDCO...")
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
  final DateTime? dataFine; // CO_GLTRP — data fine prevista SAP

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
    this.statoSap,
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
    this.dataFine,
    this.accountingSector = '',
    this.notes = '',
    this.attachmentsCount = 0,
    this.localStatus = LocalSyncStatus.synced,
    this.createdAt,
    this.updatedAt,
  });

  // ─── Logica di categoria (campi condizionali del form dinamico) ─────────────

  /// Categoria funzionale, derivata dal tipo ordine SAP (AUFART).
  ///
  /// Prima si deduceva con `woType.startsWith('ATTI')` e simili, cioè da un
  /// elenco di tipi ipotizzato in fase di specifica. I dati reali di DG1 lo
  /// hanno smentito: la maggioranza degli ordini di SP1 ha tipi che quell'elenco
  /// non prevedeva, e finiva silenziosamente in "Intervento generico".
  ///
  /// La verità è SAP. Qui c'è una tabella esplicita dei codici veri: un codice
  /// sconosciuto ricade su [WorkOrderCategory.generico], ma il tipo SAP resta
  /// visibile in interfaccia accanto all'etichetta, così un tipo nuovo si nota
  /// invece di sparire.
  WorkOrderCategory get category =>
      kWorkOrderCategoryBySapType[woType.trim().toUpperCase()] ??
      WorkOrderCategory.generico;

  /// ATTI / SOST — l'intervento è sul contatore del cliente.
  bool get hasDettagliCliente =>
      category == WorkOrderCategory.attivazione ||
      category == WorkOrderCategory.sostituzione;

  bool get hasPreventivo => category == WorkOrderCategory.preventivo;

  /// Disattivazione fornitura: lettura finale + conferma disattivazione.
  bool get hasDisattivazione => category == WorkOrderCategory.disattivazione;

  /// Apertura/attivazione fornitura: sigillo, lettura iniziale.
  bool get hasAttivazione => category == WorkOrderCategory.attivazione;

  /// Sostituzione contatore: matricola vecchio/nuovo, letture, calibro.
  bool get hasSostituzione => category == WorkOrderCategory.sostituzione;

  /// Interventi rete (perdite, interruzioni): tipo perdita, pressione.
  bool get hasInterventoRete => category == WorkOrderCategory.interventoRete;

  /// Letture aperiodiche: rilevazione del contatore senza intervento tecnico.
  bool get hasLettura => category == WorkOrderCategory.lettura;

  bool get hasMeter => meter != null;

  /// Etichetta leggibile della categoria, per le sezioni dei form dinamici.
  String get typeCategoryLabel => switch (category) {
        WorkOrderCategory.attivazione => 'Attivazione fornitura',
        WorkOrderCategory.sostituzione => 'Sostituzione contatore',
        WorkOrderCategory.disattivazione => 'Disattivazione fornitura',
        WorkOrderCategory.interventoRete => 'Intervento rete',
        WorkOrderCategory.lettura => 'Lettura contatore',
        WorkOrderCategory.preventivo => 'Preventivo',
        WorkOrderCategory.generico => 'Intervento generico',
      };

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
  String get typeEmoji => switch (category) {
        WorkOrderCategory.attivazione => '🔓',
        WorkOrderCategory.sostituzione => '🔄',
        WorkOrderCategory.disattivazione => '🚱',
        WorkOrderCategory.interventoRete => '🔧',
        WorkOrderCategory.lettura => '🔢',
        WorkOrderCategory.preventivo => '📋',
        WorkOrderCategory.generico => '⚙️',
      };

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
      statoSap: statoSap,
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
      dataFine: dataFine,
      accountingSector: accountingSector,
      notes: notes ?? this.notes,
      attachmentsCount: attachmentsCount ?? this.attachmentsCount,
      localStatus: localStatus ?? this.localStatus,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
