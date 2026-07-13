import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Impostazioni locali (M14). In memoria per l'MVP; TODO: persistere su Hive.
class AppSettings {
  final ThemeMode themeMode;
  final int syncIntervalMinutes; // 5/15/30/60
  final String photoQuality; // alta/media/bassa
  final String language; // it
  final double textScale; // fattore di scala del testo dell'intera app
  final double iconScale; // fattore di scala delle icone dell'intera app

  /// Limiti e passo dei fattori di scala (testo e icone).
  static const double minScale = 0.8;
  static const double maxScale = 1.6;
  static const double scaleStep = 0.1;

  const AppSettings({
    this.themeMode = ThemeMode.light,
    this.syncIntervalMinutes = 15,
    this.photoQuality = 'media',
    this.language = 'it',
    this.textScale = 1.0,
    this.iconScale = 1.0,
  });

  AppSettings copyWith({
    ThemeMode? themeMode,
    int? syncIntervalMinutes,
    String? photoQuality,
    String? language,
    double? textScale,
    double? iconScale,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      syncIntervalMinutes: syncIntervalMinutes ?? this.syncIntervalMinutes,
      photoQuality: photoQuality ?? this.photoQuality,
      language: language ?? this.language,
      textScale: textScale ?? this.textScale,
      iconScale: iconScale ?? this.iconScale,
    );
  }
}

class SettingsController extends StateNotifier<AppSettings> {
  SettingsController() : super(const AppSettings());

  void setThemeMode(ThemeMode mode) => state = state.copyWith(themeMode: mode);
  void setSyncInterval(int minutes) =>
      state = state.copyWith(syncIntervalMinutes: minutes);
  void setPhotoQuality(String q) => state = state.copyWith(photoQuality: q);

  /// Arrotonda al passo e limita ai valori consentiti.
  double _normalize(double value) {
    final clamped = value.clamp(AppSettings.minScale, AppSettings.maxScale);
    // Arrotonda a 1 decimale per evitare derive in virgola mobile.
    return (clamped * 10).roundToDouble() / 10;
  }

  void setTextScale(double value) =>
      state = state.copyWith(textScale: _normalize(value));

  void increaseTextScale() =>
      setTextScale(state.textScale + AppSettings.scaleStep);

  void decreaseTextScale() =>
      setTextScale(state.textScale - AppSettings.scaleStep);

  void resetTextScale() => setTextScale(1.0);

  void setIconScale(double value) =>
      state = state.copyWith(iconScale: _normalize(value));

  void increaseIconScale() =>
      setIconScale(state.iconScale + AppSettings.scaleStep);

  void decreaseIconScale() =>
      setIconScale(state.iconScale - AppSettings.scaleStep);

  void resetIconScale() => setIconScale(1.0);
}

final settingsProvider =
    StateNotifierProvider<SettingsController, AppSettings>(
        (ref) => SettingsController());

/// Coda di sincronizzazione (per la schermata Impostazioni → Sincronizzazione).
