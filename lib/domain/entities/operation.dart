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
