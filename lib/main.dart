import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/services/background_sync_service.dart';
import 'core/services/fcm_service.dart';
import 'core/services/push_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  // ProviderScope: radice dell'iniezione delle dipendenze (Riverpod).
  runApp(const ProviderScope(child: WfmApp()));
}
