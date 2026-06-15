// Servizio notifiche locali (flutter_local_notifications).
// In produzione sostituire con FCM; in mock simula la ricezione con timer.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../domain/entities/app_notification.dart';

// ─── Canale Android ────────────────────────────────────────────────────────

const _kChannelId = 'wfm_channel';
const _kChannelName = 'WFM Notifiche';
const _kChannelDesc = 'Ordini di lavoro, avvisi e aggiornamenti WFM';

const _androidChannel = AndroidNotificationChannel(
  _kChannelId,
  _kChannelName,
  description: _kChannelDesc,
  importance: Importance.high,
  playSound: true,
  enableVibration: true,
);

const _androidDetails = AndroidNotificationDetails(
  _kChannelId,
  _kChannelName,
  channelDescription: _kChannelDesc,
  importance: Importance.high,
  priority: Priority.high,
  icon: '@mipmap/ic_launcher',
  color: Color(0xFF1565C0),
  enableLights: true,
  enableVibration: true,
  styleInformation: BigTextStyleInformation(''),
);

const _notifDetails = NotificationDetails(
  android: _androidDetails,
  iOS: DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  ),
);

// ─── Servizio ──────────────────────────────────────────────────────────────

class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  int _seq = 0;

  // Stream di payload al tocco (routePath JSON) → ascoltato da app.dart.
  final _tapController = StreamController<AppNotification?>.broadcast();
  Stream<AppNotification?> get onTap => _tapController.stream;

  // Callback aggiunto dal provider per inserire la notifica nello store.
  void Function(AppNotification)? onReceived;

  // ─── Inizializzazione ──────────────────────────────────────────────────

  Future<void> initialize() async {
    if (kIsWeb) return;

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false, // chiediamo esplicitamente dopo il login
        requestBadgePermission: true,
        requestSoundPermission: true,
      ),
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onTap,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundTap,
    );

    // Crea il canale Android (no-op su versioni < 8.0).
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);
  }

  // ─── Permessi (Android 13+ / iOS) ────────────────────────────────────

  Future<bool> requestPermission() async {
    if (kIsWeb) return false;

    // Android 13+
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }

    // iOS
    final ios = _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final granted = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    return true;
  }

  // ─── Mostra una notifica OS ───────────────────────────────────────────

  Future<void> show(AppNotification notification) async {
    if (kIsWeb) return;

    // Registra nello store in-app.
    onReceived?.call(notification);

    // Serializza payload per la navigazione al tocco.
    final payload = jsonEncode({
      'id': notification.id,
      'type': notification.type.name,
      'relatedId': notification.relatedId,
      'routePath': notification.routePath,
    });

    await _plugin.show(
      ++_seq,
      notification.title,
      notification.body,
      _notifDetails,
      payload: payload,
    );
  }

  // ─── Handler tocco notifica (foreground) ─────────────────────────────

  void _onTap(NotificationResponse response) {
    final raw = response.payload;
    if (raw == null) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final notif = AppNotification(
        id: map['id'] as String? ?? '',
        type: AppNotificationType.values.byName(
          map['type'] as String? ?? 'nuovoOdl',
        ),
        title: '',
        body: '',
        relatedId: map['relatedId'] as String?,
        routePath: map['routePath'] as String?,
        receivedAt: DateTime.now(),
        isRead: true,
      );
      _tapController.add(notif);
    } catch (_) {}
  }

  void dispose() {
    _tapController.close();
  }
}

// Handler statico per background (richiesto da flutter_local_notifications).
@pragma('vm:entry-point')
void _onBackgroundTap(NotificationResponse response) {
  // Non possiamo navigare qui senza il context; l'app gestirà al riavvio.
}
