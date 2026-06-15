// Avviso di servizio.
//
// **REGOLE SAP (read-only)** : tutti i campi qui presenti provengono da SAP
// e NON possono essere modificati dall'app. Le informazioni aggiuntive che
// l'utente può aggiungere risiedono in [AvvisoExtension] (firma, preventivo,
// permessi, lavori cliente, documenti, sospensioni, note).

import 'avviso_category.dart';
import 'value_objects.dart';
import 'enums.dart';

class NotificationAvviso {
  // ── Identità ──────────────────────────────────────────────────────────────
  final String numeroAvviso; // Qmnum
  final String descrizione; // descrizione principale (back-compat)
  final String? descrizioneBreve; // spec: descrizione breve
  final String? descrizioneEstesa; // spec: descrizione estesa
  final String tipo; // codice sottotipo SAP (ZF-PF, ZA01, ZF-ZF01, ZA02, PA)
  final String? cid; // Codice Identificativo Disservizio/Chiamata

  // ── Classificazione ──────────────────────────────────────────────────────
  final CategoriaIntervento? categoriaIntervento; // Guasto/Installazione/Manutenzione
  final CanaleApertura? canaleApertura; // Telefono/Email/Web
  final TipoServizio? tipoServizio; // Emergenza/Programmato
  final String? codiceGuasto; // Malfunction Code (SAP)
  final String? codiceCausa; // Cause Code (SAP)
  final String? noteOperatore; // libere operatore call-center

  // ── Dati Avviso (SAP) ─────────────────────────────────────────────────────
  final String priorita;
  final String stato; // stringa libera per retro-compatibilità
  final AvvisoStato? statoEnum; // versione tipata (spec)
  final String? contratto; // riferimento contratto SAP
  final String? codiceContratto; // separato per chiarezza
  final bool contrattoAttivo; // SI/NO
  final String? sedeTecnica;
  final String? ubicazioneTecnica;
  final String? equipment;
  final String? matricola; // matricola equipment
  final StatoEquipment? statoEquipment;
  final String? categoriaTecnica;
  final String? tipoImpianto;
  final String? impianto; // codice impianto
  final String? puntoMisura;
  final String? centroLavoro;
  final String? assegnatoA; // tecnico assegnato (nome)
  final String? squadra; // squadra assegnata
  final String? cidAssegnato; // CID tecnico
  final String? autore;
  final String? creatoDa; // utente SAP creatore avviso
  final String? codiceCliente; // separato da customer.codCli
  final String? referente; // referente cliente
  final String? cellulare; // cellulare cliente (separato)
  final String? codiceFiscaleCliente; // legacy: spostato in Customer.codiceFiscale
  final String? areaTecnica; // area tecnica geografica (PI)
  final String? noteAccesso; // note di accesso al sito (PI)
  final bool gestionePermessi; // flag SAP
  final bool lavoriACaricoCliente; // flag SAP
  final bool reperibilita; // flag SAP: intervento in reperibilità

  // ── SLA / urgenza ───────────────────────────────────────────────────────
  final String? slaTarget; // es. "4h" — tempo massimo intervento
  final String? tempoRispostaAtteso; // es. "2h"
  final bool urgente; // intervento urgente flag
  final String? motivoUrgenza;

  // ── Date intervento (SAP) ────────────────────────────────────────────────
  final DateTime? dataApertura; // timestamp creazione
  final String? oraApertura;
  final DateTime? dataPianificata;
  final DateTime? dataInterventoRichiesta; // spec PI
  final DateTime? dataInizioGuasto; // spec PI
  final DateTime? dataFineGuasto; // spec PI
  final DateTime? dataInizioIntervento; // "Data Inizio Lavoro"
  final String? oraInizioIntervento;
  final DateTime? dataFineIntervento; // "Data Fine Lavoro"
  final String? oraFineIntervento;
  final DateTime? dataChiusura;
  final FasciaOraria? fasciaOraria;

  // ── Gestione intervento (lifecycle tecnico) ──────────────────────────────
  final DateTime? dataPresaInCarico;
  final DateTime? dataInvioTecnico;
  final DateTime? dataArrivoPrevista;
  final StatoOperativo? statoOperativo;

  // Date richiesta (esistenti, mantenute):
  final DateTime? dataInizioRichiesta;
  final String? oraInizioRichiesta;
  final DateTime? dataFineRichiesta;
  final String? oraFineRichiesta;

  // Legacy: data/ora segnalazione (manteniamo per compatibilità).
  final DateTime? dataSegnalazione;
  final String? oraSegnalazione;

