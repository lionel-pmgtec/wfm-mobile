// Appuntamento / sopralluogo legato a un OdL (cfr. "Dati sopralluogo").
// Gestione: Nuovo appuntamento, Esito appuntamento, Riepilogo appuntamenti.

enum AppointmentOutcome {
  daEffettuare,
  effettuato,
  clienteAssente,
  rifiutato,
  rinviato;

  String get label => switch (this) {
        AppointmentOutcome.daEffettuare => 'Da effettuare',
        AppointmentOutcome.effettuato => 'Effettuato',
        AppointmentOutcome.clienteAssente => 'Cliente assente',
        AppointmentOutcome.rifiutato => 'Rifiutato',
        AppointmentOutcome.rinviato => 'Rinviato',
      };
}

class Appointment {
  final String id;
  final String workOrderCode;
  final DateTime date;
  final String startTime; // Ora
  final String endTime; // Ora limite
  final bool personalizzato; // appuntamento personalizzato (P)
  final bool consensoAnticipato; // consenso cliente all'esecuzione anticipata
  final bool inPresenza; // appuntamento in presenza
  final AppointmentOutcome outcome;
  final String note;

  const Appointment({
    required this.id,
    required this.workOrderCode,
    required this.date,
    this.startTime = '',
    this.endTime = '',
    this.personalizzato = false,
    this.consensoAnticipato = false,
    this.inPresenza = true,
    this.outcome = AppointmentOutcome.daEffettuare,
    this.note = '',
  });

  Appointment copyWith({
    DateTime? date,
    String? startTime,
    String? endTime,
    bool? personalizzato,
    bool? consensoAnticipato,
    bool? inPresenza,
    AppointmentOutcome? outcome,
    String? note,
  }) {
    return Appointment(
      id: id,
      workOrderCode: workOrderCode,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      personalizzato: personalizzato ?? this.personalizzato,
      consensoAnticipato: consensoAnticipato ?? this.consensoAnticipato,
      inPresenza: inPresenza ?? this.inPresenza,
      outcome: outcome ?? this.outcome,
      note: note ?? this.note,
    );
  }
}
