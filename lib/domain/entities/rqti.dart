// Dati RQTI + Determina 5 + Bilancio Idrico — per OdL di tipo intervento rete (ZA*).
// Riferimenti: CDC_Flutter "Sous-écran Dati RQTI" e "Determina 5 e Bilancio Idrico".

enum InterventionMode {
  programmato,
  emergenza,
  riparazione,
  manutenzione;

  String get label => switch (this) {
        InterventionMode.programmato => 'Programmato',
        InterventionMode.emergenza => 'Emergenza',
        InterventionMode.riparazione => 'Riparazione',
        InterventionMode.manutenzione => 'Manutenzione',
      };
}

/// Dati RQTI — Referenziale Qualità Tecnica Interruzioni
class RqtiData {
  final String workOrderCode;
  final InterventionMode? mode;
  final DateTime? interruptionStart;
  final DateTime? interruptionEnd;
  final int affectedUsers; // numero utenze disservite
  final String pressureLevel; // livello pressione (string per supportare "B/M/A")
  final String schemaSato; // ZORDI, ZSPEC...
  final String stato; // E0001 - Valido, etc.

  const RqtiData({
    required this.workOrderCode,
    this.mode,
    this.interruptionStart,
    this.interruptionEnd,
    this.affectedUsers = 0,
    this.pressureLevel = '',
    this.schemaSato = '',
    this.stato = '',
  });

  Duration? get interruptionDuration {
    if (interruptionStart == null || interruptionEnd == null) return null;
    return interruptionEnd!.difference(interruptionStart!);
  }

  RqtiData copyWith({
    InterventionMode? mode,
    DateTime? interruptionStart,
    DateTime? interruptionEnd,
    int? affectedUsers,
    String? pressureLevel,
    String? schemaSato,
    String? stato,
  }) {
    return RqtiData(
      workOrderCode: workOrderCode,
      mode: mode ?? this.mode,
      interruptionStart: interruptionStart ?? this.interruptionStart,
      interruptionEnd: interruptionEnd ?? this.interruptionEnd,
      affectedUsers: affectedUsers ?? this.affectedUsers,
      pressureLevel: pressureLevel ?? this.pressureLevel,
      schemaSato: schemaSato ?? this.schemaSato,
      stato: stato ?? this.stato,
    );
  }
}

/// Determina 5 + Bilancio Idrico — calcoli regolatori per perdite/riparazioni.
class Determina5Data {
  final String workOrderCode;
  final String interventoPuntuale;
  final String tipologiaIntervento;
  final String causaIntervento;
  final num volumePerditaPreRiparazione; // m³
  final num volumePerditaSuRiparazione; // m³
  final String confermaRifiuto; // C / R / -

  const Determina5Data({
    required this.workOrderCode,
    this.interventoPuntuale = '',
    this.tipologiaIntervento = '',
    this.causaIntervento = '',
    this.volumePerditaPreRiparazione = 0,
    this.volumePerditaSuRiparazione = 0,
    this.confermaRifiuto = '',
  });

  num get volumeRecuperato =>
      volumePerditaPreRiparazione - volumePerditaSuRiparazione;

  Determina5Data copyWith({
    String? interventoPuntuale,
    String? tipologiaIntervento,
    String? causaIntervento,
    num? volumePerditaPreRiparazione,
    num? volumePerditaSuRiparazione,
    String? confermaRifiuto,
  }) {
    return Determina5Data(
      workOrderCode: workOrderCode,
      interventoPuntuale: interventoPuntuale ?? this.interventoPuntuale,
      tipologiaIntervento: tipologiaIntervento ?? this.tipologiaIntervento,
      causaIntervento: causaIntervento ?? this.causaIntervento,
      volumePerditaPreRiparazione:
          volumePerditaPreRiparazione ?? this.volumePerditaPreRiparazione,
      volumePerditaSuRiparazione:
          volumePerditaSuRiparazione ?? this.volumePerditaSuRiparazione,
      confermaRifiuto: confermaRifiuto ?? this.confermaRifiuto,
    );
  }
}
