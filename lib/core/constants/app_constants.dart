// Costanti globali condivise (spaziature, durate, chiavi storage).

import 'package:flutter/widgets.dart';

/// Spaziatura di base (griglia 4pt).
const double kSpacingXs = 4;
const double kSpacingSm = 8;
const double kSpacingMd = 12;
const double kSpacingLg = 16;
const double kSpacingXl = 24;
const double kSpacingXxl = 32;

/// Raggio di arrotondamento standard.
const double kRadiusSm = 8;
const double kRadiusMd = 12;
const double kRadiusLg = 20;

/// Breakpoint tablet (cfr. layout responsive split-pane).
const double kTabletBreakpoint = 600;

/// Dimensione minima target tattile (raccomandazione Apple, specifiche §6.4).
/// Aumentata leggermente per i tablet usati in cantiere (guanti, pioggia).
const double kMinTouchTarget = 52;

/// Altezza standard dei pulsanti principali (Avvia, Pausa, Concludi…).
const double kPrimaryButtonHeight = 56;

/// Durata standard delle animazioni.
const Duration kAnimFast = Duration(milliseconds: 200);
const Duration kAnimMedium = Duration(milliseconds: 400);
const Duration kAnimSlow = Duration(milliseconds: 700);

/// Padding di pagina di default.
const EdgeInsets kPagePadding = EdgeInsets.all(kSpacingLg);

/// Chiavi di archiviazione sicura (flutter_secure_storage).
class SecureKeys {
  static const String sessionToken = 'wfm_session_token';
  static const String refreshToken = 'wfm_refresh_token';
  static const String currentUserCid = 'wfm_current_user_cid';
  static const String tokenExpiry = 'wfm_token_expiry';
  static const String hiveEncryptionKey = 'wfm_hive_key';
}

/// Nomi delle box Hive (cfr. specifiche §9.2).
class HiveBoxes {
  static const String workOrders = 'work_orders';
  static const String esiti = 'esiti';
  static const String attachments = 'attachments';
  static const String anagraficaMaterials = 'anagrafica_materials';
  static const String anagraficaWarehouses = 'anagrafica_warehouses';
  static const String anagraficaMeterBrands = 'anagrafica_meter_brands';
  static const String anagraficaTamCodes = 'anagrafica_tam_codes';
  static const String anagraficaUsers = 'anagrafica_users';
  static const String syncQueue = 'sync_queue';
  static const String settings = 'settings';
}
