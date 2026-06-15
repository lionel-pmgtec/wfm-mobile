// Sospensione di OdL/Avviso — sospensioni dettagliate.
// Una sospensione è un periodo durante il quale l'attività è temporaneamente bloccata
// (es. cliente assente, materiale mancante, accesso impossibile, fine turno).

enum SuspensionType {
  lavoro, // L — Sospensione lavoro
  cliente, // CL — Cliente assente
  materiale, // MAT — Materiale mancante
  accesso, // ACC — Accesso impossibilitato
  meteo, // MT — Condizioni meteo
  fineTurno, // FT — Fine turno
  pausa, // PS — In pausa
  test, // TEST — In test
  nonAutorizzato, // NA — Non autorizzato
  altro; // ALT — Altro

  String get label => switch (this) {
        SuspensionType.lavoro => 'L — Sospensione lavoro',
        SuspensionType.cliente => 'CL — Cliente assente',
        SuspensionType.materiale => 'MAT — Materiale mancante',
        SuspensionType.accesso => 'ACC — Accesso impossibilitato',
        SuspensionType.meteo => 'MT — Condizioni meteo',
        SuspensionType.fineTurno => 'FT — Fine turno',
        SuspensionType.pausa => 'PS — In pausa',
        SuspensionType.test => 'TEST — In test',
        SuspensionType.nonAutorizzato => 'NA — Non autorizzato',
        SuspensionType.altro => 'ALT — Altro',
      };

  String get sapCode => switch (this) {
        SuspensionType.lavoro => 'L',
        SuspensionType.cliente => 'CL',
        SuspensionType.materiale => 'MAT',
        SuspensionType.accesso => 'ACC',
        SuspensionType.meteo => 'MT',
        SuspensionType.fineTurno => 'FT',
        SuspensionType.pausa => 'PS',
        SuspensionType.test => 'TEST',
        SuspensionType.nonAutorizzato => 'NA',
        SuspensionType.altro => 'ALT',
      };
}

class Suspension {
  final String id;
  final String parentCode; // workOrderCode o avvisoNumero
  final SuspensionType type;
  final String cause; // causa libera
  final String note;
  final DateTime startDateTime;
  final DateTime? endDateTime; // null = ancora attiva
  final String authorCid;

  const Suspension({
    required this.id,
    required this.parentCode,
    required this.type,
    this.cause = '',
    this.note = '',
    required this.startDateTime,
    this.endDateTime,
    this.authorCid = '',
  });

  bool get isActive => endDateTime == null;

  Duration get duration =>
      (endDateTime ?? DateTime.now()).difference(startDateTime);

  Suspension copyWith({DateTime? endDateTime, String? note}) {
    return Suspension(
      id: id,
      parentCode: parentCode,
      type: type,
      cause: cause,
      note: note ?? this.note,
      startDateTime: startDateTime,
      endDateTime: endDateTime ?? this.endDateTime,
      authorCid: authorCid,
    );
  }
}
