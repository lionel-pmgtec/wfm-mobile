import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/services/geolocation_service.dart';
import 'core/services/push_notification_service.dart';
import 'core/theme/app_theme.dart';
import 'presentation/providers/core_providers.dart';
import 'presentation/providers/notifications_provider.dart';
import 'presentation/providers/settings_provider.dart';

class WfmApp extends ConsumerStatefulWidget {
  const WfmApp({super.key});

  @override
  ConsumerState<WfmApp> createState() => _WfmAppState();
}

class _WfmAppState extends ConsumerState<WfmApp> {
  StreamSubscription? _tapSub;
  bool _simulatorStarted = false;

  @override
  void initState() {
    super.initState();

    // Inizializza il notifier per registrare onReceived sul servizio push.
    ref.read(notificationsProvider.notifier);

    // Ascolta i tap sulle notifiche OS → naviga al percorso corretto.
    _tapSub = PushNotificationService.instance.onTap.listen((notif) {
      if (notif?.routePath != null && mounted) {
        ref.read(goRouterProvider).push(notif!.routePath!);
        ref.read(notificationsProvider.notifier).markRead(notif.id);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Avvia il simulatore mock solo una volta e solo in modalità mock.
    if (!_simulatorStarted) {
      _simulatorStarted = true;
      final config = ref.read(appConfigProvider);
      if (config.useMockData) {
        MockNotificationSimulator.start();
      }
    }
  }

  @override
  void dispose() {
    _tapSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(goRouterProvider);
    final themeMode = ref.watch(settingsProvider).themeMode;

    return MaterialApp.router(
      title: 'SAP Work Manager — WFM Mobile',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      darkTheme: buildAppTheme(),
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) =>
          _PermissionRequestWrapper(child: child!),
    );
  }
}

// ─── Wrapper che richiede i permessi push al primo avvio ─────────────────

class _PermissionRequestWrapper extends StatefulWidget {
  final Widget child;
  const _PermissionRequestWrapper({required this.child});

  @override
  State<_PermissionRequestWrapper> createState() =>
      _PermissionRequestWrapperState();
}

class _PermissionRequestWrapperState
    extends State<_PermissionRequestWrapper> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PushNotificationService.instance.requestPermission();
      // Richiesta non bloccante: serve a Play/Stop OdL, foto geotag, mappa.
      GeolocationService.instance.ensurePermission();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
