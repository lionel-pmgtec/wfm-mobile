import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/config/backend_discovery.dart';
import 'core/services/background_sync_service.dart';
import 'core/services/fcm_service.dart';
import 'core/services/arrival_store.dart';
import 'core/services/avvisi_rimossi_store.dart';
import 'core/services/odl_rimossi_store.dart';
import 'core/services/impostazioni_store.dart';
import 'core/services/push_notification_service.dart';
import 'core/services/stock_impegnato_store.dart';
import 'data/datasources/local/local_data_source.dart';
import 'presentation/providers/appointments_provider.dart';
import 'presentation/providers/core_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final backend = await discoverBackend();
  final appConfig = backend.baseUrl == null
      ? AppConfig.dev
      : AppConfig.dev.withMiddlewareBaseUrl(backend.baseUrl!);
  final backendStatus = backend.baseUrl == null
      ? 'Backend non raggiungibile: verifica la rete e assets/backend_servers.json'
      : 'Backend ${backend.baseUrl} — HTTP ${backend.statusCode} OK';

  // Localizzazione date (it_IT) usata da intl/Fmt.
  await initializeDateFormatting('it_IT', null);

  // Inizializza il servizio di notifiche push locali.
  await PushNotificationService.instance.initialize();

  // Inizializza Firebase Cloud Messaging (no-op se google-services.json mancante).
  await FcmService.instance.initialize();

  // Sincronizzazione periodica in background (ogni 15 minuti).
  await BackgroundSyncService.instance.initialize();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarContrastEnforced: false,
  ));

  // Dati locali persistenti: allegati in attesa, bozze esito e coda di sync
  // sopravvivono al riavvio e partono appena c'è connessione.
  final localData = await PersistentLocalDataSource.open();
  await EsitoAppuntamentoStore.open();
  await ArrivalStore.open();
  await ImpostazioniStore.open();
  await AvvisiRimossiStore.open();
  await OdlRimossiStore.open();
  await StockImpegnatoStore.open();

  // ProviderScope: radice dell'iniezione delle dipendenze (Riverpod).
  runApp(ProviderScope(
    overrides: [
      localDataSourceProvider.overrideWithValue(localData),
      appConfigProvider.overrideWithValue(appConfig),
      backendStatusProvider.overrideWithValue(backendStatus),
    ],
    child: const WfmApp(),
  ));
}
