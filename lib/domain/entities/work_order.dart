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
/// non i tipi ipotizzati in fase di specifica .
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
  'SOPA': WorkOrderCategory.interventoRete,
  'LEAP': WorkOrderCategory.lettura,
  'ZDE2': WorkOrderCategory.generico,

  'ZF01': WorkOrderCategory.interventoRete,
  'ZF02': WorkOrderCategory.interventoRete, // 10 ordini su SP1
  'ZF04': WorkOrderCategory.interventoRete,

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

  // ── CLIENTE ────────────────────────────────────────────────
  final Address address;
  final Customer customer;
  final String? codiceCliente; // se non presente in customer
  final String? referente;
  final String? telefonoCliente;

  // ── INDIRIZZI ──────────────────────────────────────────────
  final Address? indirizzoOggetto;
  final Address? indirizzoIntervento;

  // ── DATI TECNICI ───────────────────────────────────────────
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

  // ── RISORSE ────────────────────────────────────────────────
  final String? cidAssegnato; // tecnico assegnato — modificabile
  final String squadra;
  final String? responsabile;
  final String? fornitoreEsterno;
  final bool reperibilita;

  // ── AMPLIAMENTO ────────────────────────────────────────────
  final String? impiantoDis; // impianto disattivazione
  final String? contratto;

  // ── PIANIFICAZIONE ─────────────────────────────────────────
  final String? ultimoCicloManutenzione;
  final String? postManut;
  final DateTime? dataEsec;
  final DateTime? dataFine; // CO_GLTRP — data fine prevista SAP

  // ── ALTRI ─────────────────────────────────────────────────────────
  final String accountingSector; // POT, FOG...
  final String notes; // SAP + campo unite (retro-compat)
  /// Nota SAP (DESCRIZIONE/NOTE dell'ordine) — SOLA LETTURA.
  final String noteSap;
  /// Note aggiunte sul campo dal tecnico — modificabili (PATCH `notes`).
  final String noteAggiunte;
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
    this.noteSap = '',
    this.noteAggiunte = '',
    this.attachmentsCount = 0,
    this.localStatus = LocalSyncStatus.synced,
    this.createdAt,
    this.updatedAt,
  });

  // ─── Logica di categoria (campi condizionali del form dinamico) ─────────────

  /// Categoria funzionale, derivata dal tipo ordine SAP (AUFART).
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

  /// Posa contatore (prima attivazione): l'operatore INSTALLA un contatore
  /// nuovo, quindi ne inserisce matricola/lettura di posa. Si riconosce dal
  /// tipo di attività SAP (TP_ATT_PM = "POS") o dalla descrizione ("posa"):
  /// il WS non manda un flag dedicato. Sui POS reali il DATI_APPARECCHIATURA
  /// arriva vuoto ([meter] == null): è comunque una posa.
  bool get isPosaContatore {
    if (category != WorkOrderCategory.attivazione) return false;
    final cod =
        '${tipoAttivitaCodice ?? ''} $subTam'.trim().toUpperCase();
    if (cod.split(RegExp(r'\s+')).contains('POS')) return true;
    final txt = '${tipoAttivitaNome ?? ''} $woTypeDescription'.toLowerCase();
    return txt.contains('posa');
  }

  /// Contatore da INSTALLARE sul campo: una posa, oppure un'attivazione senza
  /// contatore in anagrafica (matricola assente). In questi casi l'operatore
  /// digita la matricola e non esiste una lettura precedente.
  bool get isNuovoContatore =>
      isPosaContatore ||
      (hasAttivazione && (meter?.matricola ?? matricola ?? '').trim().isEmpty);

  /// L'intervento prevede una lettura del contatore da trasmettere alla
  /// chiusura: qualunque OdL con contatore in anagrafica, più le attivazioni
  /// (anche quando il contatore è nuovo e quindi assente da SAP).
  bool get hasMeterReading => meter != null || hasAttivazione;

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

  /// Nome mostrato dell'OdL. Usa la descrizione SAP quando è presente e
  /// significativa (non vuota e diversa dal solo codice tipo); altrimenti
  /// ripiega sull'etichetta leggibile della categoria — così un nome c'è sempre.
  String get displayName {
    final d = woTypeDescription.trim();
    if (d.isEmpty || d.toUpperCase() == woType.trim().toUpperCase()) {
      return typeCategoryLabel;
    }
    return d;
  }

  // ─── Transizioni del ciclo di vita ────────────────────

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

  /// Pronto Intervento — intervento urgente da rendere subito visibile in Home.
  ///
  /// Non è un flag dedicato di SAP: lo deriviamo dai campi già esposti dal
  /// backend, senza inventare dati. È PI un ordine il cui tipo (AUFART) ricade
  /// nella categoria [WorkOrderCategory.interventoRete] — cioè i codici di
  /// pronto intervento rete/emergenza (ZA01, ZA02, ZF0x, SOPA…) — oppure
  /// segnalato in reperibilità dal flag SAP [reperibilita].
  bool get isProntoIntervento =>
      category == WorkOrderCategory.interventoRete || reperibilita;

  /// Vero se la priorità indica alta urgenza (Alta / 1 / urgente).
  /// Usato per ordinare i Pronto Intervento e per l'etichetta in Home.
  bool get isHighPriority {
    final p = priorita.trim().toLowerCase();
    if (p.isEmpty) return false;
    return p.contains('alta') ||
        p.contains('urgent') ||
        p == '1' ||
        p == 'a';
  }

  /// Emoji indicativa in base alla tipologia (mostrata come testo accanto al
  /// nome). NB: deve restituire un vero glifo, non il nome di un'icona.
  String get typeEmoji => switch (category) {
        WorkOrderCategory.attivazione => '🔓',
        WorkOrderCategory.sostituzione => '🔄',
        WorkOrderCategory.disattivazione => '⛔',
        WorkOrderCategory.interventoRete => '🔧',
        WorkOrderCategory.lettura => '🔢',
        WorkOrderCategory.preventivo => '📋',
        WorkOrderCategory.generico => '⚙️',
      };

  WorkOrder copyWith({
    WorkOrderStatus? status,
    String? notes,
    String? noteAggiunte,
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
      noteSap: noteSap,
      noteAggiunte: noteAggiunte ?? this.noteAggiunte,
      attachmentsCount: attachmentsCount ?? this.attachmentsCount,
      localStatus: localStatus ?? this.localStatus,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
