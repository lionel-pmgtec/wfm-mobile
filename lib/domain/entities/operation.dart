// Operazione (scheda Operazioni di un OdL) — spec aziendale.
//
// Una operazione e una riga della tabella operazioni che il tecnico
// compila durante l'esecuzione dell'OdL. Piu righe possono condividere
// lo stesso CID (operatore).

class Operation {
  final String id; // identificatore univoco riga
  final String number; // Op. — numero operazione (0010, 0020, ...)
  final String codice; // codice operazione SAP
  final String testoBreve; // testo breve (intestazione riga)
  final String cid; // CID operatore assegnato
  final String description; // descrizione estesa
  final String workCenter; // centro di lavoro
  final String? longText;
  final bool completed;
  // Date cardine (pianificate)
  final DateTime? dataInizioPrevista;
  final DateTime? dataFinePrevista;
  // Tempi
  final num? plannedHours; // ore pianificate
  final num? durataEffettiva; // durata effettiva (inserimento libero, ore)
  final num? actualHours; // alias legacy = durataEffettiva
  final String? tempoLavoroFase; // descrizione tempo lavoro per fase

  const Operation({
    this.id = '',
    required this.number,
    required this.description,
    this.codice = '',
    this.testoBreve = '',
    this.cid = '',
    this.workCenter = '',
    this.longText,
    this.completed = false,
    this.dataInizioPrevista,
    this.dataFinePrevista,
    this.plannedHours,
    this.durataEffettiva,
    this.actualHours,
    this.tempoLavoroFase,
  });

  /// Restituisce la durata effettiva (preferisce [durataEffettiva], fallback
  /// su [actualHours] per retro-compatibilita).
  num? get effectiveHours => durataEffettiva ?? actualHours;

  Operation copyWith({
    String? id,
    String? number,
    String? codice,
    String? testoBreve,
    String? cid,
    String? description,
    String? workCenter,
    String? longText,
    bool? completed,
    DateTime? dataInizioPrevista,
    DateTime? dataFinePrevista,
    num? plannedHours,
    num? durataEffettiva,
    num? actualHours,
    String? tempoLavoroFase,
  }) =>
      Operation(
        id: id ?? this.id,
        number: number ?? this.number,
        codice: codice ?? this.codice,
        testoBreve: testoBreve ?? this.testoBreve,
        cid: cid ?? this.cid,
        description: description ?? this.description,
        workCenter: workCenter ?? this.workCenter,
        longText: longText ?? this.longText,
        completed: completed ?? this.completed,
        dataInizioPrevista: dataInizioPrevista ?? this.dataInizioPrevista,
        dataFinePrevista: dataFinePrevista ?? this.dataFinePrevista,
        plannedHours: plannedHours ?? this.plannedHours,
        durataEffettiva: durataEffettiva ?? this.durataEffettiva,
        actualHours: actualHours ?? this.actualHours,
        tempoLavoroFase: tempoLavoroFase ?? this.tempoLavoroFase,
      );
}

/// Le tre operazioni standard di ogni OdL, qualunque sia il tipo: 0010
/// Trasferimento, 0040 Lavori Idraulici, 0200 Automezzi.
///
/// Sono quelle del backend (`OPERAZIONI_SOST` in dominio/tipiOrdine.ts: "sempre
/// queste, qualunque sia il tipo attività"), che a sua volta le ricava dagli
/// ordini SAP; il backend le dà all'ordine solo se è una SOST creata dal
/// tablet, quindi un ZA02 creato dal tablet arriva senza. Il tablet le propone
/// SOLO quando l'ordine non ne ha: le operazioni mandate dal backend (cicli
/// SAP) hanno sempre la precedenza. Forma identica a quella del backend
/// (toOperation: id = numero, codice = chiave di controllo).
const List<Operation> kOperazioniStandard = [
  Operation(
      id: '0010',
      number: '0010',
      codice: 'PM01',
      testoBreve: 'Trasferimento',
      description: 'Trasferimento'),
  Operation(
      id: '0040',
      number: '0040',
      codice: 'ZM01',
      testoBreve: 'Lavori Idraulici',
      description: 'Lavori Idraulici'),
  Operation(
      id: '0200',
      number: '0200',
      codice: 'PM01',
      testoBreve: 'Automezzi',
      description: 'Automezzi'),
];
