// Lettura a voce alta: la voce, il tono e la velocità scelti in Impostazioni
// arrivano al motore vocale. Il motore qui è finto (canale della piattaforma).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wfm_mobile/core/services/impostazioni_store.dart';
import 'package:wfm_mobile/core/services/lettura_vocale_service.dart';
import 'package:wfm_mobile/core/widgets/voice_text_field.dart';
import 'package:wfm_mobile/presentation/providers/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final chiamate = <MethodCall>[];

  setUp(() {
    chiamate.clear();
    ImpostazioniStore.resetForTests();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'), (c) async {
      chiamate.add(c);
      if (c.method == 'getVoices') {
        return [
          {'name': 'it-it-x-itb-local', 'locale': 'it-IT'},
          {'name': 'it-it-x-itd-local', 'locale': 'it-IT'},
          {'name': 'en-us-x-tpf-local', 'locale': 'en-US'},
        ];
      }
      return 1;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'), null);
  });

  Iterable<MethodCall> quali(String m) => chiamate.where((c) => c.method == m);

  test('elenca solo le voci italiane', () async {
    final voci = await LetturaVocale.instance.vociItaliane();
    expect(voci.map((v) => v.nome), ['it-it-x-itb-local', 'it-it-x-itd-local']);
  });

  test('applica: voce scelta, tono e velocità', () async {
    await LetturaVocale.instance
        .applica(voce: 'it-it-x-itd-local', tono: 0.7, velocita: 0.4);
    expect(quali('setVoice').single.arguments,
        {'name': 'it-it-x-itd-local', 'locale': 'it-IT'});
    expect(quali('setPitch').single.arguments, 0.7);
    expect(quali('setSpeechRate').single.arguments, 0.4);
  });

  test('una voce non più installata non viene impostata', () async {
    await LetturaVocale.instance.applica(voce: 'sparita', tono: 1.0);
    expect(quali('setVoice'), isEmpty);
    expect(quali('setPitch'), hasLength(1));
  });

  test('senza voce scelta resta la predefinita', () async {
    await LetturaVocale.instance.applica();
    expect(quali('setVoice'), isEmpty);
  });

  testWidgets('l\'altoparlante di un campo legge con le impostazioni',
      (t) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(settingsProvider.notifier)
      ..setVoceLettura('it-it-x-itd-local')
      ..setVocePitch(0.6);
    final ctrl = TextEditingController(text: 'Perdita sul contatore');
    await t.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
          home: Scaffold(body: VoiceTextField(controller: ctrl, label: 'Note'))),
    ));
    await t.tap(find.byIcon(Icons.volume_up_outlined));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await t.pump();

    expect(quali('setVoice').last.arguments['name'], 'it-it-x-itd-local');
    expect(quali('setPitch').last.arguments, 0.6);
    expect(quali('speak').last.arguments, 'Perdita sul contatore');
  });
}
