// Value object di dominio condivisi.

/// Geolocalizzazione di un evento (foto, avvio/stop OdL) — specifiche §9.1.
class Geolocation {
  final double latitude;
  final double longitude;
  final double accuracy; // metri
  final DateTime capturedAt;

  const Geolocation({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.capturedAt,
  });
}

/// Indirizzo dell'intervento (cliccabile → mappa).
class Address {
  // Civico
  final String street;
  final String streetNumber;
  // Località
  final String cap; // codice avviamento postale
  final String localita; // frazione / località (ex additionalInfo)
  final String city; // comune
  final String provincia; // sigla provincia (es. AN)
  final String regione;
  final String nazione;
  // GPS
  final double? latitude;
  final double? longitude;
  // Legacy: campo libero per compatibilità con dati esistenti
  final String additionalInfo;

  const Address({
    this.street = '',
    this.streetNumber = '',
    this.cap = '',
    this.localita = '',
    this.city = '',
    this.provincia = '',
    this.regione = '',
    this.nazione = 'IT',
    this.latitude,
    this.longitude,
    this.additionalInfo = '',
  });

  /// Riga completa leggibile (1 sola riga compact).
  String get full {
    final viaCivico = [street, streetNumber]
        .where((e) => e.isNotEmpty)
        .join(' ');
    final cityWithCap = [
      if (cap.isNotEmpty) cap,
      city,
      if (provincia.isNotEmpty) '($provincia)',
    ].where((e) => e.isNotEmpty).join(' ');
    final parts = [
      if (viaCivico.isNotEmpty) viaCivico,
      if (cityWithCap.isNotEmpty) cityWithCap,
      if (localita.isNotEmpty) localita,
      if (additionalInfo.isNotEmpty) additionalInfo,
    ].toList();
    return parts.join(', ');
  }

  /// Riga breve per la lista (città + via).
  String get short {
    final s = [city, street].where((e) => e.isNotEmpty).join(' · ');
    return s.isEmpty ? '—' : s;
  }

  bool get hasCoordinates => latitude != null && longitude != null;

  String get gpsCoordinates {
    if (!hasCoordinates) return '';
    return '${latitude!.toStringAsFixed(6)}, ${longitude!.toStringAsFixed(6)}';
  }
}

/// Cliente / punto di utilizzo.
class Customer {
  final String? objectCode;
  final String? nome;
  final String? cognome;
  final String? ragioneSociale; // per clienti business
  final String? codiceFiscale;
  final String? partitaIva;
  final String? telefono;
  final String? email;
  final String? codBp;
  final String? codCli;
  final int? familyNucleus;

  const Customer({
    this.objectCode,
    this.nome,
    this.cognome,
    this.ragioneSociale,
    this.codiceFiscale,
    this.partitaIva,
    this.telefono,
    this.email,
    this.codBp,
    this.codCli,
    this.familyNucleus,
  });

  /// Nome completo: ragione sociale per business, nome+cognome per privati.
  String get fullName {
    if (ragioneSociale != null && ragioneSociale!.isNotEmpty) {
      return ragioneSociale!;
    }
    return [nome, cognome]
        .whereType<String>()
        .where((e) => e.isNotEmpty)
        .join(' ');
  }

  bool get isBusiness =>
      ragioneSociale != null && ragioneSociale!.isNotEmpty;

  bool get isEmpty =>
      (nome == null || nome!.isEmpty) &&
      (cognome == null || cognome!.isEmpty) &&
      (ragioneSociale == null || ragioneSociale!.isEmpty) &&
      (telefono == null || telefono!.isEmpty);
}