  // ── Indirizzi (spec §4 - Sezione 3) ─────────────────────────────────────
  /// Indirizzo dell'Avviso (sede della segnalazione / indirizzo amministrativo).
  final Address address;
  /// Telefono dell'indirizzo Avviso.
  final String? indirizzoAvvisoTelefono;
  /// Indirizzo Oggetto (dove si trova l'oggetto tecnico — es. impianto).
  final Address? indirizzoOggetto;
  /// Indirizzo Lavoro (dove si esegue il lavoro fisico — può coincidere
  /// con Oggetto, ma è separato per gestire i casi di lavori in trincea
  /// su impianti di altri edifici).
  final Address? indirizzoLavoro;

  // ── Cliente (SAP) ─────────────────────────────────────────────────────────
  final Customer customer;

  // ── OdL collegato ─────────────────────────────────────────────────────────
  final String? ordineDiLavoro;
  final String? statoOdl;
  final String? calibro;
  final String? codiceMateriale;

  // ── Flags ────────────────────────────────────────────────────────────────
  final bool interruzioneFornitura;
  final LocalSyncStatus localStatus;

  const NotificationAvviso({
    required this.numeroAvviso,
    required this.descrizione,
    required this.tipo,
    this.descrizioneBreve,
    this.descrizioneEstesa,
    this.cid,
    this.categoriaIntervento,
    this.canaleApertura,
    this.tipoServizio,
    this.codiceGuasto,
    this.codiceCausa,
    this.noteOperatore,
    this.priorita = '',
    this.stato = 'Creato',
    this.statoEnum,
    this.contratto,
    this.codiceContratto,
    this.contrattoAttivo = false,
    this.sedeTecnica,
    this.ubicazioneTecnica,
    this.equipment,
    this.matricola,
    this.statoEquipment,
    this.categoriaTecnica,
    this.tipoImpianto,
    this.impianto,
    this.puntoMisura,
    this.centroLavoro,
    this.assegnatoA,
    this.squadra,
    this.cidAssegnato,
    this.autore,
    this.creatoDa,
    this.codiceCliente,
    this.referente,
    this.cellulare,
    this.codiceFiscaleCliente,
    this.areaTecnica,
    this.noteAccesso,
    this.gestionePermessi = false,
    this.lavoriACaricoCliente = false,
    this.reperibilita = false,
    this.slaTarget,
    this.tempoRispostaAtteso,
    this.urgente = false,
    this.motivoUrgenza,
    this.dataApertura,
    this.oraApertura,
    this.dataPianificata,
    this.dataInterventoRichiesta,
    this.dataInizioGuasto,
    this.dataFineGuasto,
    this.dataChiusura,
    this.fasciaOraria,
    this.dataPresaInCarico,
    this.dataInvioTecnico,
    this.dataArrivoPrevista,
    this.statoOperativo,
    this.dataInizioRichiesta,
    this.oraInizioRichiesta,
    this.dataFineRichiesta,
    this.oraFineRichiesta,
    this.dataInizioIntervento,
    this.oraInizioIntervento,
    this.dataFineIntervento,
    this.oraFineIntervento,
    this.dataSegnalazione,
    this.oraSegnalazione,
    this.address = const Address(),
    this.indirizzoAvvisoTelefono,
    this.indirizzoOggetto,
    this.indirizzoLavoro,
    this.customer = const Customer(),
    this.ordineDiLavoro,
    this.statoOdl,
    this.calibro,
    this.codiceMateriale,
    this.interruzioneFornitura = false,
    this.localStatus = LocalSyncStatus.synced,
  });

  /// Stato tipizzato, derivato da [statoEnum] se presente, altrimenti
  /// inferito dalla stringa [stato] tramite [AvvisoStato.fromRaw].
  AvvisoStato get statoTipo => statoEnum ?? AvvisoStato.fromRaw(stato);

  bool get hasOrdineCollegato =>
      ordineDiLavoro != null && ordineDiLavoro!.isNotEmpty;

  /// Sottotipo derivato dal campo [tipo] tramite il registry.
  AvvisoSubType get sottotipo => AvvisoSubType.fromCode(tipo);

  /// Categoria macro (Pronto Intervento / Richiesta Preventivo).
  AvvisoCategory get categoria => sottotipo.category;

  /// Vero se il flusso prevede il preventivo (firma + PDF + pagamento).
  bool get richiedePreventivo => categoria.hasPreventivoFlow;

  /// Vero se è chiuso (basato sull'enum tipizzato).
  bool get isChiuso => statoTipo.isClosed;

  /// Vero se priorità è "alta" o "critica".
  bool get isUrgente {
    final p = priorita.toLowerCase();
    return p.contains('alta') || p.contains('critic') || p.contains('urg') ||
        p.startsWith('3') || p.startsWith('4');
  }

  /// Telefono utile per la visualizzazione (preferenza: indirizzo, poi cliente).
  String? get telefonoUtile =>
      indirizzoAvvisoTelefono?.isNotEmpty == true
          ? indirizzoAvvisoTelefono
          : customer.telefono;
}
