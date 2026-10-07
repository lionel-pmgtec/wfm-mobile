// Impostazioni: si salvano su disco e tornano dopo il riavvio dell'app;
// voce di lettura (voce, tono, velocità) scelta in Impostazioni.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:wfm_mobile/core/services/impostazioni_store.dart';
import 'package:wfm_mobile/presentation/features/settings/settings_screen.dart';
import 'package:wfm_mobile/presentation/providers/settings_provider.dart';

void main() {
  late Directory dir;

  setUpAll(() => initializeDateFormatting('it_IT', null));

  setUp(() async {
    ImpostazioniStore.resetForTests();
    dir = await Directory.systemTemp.createTemp('impostazioni_test');
    await ImpostazioniStore.open(hivePath: dir.path);
  });

  tearDown(() async {
    ImpostazioniStore.resetForTests();
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  });

  /// Simula il riavvio: la memoria si svuota e si riapre il file su disco.
  Future<void> riavvia() async {
    ImpostazioniStore.resetForTests();
    await ImpostazioniStore.open(hivePath: dir.path);
  }

  test('senza nulla di salvato: valori predefiniti', () {
    final s = SettingsController().state;
    expect(s.textScale, 1.0);
    expect(s.voceLettura, '');
    expect(s.vocePitch, 1.0);
    expect(s.voceVelocita, 0.5);
    expect(s.themeMode, ThemeMode.light);
  });

  test('tutte le impostazioni tornano dopo il riavvio', () async {
    final c = SettingsController();
    c.setThemeMode(ThemeMode.dark);
    c.setSyncInterval(30);
    c.setPhotoQuality('alta');
    c.setTextScale(1.3);
    c.setIconScale(1.2);
    c.setVoceLettura('it-it-x-itd-local');
    c.setVocePitch(0.7);
    c.setVoceVelocita(0.4);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    await riavvia();
    final s = SettingsController().state;
    expect(s.themeMode, ThemeMode.dark);
    expect(s.syncIntervalMinutes, 30);
    expect(s.photoQuality, 'alta');
    expect(s.textScale, 1.3);
    expect(s.iconScale, 1.2);
    expect(s.voceLettura, 'it-it-x-itd-local');
    expect(s.vocePitch, 0.7);
    expect(s.voceVelocita, 0.4);
  });

  test('valori salvati non validi: si torna al predefinito', () async {
    await ImpostazioniStore.scrivi({
      'themeMode': 'boh',
      'syncIntervalMinutes': '7',
      'photoQuality': 'enorme',
      'textScale': 'abc',
      'vocePitch': '9',
      'voceVelocita': '-3',
    });
    final s = SettingsController().state;
    expect(s.themeMode, ThemeMode.light);
    expect(s.syncIntervalMinutes, 15);
    expect(s.photoQuality, 'media');
    expect(s.textScale, 1.0);
    expect(s.vocePitch, AppSettings.maxPitch); // limitato
    expect(s.voceVelocita, AppSettings.minVelocita);
  });

  test('tono e velocità restano nei limiti', () {
    final c = SettingsController();
    c.setVocePitch(5);
    expect(c.state.vocePitch, AppSettings.maxPitch);
    c.setVoceVelocita(0);
    expect(c.state.voceVelocita, AppSettings.minVelocita);
  });

  test('ripristina: voce, tono e velocità predefiniti', () {
    final c = SettingsController();
    c.setVoceLettura('x');
    c.setVocePitch(0.6);
    c.ripristinaVoce();
    expect(c.state.voceLettura, '');
    expect(c.state.vocePitch, 1.0);
    expect(c.state.voceVelocita, 0.5);
  });

  testWidgets('la schermata mostra la sezione Voce di lettura', (t) async {
    await t.binding.setSurfaceSize(const Size(1000, 3000));
    await t.pumpWidget(const ProviderScope(
        child: MaterialApp(home: SettingsScreen())));
    await t.pumpAndSettle();
    // Il canale del motore vocale risponde in modo asincrono reale.
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await t.pumpAndSettle();
    expect(find.text('VOCE DI LETTURA'), findsOneWidget);
    expect(find.text('Tono'), findsOneWidget);
    expect(find.text('Velocità'), findsOneWidget);
    expect(find.text('Prova la voce'), findsOneWidget);
    // Nei test non c'è un motore vocale: nessuna voce, e nessun errore.
    expect(find.text('Nessuna voce italiana trovata sul dispositivo'),
        findsOneWidget);
  });

  testWidgets('spostare il tono e "Ripristina" aggiornano le impostazioni',
      (t) async {
    await t.binding.setSurfaceSize(const Size(1000, 3000));
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await t.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SettingsScreen())));
    await t.pumpAndSettle();

    final tono = find.byType(Slider).first;
    await t.drag(tono, const Offset(-400, 0));
    await t.pumpAndSettle();
    expect(container.read(settingsProvider).vocePitch, lessThan(1.0));

    await t.tap(find.text('Ripristina'));
    await t.pumpAndSettle();
    expect(container.read(settingsProvider).vocePitch, 1.0);
  });
}
