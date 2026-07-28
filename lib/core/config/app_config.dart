enum AppFlavor { dev, qa, prod }

class AppConfig {
  final AppFlavor flavor;

  /// URL di base del BACKEND DEL COLLEGA (cruscotto, Node) — usato per tutte le
  /// LETTURE (liste/dettaglio ODL e avvisi) e il realtime SSE. È il backend
  /// principale: SAP spinge i dati qui, l'app li legge in `/api/*`.
  final String cruscottoBaseUrl;

  /// sap-client trasmesso negli header verso il middleware.
  final String sapClient;

  /// Durata validità del token di sessione .
  final Duration sessionDuration;

  /// Timeout di rete.
  final Duration connectTimeout;
  final Duration receiveTimeout;

  /// Frequenza di sincronizzazione in background.
  final Duration backgroundSyncInterval;

  const AppConfig({
    required this.flavor,
    required this.cruscottoBaseUrl,
    this.sapClient = '100',
    this.sessionDuration = const Duration(hours: 8),
    this.connectTimeout = const Duration(seconds: 20),
    this.receiveTimeout = const Duration(seconds: 30),
    this.backgroundSyncInterval = const Duration(minutes: 15),
  });

  static const AppConfig dev = AppConfig(
    flavor: AppFlavor.dev,
    // Scegliere l'host in base al target di esecuzione:
    //   • Web / Desktop            -> http://localhost:8080/api/v1
    //   • Emulatore Android (AVD)  -> http://10.0.2.2:8080/api/v1
    //   • Dispositivo fisico Wi-Fi -> http://<IP-PC>:8080/api/v1
    //
    // ATTENZIONE: l'IP del PC è assegnato in DHCP e CAMBIA. Quando l'app dice
    // "Il server non risponde" mentre il middleware è avviato, è quasi sempre
    // questo: ricontrollare con `ipconfig` e aggiornare la riga qui sotto.
    // (Wi-Fi del PC il 2026-07-17: 192.168.1.8 — prima era 192.168.1.93.)
    //
    // Il telefono deve essere sulla STESSA Wi-Fi e la porta 8080 aperta nel firewall
    //middlewareBaseUrl: 'http://localhost:8080/api/v1',
    // Backend del collega (letture + SSE). Stesso host, porta 4000, base /api.
    // Aggiornare l'IP insieme a middlewareBaseUrl quando cambia (DHCP).
    cruscottoBaseUrl: 'http://192.168.1.93:4000/api',
  );

  static const AppConfig qa = AppConfig(
    flavor: AppFlavor.qa,
    cruscottoBaseUrl: 'https://wfm-cruscotto.qa.local/api',
  );

  static const AppConfig prod = AppConfig(
    flavor: AppFlavor.prod,
    cruscottoBaseUrl: 'https://wfm-cruscotto.client.com/api',
  );

  bool get isProd => flavor == AppFlavor.prod;
}

/// Config attivo dell'applicazione. Cambiabile in main_<flavor>.dart in futuro.
const AppConfig kAppConfig = AppConfig.dev;
