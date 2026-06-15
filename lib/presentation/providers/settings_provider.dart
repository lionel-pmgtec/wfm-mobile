import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Impostazioni locali (M14). In memoria per l'MVP; TODO: persistere su Hive.
class AppSettings {
  final ThemeMode themeMode;
  final int syncIntervalMinutes; // 5/15/30/60
  final String photoQuality; // alta/media/bassa
  final String language; // it

  const AppSettings({
    this.themeMode = ThemeMode.light,
    this.syncIntervalMinutes = 15,
    this.photoQuality = 'media',
    this.language = 'it',
  });

  AppSettings copyWith({
    ThemeMode? themeMode,
    int? syncIntervalMinutes,
    String? photoQuality,
    String? language,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      syncIntervalMinutes: syncIntervalMinutes ?? this.syncIntervalMinutes,
      photoQuality: photoQuality ?? this.photoQuality,
      language: language ?? this.language,
    );
  }
}

class SettingsController extends StateNotifier<AppSettings> {
  SettingsController() : super(const AppSettings());

  void setThemeMode(ThemeMode mode) => state = state.copyWith(themeMode: mode);
  void setSyncInterval(int minutes) =>
      state = state.copyWith(syncIntervalMinutes: minutes);
  void setPhotoQuality(String q) => state = state.copyWith(photoQuality: q);
}

final settingsProvider =
    StateNotifierProvider<SettingsController, AppSettings>(
        (ref) => SettingsController());

/// Coda di sincronizzazione (per la schermata Impostazioni → Sincronizzazione).
