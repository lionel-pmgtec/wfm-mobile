// Contatore (Misuratore) — specifiche §9.1 + M6.

class Meter {
  final String matricola; // numero di serie
  final String brand;
  final String model;
  final String caliber; // calibro
  final String materialCode;
  final DateTime? installDate;
  final String location; // "Mi" / ubicazione
  final String sector; // H1 (acqua fredda), H2 (acqua calda)...
  final num? lastReading;
  final DateTime? lastReadingDate;
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
    this.lastReading,
    this.lastReadingDate,
    this.sealNumber,
  });

  String get displayName =>
      [brand, model].where((e) => e.isNotEmpty).join(' ').trim();
}
