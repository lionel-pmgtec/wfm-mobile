enum AppFlavor { dev, qa, prod }

class AppConfig {
  final AppFlavor flavor;

  /// URL base del middleware/API REST.
  /// Example: http://10.0.2.2:4000/api/v1
  final String middlewareBaseUrl;

  /// Alias compatibile con la vecchia configurazione.
  String get backendBaseUrl => middlewareBaseUrl;

  /// Base REST del tablet: `<middlewareBaseUrl>`.
  String get apiBaseUrl => middlewareBaseUrl;

  /// Base del realtime SSE: `<backendRoot>/api` (lo stream è `/api/stream`).
  String get streamBaseUrl {
    final base = middlewareBaseUrl.endsWith('/api/v1')
        ? middlewareBaseUrl.substring(
            0, middlewareBaseUrl.length - '/api/v1'.length)
        : middlewareBaseUrl;
    return '$base/api';
  }

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
    required this.middlewareBaseUrl,
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
    middlewareBaseUrl: String.fromEnvironment(
      'WFM_BASE_URL',
      defaultValue: 'http://10.0.2.2:4000/api/v1', // emulatore Android
    ),
  );

  // static const AppConfig qa = AppConfig(
  //   flavor: AppFlavor.qa,
  //   middlewareBaseUrl: 'https://wfm-cruscotto.qa.local',
  // );

  // static const AppConfig prod = AppConfig(
  //   flavor: AppFlavor.prod,
  //   middlewareBaseUrl: 'https://wfm-cruscotto.client.com',
  // );

  bool get isProd => flavor == AppFlavor.prod;
}

/// Config attivo dell'applicazione. Cambiabile in main_<flavor>.dart in futuro.
const AppConfig kAppConfig = AppConfig.dev;
