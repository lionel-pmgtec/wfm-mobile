import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/services/geolocation_service.dart';
import 'core/services/new_items_poll_service.dart';
import 'core/services/push_notification_service.dart';
import 'core/theme/app_theme.dart';
import 'presentation/providers/notifications_provider.dart';
import 'presentation/providers/core_providers.dart';
import 'presentation/providers/settings_provider.dart';
import 'presentation/providers/sync_provider.dart';

class WfmApp extends ConsumerStatefulWidget {
  const WfmApp({super.key});

  @override
  ConsumerState<WfmApp> createState() => _WfmAppState();
}

class _WfmAppState extends ConsumerState<WfmApp> {
  StreamSubscription? _tapSub;

  @override
  void initState() {
    super.initState();

    // Inizializza il notifier per registrare onReceived sul servizio push.
    ref.read(notificationsProvider.notifier);

    ref.read(newItemsPollServiceProvider);

    // Attiva il processore della coda offline: al ritorno della connettività
    // reinvia automaticamente le operazioni accodate mentre si era offline.
    ref.read(syncProcessorProvider);

    // Ascolta i tap sulle notifiche OS → naviga al percorso corretto.
    _tapSub = PushNotificationService.instance.onTap.listen((notif) {
      if (notif?.routePath != null && mounted) {
        ref.read(goRouterProvider).push(notif!.routePath!);
        ref.read(notificationsProvider.notifier).markRead(notif.id);
      }
    });
  }

  @override
  void dispose() {
    _tapSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(goRouterProvider);
    final settings = ref.watch(settingsProvider);

    return MaterialApp.router(
      title: 'SAP Work Manager — WFM Mobile',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(iconScale: settings.iconScale),
      darkTheme: buildAppTheme(iconScale: settings.iconScale),
      themeMode: settings.themeMode,
      routerConfig: router,
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: TextScaler.linear(settings.textScale),
          ),
          child: _BackendStatusNotifier(
            child: _PermissionRequestWrapper(child: child!),
          ),
        );
      },
    );
  }
}

class _BackendStatusNotifier extends ConsumerStatefulWidget {
  final Widget child;
  const _BackendStatusNotifier({required this.child});

  @override
  ConsumerState<_BackendStatusNotifier> createState() =>
      _BackendStatusNotifierState();
}

class _BackendStatusNotifierState
    extends ConsumerState<_BackendStatusNotifier> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final status = ref.read(backendStatusProvider);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(status),
        backgroundColor: status.contains('HTTP 200 OK')
            ? Colors.green.shade700
            : Colors.red.shade700,
        duration: const Duration(seconds: 5),
      ));
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// ─── Wrapper che richiede i permessi push al primo avvio ─────────────────

class _PermissionRequestWrapper extends StatefulWidget {
  final Widget child;
  const _PermissionRequestWrapper({required this.child});

  @override
  State<_PermissionRequestWrapper> createState() =>
      _PermissionRequestWrapperState();
}

class _PermissionRequestWrapperState extends State<_PermissionRequestWrapper> {
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
