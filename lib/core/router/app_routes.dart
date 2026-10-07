// Costanti dei percorsi di navigazione (go_router).

class AppRoutes {
  static const String splash = '/splash';
  static const String login = '/login';
  static const String home = '/home';

  static const String workOrders = '/work-orders';
  // Lista OdL filtrata per stato (card cliccabili della Home). Path distinto da
  // /work-orders/:id per non collidere col dettaglio.
  static const String workOrdersByStatus = '/ordini-per-stato/:status';
  // Lista dei soli Pronto Intervento (urgenti).
  static const String prontoIntervento = '/pronto-intervento';
  static const String workOrderDetail = '/work-orders/:id';
  static const String esito = '/work-orders/:id/esito';
  static const String meter = '/work-orders/:id/meter';
  static const String appointments = '/work-orders/:id/appointments';
  // Sub-screens OdL
  static const String genOre = '/work-orders/:id/gen-ore';
  static const String copiaOrdine = '/work-orders/:id/copia';
  static const String cambioCid = '/work-orders/:id/cambio-cid';
  static const String addComponente = '/work-orders/:id/aggiungi-componente';
  static const String storicoAppuntamenti = '/work-orders/:id/storico-appuntamenti';
  static const String esitoAppuntamento = '/work-orders/:id/esito-appuntamento';
  static const String sospensioni = '/work-orders/:id/sospensioni';

  static const String avvisi = '/avvisi';
  static const String avvisoDetail = '/avvisi/:id';
  // Sub-screens Avvisi
  static const String generaOrdineDaAvviso = '/avvisi/:id/genera-ordine';

  // Preventivo — chiave generica: numero Avviso OPPURE codice OdL.
  // Rende il flusso preventivo raggiungibile sia dall'Avviso sia dall'OdL.
  static const String preventivo = '/preventivo/:key';
  static const String preventivoFirma = '/preventivo/:key/firma';
  static const String preventivoPdf = '/preventivo/:key/pdf';

  static const String createOrder = '/create-order';

  /// Crea un OdL di sostituzione a partire da un altro OdL (scenario 2):
  /// precompila tipo=SOST, contatore e OdL d'origine (tracciabilità).
  static String createOrderSostPath(String originCode, String matricola) =>
      '/create-order?type=SOST'
      '&origin=${Uri.encodeComponent(originCode)}'
      '&meter=${Uri.encodeComponent(matricola)}';
  /// Crea un OdL SOST a partire da un AVVISO: stesso modulo di creazione (matricola,
  /// tipo attività, priorità in codice…), precompilato con i dati dell'avviso.
  static String createOrderSostDaAvvisoPath(String numeroAvviso) =>
      createOrderDaAvvisoPath(numeroAvviso, 'SOST');

  /// Stesso modulo, per un tipo qualunque (es. ZA02 dall'avviso ZI).
  static String createOrderDaAvvisoPath(String numeroAvviso, String woType) =>
      '/create-order?type=${Uri.encodeComponent(woType)}'
      '&avviso=${Uri.encodeComponent(numeroAvviso)}';
  static const String createAvviso = '/create-avviso';

  /// OdL da un punto della mappa (contatore, punto della rete, punto scelto):
  /// tipo se noto, matricola se c'è, posizione, indirizzo del punto e ciclo
  /// da proporre.
  static String createOrderDaMappaPath(
          {String? woType,
          String? matricola,
          required double lat,
          required double lng,
          String? ciclo,
          IndirizzoMappa? indirizzo}) =>
      Uri(path: createOrder, queryParameters: {
        if ((woType ?? '').isNotEmpty) 'type': woType,
        if ((matricola ?? '').isNotEmpty) 'meter': matricola,
        'lat': '$lat',
        'lng': '$lng',
        if ((ciclo ?? '').isNotEmpty) 'ciclo': ciclo,
        ...?indirizzo?.query,
      }).toString();

  /// Avviso da un punto della mappa: matricola, posizione e indirizzo.
  static String createAvvisoDaMappaPath(
          {String? matricola,
          required double lat,
          required double lng,
          IndirizzoMappa? indirizzo}) =>
      Uri(path: createAvviso, queryParameters: {
        if ((matricola ?? '').isNotEmpty) 'meter': matricola,
        'lat': '$lat',
        'lng': '$lng',
        ...?indirizzo?.query,
      }).toString();
  static const String settings = '/settings';
  static const String notifications = '/notifications';
  static const String syncQueue = '/sync-queue';

  /// Centro di sincronizzazione: elenco degli oggetti creati sul campo.
  static const String syncCenter = '/sincronizzazione';

  // Modulo Standalone
  static const String standalone = '/standalone';
  static const String standaloneEquipment = '/standalone/equipment';
  static const String standaloneSostBarcode = '/standalone/sostituzione-barcode';
  static const String standaloneSquadra = '/standalone/squadra';
  static const String standaloneTemplates = '/standalone/templates';

  static const String map = '/map';
  static const String scanner = '/scanner';
  static const String signature = '/signature';

  /// Helper per costruire path con id.
  static String workOrderDetailPath(String id) => '/work-orders/$id';
  static String workOrdersByStatusPath(String status) => '/ordini-per-stato/$status';
  static String esitoPath(String id) => '/work-orders/$id/esito';
  static String meterPath(String id) => '/work-orders/$id/meter';
  static String appointmentsPath(String id) => '/work-orders/$id/appointments';
  static String genOrePath(String id) => '/work-orders/$id/gen-ore';
  static String copiaOrdinePath(String id) => '/work-orders/$id/copia';
  static String cambioCidPath(String id) => '/work-orders/$id/cambio-cid';
  static String addComponentePath(String id) => '/work-orders/$id/aggiungi-componente';
  static String storicoAppuntamentiPath(String id) => 'work-orders/$id/storico-appuntamenti';
  static String esitoAppuntamentoPath(String id) => '/work-orders/$id/esito-appuntamento';
  static String sospensioniPath(String id) => '/work-orders/$id/sospensioni';

  static String avvisoDetailPath(String id) => '/avvisi/$id';
  static String generaOrdineDaAvvisoPath(String id) => '/avvisi/$id/genera-ordine';

  /// [key] = numero Avviso o codice OdL a cui è collegato il preventivo.
  static String preventivoPath(String key) => '/preventivo/$key';
  static String preventivoFirmaPath(String key) => '/preventivo/$key/firma';
  static String preventivoPdfPath(String key) => '/preventivo/$key/pdf';
}

/// Indirizzo di un punto della mappa, passato ai moduli di creazione nei
/// parametri del percorso (via, civico, comune, CAP).
class IndirizzoMappa {
  final String via;
  final String civico;
  final String comune;
  final String cap;

  const IndirizzoMappa(
      {this.via = '', this.civico = '', this.comune = '', this.cap = ''});

  bool get isEmpty => via.isEmpty && comune.isEmpty;

  Map<String, String> get query => {
        if (via.isNotEmpty) 'via': via,
        if (civico.isNotEmpty) 'civico': civico,
        if (comune.isNotEmpty) 'comune': comune,
        if (cap.isNotEmpty) 'cap': cap,
      };

  /// Null se nei parametri non c'è né la via né il comune.
  static IndirizzoMappa? daQuery(Map<String, String> q) {
    final i = IndirizzoMappa(
      via: q['via']?.trim() ?? '',
      civico: q['civico']?.trim() ?? '',
      comune: q['comune']?.trim() ?? '',
      cap: q['cap']?.trim() ?? '',
    );
    return i.isEmpty ? null : i;
  }
}
