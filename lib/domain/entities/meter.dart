// Contatore (Misuratore).

class Meter {
  final String matricola; // numero di serie
  final String brand;
  final String model;
  final String caliber; // calibro
  final String materialCode;
  final DateTime? installDate;
  final String location; // sede tecnica (SEDE_TECNICA)
  final String sector; // H1 (acqua fredda), H2 (acqua calda)...
  // Ubicazione fisica del misuratore (ora esposta da SAP).
  final String ubicazione; // codice ubicazione (es. A0144)
  final String ubicazioneDesc; // definizione ubicazione (UBICAZIONE_AGG)
  final String posizioneInBatteria; // posizione in batteria
  final String oggettoAllacciamento; // punto di connessione
  final num? lastReading;
  final DateTime? lastReadingDate;
  // Lettura PRECEDENTE dallo storico contatore (SAP PREC_VALORE/PREC_DATA…).
  final num? previousReading;
  final DateTime? previousReadingDate;
  final String? previousReadingTime;
  final String? previousReadingStatus;
  final String? sealNumber; // numero sigillo

  const Meter({
    required this.matricola,
    this.brand = '',
    this.model = '',
    this.caliber = '',
    this.materialCode = '',
    this.installDate,
    this.location = '',
    this.sector = '',
    this.ubicazione = '',
    this.ubicazioneDesc = '',
    this.posizioneInBatteria = '',
    this.oggettoAllacciamento = '',
    this.lastReading,
    this.lastReadingDate,
    this.previousReading,
    this.previousReadingDate,
    this.previousReadingTime,
    this.previousReadingStatus,
    this.sealNumber,
  });

  String get displayName =>
      [brand, model].where((e) => e.isNotEmpty).join(' ').trim();
}
