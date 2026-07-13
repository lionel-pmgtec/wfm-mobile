enum AppFlavor { dev, qa, prod }

class AppConfig {
  final AppFlavor flavor;

  /// URL di base del MIDDLEWARE (REST/JSON). L'app non parla mai direttamente
  /// con SAP: il middleware traduce REST <-> SOAP .
  final String middlewareBaseUrl;

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
    required this.middlewareBaseUrl,
    this.sapClient = '100',
    this.sessionDuration = const Duration(hours: 8),
    this.connectTimeout = const Duration(seconds: 20),
    this.receiveTimeout = const Duration(seconds: 30),
    this.backgroundSyncInterval = const Duration(minutes: 15),
  });

  static const AppConfig dev = AppConfig(
    flavor: AppFlavor.dev,
    // Scegliere l'host in base al target di esecuzione:
    //   • Web / Desktop           -> http://localhost:8080/api/v1
    //   • Emulatore Android (AVD)  -> http://10.0.2.2:8080/api/v1
    //   • Dispositivo fisico Wi-Fi -> http://<IP-PC>:8080/api/v1
    // IP del PC su questa rete: 192.168.1.93 (Wi-Fi) / 192.168.1.71 (Ethernet).
    // Il telefono deve essere sulla STESSA Wi-Fi e la porta 8080 aperta nel firewall.
    middlewareBaseUrl: 'http://192.168.1.93:8080/api/v1',
  );

  static const AppConfig qa = AppConfig(
    flavor: AppFlavor.qa,
    middlewareBaseUrl: 'https://wfm-middleware.qa.local/api/v1',
  );

  static const AppConfig prod = AppConfig(
    flavor: AppFlavor.prod,
    middlewareBaseUrl: 'https://wfm-middleware.client.com/api/v1',
  );

  bool get isProd => flavor == AppFlavor.prod;
}

/// Config attivo dell'applicazione. Cambiabile in main_<flavor>.dart in futuro.
const AppConfig kAppConfig = AppConfig.dev;
