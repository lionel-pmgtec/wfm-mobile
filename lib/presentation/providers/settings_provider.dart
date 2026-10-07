import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/impostazioni_store.dart';

/// Impostazioni locali. Ogni modifica viene salvata su disco
/// ([ImpostazioniStore]) e riletta all'avvio.
class AppSettings {
  final ThemeMode themeMode;
  final int syncIntervalMinutes; // 5/15/30/60
  final String photoQuality; // alta/media/bassa
  final String language; // it
  final double textScale; // fattore di scala del testo dell'intera app
  final double iconScale; // fattore di scala delle icone dell'intera app

  /// Voce di lettura (altoparlante dei campi di testo): nome della voce
  /// installata sul tablet ('' = voce predefinita), tono e velocità.
  final String voceLettura;
  final double vocePitch;
  final double voceVelocita;

  /// Limiti e passo dei fattori di scala (testo e icone).
  static const double minScale = 0.8;
  static const double maxScale = 1.6;
  static const double scaleStep = 0.1;

  /// Limiti della voce: tono 0.5 (grave) … 1.5 (acuto); velocità del motore
  /// (0.5 = normale).
  static const double minPitch = 0.5;
  static const double maxPitch = 1.5;
  static const double minVelocita = 0.2;
  static const double maxVelocita = 0.8;

  const AppSettings({
    this.themeMode = ThemeMode.light,
    this.syncIntervalMinutes = 15,
    this.photoQuality = 'media',
    this.language = 'it',
    this.textScale = 1.0,
    this.iconScale = 1.0,
    this.voceLettura = '',
    this.vocePitch = 1.0,
    this.voceVelocita = 0.5,
  });

  AppSettings copyWith({
    ThemeMode? themeMode,
    int? syncIntervalMinutes,
    String? photoQuality,
    String? language,
    double? textScale,
    double? iconScale,
    String? voceLettura,
    double? vocePitch,
    double? voceVelocita,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      syncIntervalMinutes: syncIntervalMinutes ?? this.syncIntervalMinutes,
      photoQuality: photoQuality ?? this.photoQuality,
      language: language ?? this.language,
      textScale: textScale ?? this.textScale,
      iconScale: iconScale ?? this.iconScale,
      voceLettura: voceLettura ?? this.voceLettura,
      vocePitch: vocePitch ?? this.vocePitch,
      voceVelocita: voceVelocita ?? this.voceVelocita,
    );
  }

  Map<String, String> toStore() => {
        'themeMode': themeMode.name,
        'syncIntervalMinutes': '$syncIntervalMinutes',
        'photoQuality': photoQuality,
        'language': language,
        'textScale': '$textScale',
        'iconScale': '$iconScale',
        'voceLettura': voceLettura,
        'vocePitch': '$vocePitch',
        'voceVelocita': '$voceVelocita',
      };

  /// Impostazioni salvate; per ogni valore assente o non valido resta il
  /// predefinito.
  factory AppSettings.daStore() {
    String? l(String k) => ImpostazioniStore.leggi(k);
    double? n(String k, double min, double max) {
      return double.tryParse(l(k) ?? '')?.clamp(min, max).toDouble();
    }

    const d = AppSettings();
    final sync = int.tryParse(l('syncIntervalMinutes') ?? '');
    final foto = l('photoQuality');
    return AppSettings(
      themeMode: ThemeMode.values.firstWhere((m) => m.name == l('themeMode'),
          orElse: () => d.themeMode),
      syncIntervalMinutes: const [5, 15, 30, 60].contains(sync) ? sync! : d.syncIntervalMinutes,
      photoQuality: const ['alta', 'media', 'bassa'].contains(foto) ? foto! : d.photoQuality,
      language: l('language') ?? d.language,
      textScale: n('textScale', minScale, maxScale) ?? d.textScale,
      iconScale: n('iconScale', minScale, maxScale) ?? d.iconScale,
      voceLettura: l('voceLettura') ?? d.voceLettura,
      vocePitch: n('vocePitch', minPitch, maxPitch) ?? d.vocePitch,
      voceVelocita: n('voceVelocita', minVelocita, maxVelocita) ?? d.voceVelocita,
    );
  }
}

class SettingsController extends StateNotifier<AppSettings> {
  SettingsController() : super(AppSettings.daStore());

  /// Ogni cambio di stato viene scritto su disco.
  @override
  set state(AppSettings value) {
    super.state = value;
    ImpostazioniStore.scrivi(value.toStore());
  }

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

  // ── Voce di lettura ───────────────────────────────────────────────────────
  void setVoceLettura(String nome) => state = state.copyWith(voceLettura: nome);

  void setVocePitch(double v) => state = state.copyWith(
      vocePitch: v.clamp(AppSettings.minPitch, AppSettings.maxPitch).toDouble());

  void setVoceVelocita(double v) => state = state.copyWith(
      voceVelocita:
          v.clamp(AppSettings.minVelocita, AppSettings.maxVelocita).toDouble());

  /// Torna a voce, tono e velocità predefiniti.
  void ripristinaVoce() => state = state.copyWith(
      voceLettura: '', vocePitch: 1.0, voceVelocita: 0.5);
}

final settingsProvider =
    StateNotifierProvider<SettingsController, AppSettings>(
        (ref) => SettingsController());

/// Coda di sincronizzazione (per la schermata Impostazioni → Sincronizzazione).
