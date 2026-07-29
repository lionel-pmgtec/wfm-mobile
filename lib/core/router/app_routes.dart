// Costanti dei percorsi di navigazione (go_router).

class AppRoutes {
  static const String login = '/login';
  static const String home = '/home';

  static const String workOrders = '/work-orders';
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
  static const String settings = '/settings';
  static const String notifications = '/notifications';
  static const String syncQueue = '/sync-queue';

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
