// Firebase Cloud Messaging.
// Inizializza Firebase, gestisce il token FCM e lo registra sul middleware
// (Cruscotto). Bridga i messaggi in arrivo verso PushNotificationService per
// mostrarli all'utente con flutter_local_notifications.

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../domain/entities/app_notification.dart';
import 'push_notification_service.dart';

/// Handler top-level richiesto da firebase_messaging per i messaggi background.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // L'isolato di background non condivide stato col processo principale.
  // Qui ci limitiamo a inizializzare Firebase; la UI sarà aggiornata al
  // prossimo foreground tramite il listener su onMessageOpenedApp.
  await Firebase.initializeApp();
}

class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  bool _initialized = false;
  String? _token;
  String? get token => _token;

  /// Callback iniettato dall'app per inviare il token al middleware.
  Future<void> Function(String token)? onTokenAvailable;

  /// Inizializza Firebase + FirebaseMessaging. Da chiamare prima di runApp().
  Future<void> initialize() async {
    if (kIsWeb || _initialized) return;
    _initialized = true;

    try {
      await Firebase.initializeApp();
    } catch (e) {
      // google-services.json mancante in dev → mock mode, skip senza crash.
      if (kDebugMode) {
        // ignore: avoid_print
        print('[fcm] Firebase non inizializzato: $e');
      }
      _initialized = false;
      return;
    }

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Messaggio ricevuto a app in foreground → mostra notifica locale.
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // Listener cambio token (refresh periodico Firebase).
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      _token = newToken;
      onTokenAvailable?.call(newToken);
    });
  }

  /// Richiede i permessi push e ottiene il token FCM.
  /// Restituisce il token (o null se permessi negati / Firebase non inizializzato).
  Future<String?> requestPermissionAndToken() async {
    if (kIsWeb || !_initialized) return null;

    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return null;
    }

    try {
      _token = await FirebaseMessaging.instance.getToken();
      if (_token != null) {
        onTokenAvailable?.call(_token!);
      }
      return _token;
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[fcm] getToken error: $e');
      }
      return null;
    }
  }

  /// Elimina il token (chiamato al logout, opzionale).
  Future<void> deleteToken() async {
    if (!_initialized) return;
    try {
      await FirebaseMessaging.instance.deleteToken();
      _token = null;
    } catch (_) {}
  }

  void _onForegroundMessage(RemoteMessage message) {
    final notif = _toAppNotification(message);
    if (notif == null) return;
    PushNotificationService.instance.show(notif);
  }

  AppNotification? _toAppNotification(RemoteMessage message) {
    final n = message.notification;
    final data = message.data;
    final title = n?.title ?? data['title']?.toString();
    final body = n?.body ?? data['body']?.toString();
    if (title == null && body == null) return null;

    return AppNotification(
      id: message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      type: _parseType(data['type']?.toString()),
      title: title ?? 'Notifica',
      body: body ?? '',
      relatedId: data['relatedId']?.toString(),
      routePath: data['routePath']?.toString(),
      receivedAt: DateTime.now(),
    );
  }

  AppNotificationType _parseType(String? raw) {
    if (raw == null) return AppNotificationType.nuovoOdl;
    try {
      return AppNotificationType.values.byName(raw);
    } catch (_) {
      return AppNotificationType.nuovoOdl;
    }
  }
}
