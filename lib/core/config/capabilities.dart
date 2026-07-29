
class Cap {
  Cap._();

  // ODL
  static const odlDatiOrdine = 'odl.datiOrdine';
  static const odlDatiTecnici = 'odl.datiTecnici';
  static const odlOperazioni = 'odl.operazioni';
  static const odlPianificazione = 'odl.pianificazione';
  static const odlCliente = 'odl.cliente';
  static const odlIndirizzi = 'odl.indirizzi';
  static const odlAppuntamento = 'odl.appuntamento';
  static const odlContatore = 'odl.contatore';
  static const odlMateriali = 'odl.materiali';
  static const odlRisorse = 'odl.risorse';
  static const odlAmpliamento = 'odl.ampliamento';
  static const odlNote = 'odl.note';
  static const odlAllegati = 'odl.allegati';

  // Avvisi
  static const avvisoDatiAvviso = 'avviso.datiAvviso';
  static const avvisoDatiTecnici = 'avviso.datiTecnici';
  static const avvisoCliente = 'avviso.cliente';
  static const avvisoIndirizzi = 'avviso.indirizzi';
  static const avvisoGestioneIntervento = 'avviso.gestioneIntervento';
  static const avvisoAllegati = 'avviso.allegati';
  static const avvisoPreventivo = 'avviso.preventivo';

  /// Scrittura verso SAP. Non ancora attivo: ZWFMT_SERVIZIO_PM è di sola lettura e
  /// non esiste nessun servizio di scrittura.
  static const writeSap = 'write.sap';
}

/// Sorgente dati dichiarata dal middleware.
enum CapabilityMode { sap, excel }

class Capabilities {
  final CapabilityMode mode;

  /// Nome della sorgente, per i messaggi mostrati al tecnico
  /// (es. `ZWFMT_SERVIZIO_PM`).
  final String source;

  final Map<String, bool> _fields;

  const Capabilities({
    required this.mode,
    required this.source,
    required Map<String, bool> fields,
  }) : _fields = fields;

  /// Fallback: tutto disponibile.
  ///
  /// È lo stato usato finché la risposta del middleware non arriva, e quello a
  /// cui si ricade se `/capabilities` non risponde. Continua così a funzionare come prima invece
  /// di far sparire mezza interfaccia.
  static const Capabilities allEnabled = Capabilities(
    mode: CapabilityMode.excel,
    source: 'middleware',
    fields: <String, bool>{},
  );

  /// Una capability sconosciuta vale `true`: se il middleware non si esprime su
  /// una sezione, la si mostra. Meglio un campo vuoto che una sezione sparita
  /// per un refuso nella chiave.
  bool has(String key) => _fields[key] ?? true;

  bool get isSapMode => mode == CapabilityMode.sap;

  /// Messaggio mostrato accanto a un campo o a una sezione non alimentata.
  String get unavailableReason => 'Dati non disponibile';

  factory Capabilities.fromJson(Map<String, dynamic> json) {
    final raw = json['fields'];
    final fields = <String, bool>{};
    if (raw is Map) {
      raw.forEach((k, v) {
        if (v is bool) fields['$k'] = v;
      });
    }
    return Capabilities(
      mode: '${json['mode']}'.toLowerCase() == 'sap'
          ? CapabilityMode.sap
          : CapabilityMode.excel,
      source: (json['source'] ?? 'middleware').toString(),
      fields: fields,
    );
  }
}
