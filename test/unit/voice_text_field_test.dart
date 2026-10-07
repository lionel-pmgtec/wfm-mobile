// Dettatura vocale (microfono) e lettura a voce alta (altoparlante) sui campi
// di testo. In ambiente di test non c'è un vero motore STT/TTS: verifichiamo
// solo che le icone compaiano e che i tocchi non facciano esplodere il widget
// (le eccezioni del platform channel sono catturate internamente).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wfm_mobile/core/widgets/voice_text_field.dart';

void main() {
  testWidgets('VoiceTextField mostra microfono e altoparlante', (t) async {
    final ctrl = TextEditingController();
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
          body: VoiceTextField(controller: ctrl, label: 'Note')),
    ));
    await t.pump();

    expect(find.byIcon(Icons.mic_none_outlined), findsOneWidget);
    expect(find.byIcon(Icons.volume_up_outlined), findsOneWidget);
  });

  testWidgets('il tocco sull\'altoparlante senza testo non fa nulla', (t) async {
    final ctrl = TextEditingController();
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
          body: VoiceTextField(controller: ctrl, label: 'Note')),
    ));
    await t.pump();

    await t.tap(find.byIcon(Icons.volume_up_outlined));
    await t.pumpAndSettle();

    // Nessuna eccezione, l'icona resta quella di partenza (non "in lettura").
    expect(find.byIcon(Icons.volume_up_outlined), findsOneWidget);
  });

  testWidgets(
      'il tocco sul microfono senza motore STT disponibile non crasha il widget',
      (t) async {
    final ctrl = TextEditingController();
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
          body: VoiceTextField(controller: ctrl, label: 'Note')),
    ));
    await t.pump();

    // In test non c'è un motore STT reale: l'inizializzazione fallisce in modo
    // controllato. Se l'eccezione non fosse catturata, pumpAndSettle la
    // rilancerebbe e questo test fallirebbe.
    await t.tap(find.byIcon(Icons.mic_none_outlined));
    await t.pumpAndSettle();

    expect(find.byType(VoiceTextField), findsOneWidget);
  });

  testWidgets('enableSpeech/enableTts a false nasconde le rispettive icone',
      (t) async {
    final ctrl = TextEditingController();
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
          body: VoiceTextField(
              controller: ctrl,
              label: 'Note',
              enableSpeech: false,
              enableTts: false)),
    ));
    await t.pump();

    expect(find.byIcon(Icons.mic_none_outlined), findsNothing);
    expect(find.byIcon(Icons.volume_up_outlined), findsNothing);
  });

  testWidgets(
      'VoiceSuffixIcons con testo fisso (campo sola lettura): niente microfono',
      (t) async {
    await t.pumpWidget(const MaterialApp(
      home: Scaffold(
          body: VoiceSuffixIcons(text: 'Descrizione SAP', enableSpeech: false)),
    ));
    await t.pump();

    expect(find.byIcon(Icons.volume_up_outlined), findsOneWidget);
    expect(find.byIcon(Icons.mic_none_outlined), findsNothing);
  });

  testWidgets('VoiceSuffixIcons con testo fisso: leggere non crasha', (t) async {
    await t.pumpWidget(const MaterialApp(
      home: Scaffold(
          body: VoiceSuffixIcons(text: 'Descrizione SAP', enableSpeech: false)),
    ));
    await t.pump();

    await t.tap(find.byIcon(Icons.volume_up_outlined));
    await t.pumpAndSettle();

    expect(find.byType(VoiceSuffixIcons), findsOneWidget);
  });
}
