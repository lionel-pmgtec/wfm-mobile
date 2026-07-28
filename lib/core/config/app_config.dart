enum AppFlavor { dev, qa, prod }

class AppConfig {
  final AppFlavor flavor;

  /// Il backend ha due percorsi: uno per i dati e uno per il realtime.
  /// I percorsi qui sotto sono dello stesso server, cambia solo la base:
  ///   • `/api/v1` → dati, scritture, auth, esiti, anagrafiche (contratto tablet)
  ///   • `/api`    → realtime SSE (`GET /api/stream`), fuori da `/api/v1`
  final String backendBaseUrl;

  /// Base REST del tablet: `<backend>/api/v1`.
  String get apiBaseUrl => '$backendBaseUrl/api/v1';

  /// Base del realtime SSE: `<backend>/api` (lo stream è `/api/stream`).
  String get streamBaseUrl => '$backendBaseUrl/api';

  /// sap-client trasmesso negli header verso il backend.
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
    required this.backendBaseUrl,
    this.sapClient = '100',
    this.sessionDuration = const Duration(hours: 8),
    this.connectTimeout = const Duration(seconds: 20),
    this.receiveTimeout = const Duration(seconds: 30),
    this.backgroundSyncInterval = const Duration(minutes: 15),
  });


  // Host per target di esecuzione:
  //   • Web / Desktop (stesso PC) -> localhost
  //   • Emulatore Android (AVD)   -> 10.0.2.2
  //   • Tablet fisico Wi-Fi       -> IP del PC (DHCP: cambia! `ipconfig`, porta 4000 nel firewall)
  static const AppConfig dev = AppConfig(
    flavor: AppFlavor.dev,
    // Tablet : per usare il tablet fisico, bisogna configurare lindirizzo IP del PC fisico sulla Wi-Fi, e non usare localhost.
    // Il tablet deve essere connesso alla stessa rete Wi-Fi del PC, e il firewall del PC deve permettere le connessioni in ingresso sulla porta 4000. 
    // Web/Desktop sullo stesso PC -> 'http://localhost:4000'.
    backendBaseUrl: 'http://192.168.1.93:4000',
  );

  static const AppConfig qa = AppConfig(
    flavor: AppFlavor.qa,
    backendBaseUrl: 'https://wfm-cruscotto.qa.local',
  );

  static const AppConfig prod = AppConfig(
    flavor: AppFlavor.prod,
    backendBaseUrl: 'https://wfm-cruscotto.client.com',
  );

  bool get isProd => flavor == AppFlavor.prod;
}

/// Config attivo dell'applicazione. Cambiabile in main_<flavor>.dart in futuro.
const AppConfig kAppConfig = AppConfig.dev;
