// Dettatura vocale (speech_to_text) e lettura a voce alta (flutter_tts) per i
// campi di testo. Il microfono AGGIUNGE il testo dettato in coda a quello già
// scritto (non lo sovrascrive); l'altoparlante legge il contenuto attuale.
// Pensato per note/descrizioni compilate sul campo, spesso con le mani
// sporche o l'operatore in piedi accanto al contatore.
//
// Entrambe le funzioni sono "silenziose" se il dispositivo non le supporta o
// nega il permesso: il tocco semplicemente non fa nulla di rumoroso, il
// campo resta un TextFormField normale, mai bloccante.
//
// Due modi d'uso:
// - `VoiceTextField`: campo completo pronto all'uso (stile di default).
// - `VoiceSuffixIcons`: solo le due iconcine, da passare come `suffixIcon` a
//   un `TextFormField`/`InputDecoration` già stilizzato da un'altra
//   schermata (es. bordo/riempimento propri di `create_order_screen.dart`).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../presentation/providers/settings_provider.dart';
import '../services/lettura_vocale_service.dart';
import '../theme/app_theme.dart';

class VoiceSuffixIcons extends StatefulWidget {
  /// Campo modificabile: mostra microfono (dettatura, scrive qui) e
  /// altoparlante (legge il contenuto attuale del controller).
  final TextEditingController? controller;

  /// Testo fisso in sola lettura (es. una `FieldRow` non editabile, dato
  /// SAP): solo l'altoparlante ha senso, non c'è nulla in cui dettare.
  final String? text;
  final bool enableSpeech;
  final bool enableTts;
  const VoiceSuffixIcons({
    super.key,
    this.controller,
    this.text,
    this.enableSpeech = true,
    this.enableTts = true,
  }) : assert(controller != null || text != null,
            'serve un controller (campo modificabile) o un testo fisso (sola lettura)');

  @override
  State<VoiceSuffixIcons> createState() => _VoiceSuffixIconsState();
}

class _VoiceSuffixIconsState extends State<VoiceSuffixIcons> {
  // Condivisi fra tutti i campi dell'app: una sola dettatura/lettura alla
  // volta ha senso (non si può parlare in due microfoni contemporaneamente).
  static final SpeechToText _speech = SpeechToText();
  static final LetturaVocale _tts = LetturaVocale.instance;

  bool _speechInizializzato = false;
  bool _ascolto = false;
  bool _parlando = false;
  String _basePrimaDellaDettatura = '';

  @override
  void initState() {
    super.initState();
    if (widget.enableTts) {
      _tts.suFine(() {
        if (mounted) setState(() => _parlando = false);
      });
    }
  }

  Future<void> _assicuraSpeechInizializzato() async {
    if (_speechInizializzato) return;
    try {
      _speechInizializzato = await _speech.initialize(
        onStatus: (status) {
          if ((status == 'done' || status == 'notListening') && mounted) {
            setState(() => _ascolto = false);
          }
        },
        onError: (_) {
          if (mounted) setState(() => _ascolto = false);
        },
      );
    } catch (_) {
      _speechInizializzato = false;
    }
  }

  Future<void> _toggleDettatura() async {
    final controller = widget.controller;
    if (controller == null) return; // testo fisso: niente da dettare
    if (_ascolto) {
      await _speech.stop();
      if (mounted) setState(() => _ascolto = false);
      return;
    }
    await _assicuraSpeechInizializzato();
    if (!_speechInizializzato) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Dettatura vocale non disponibile su questo dispositivo')));
      }
      return;
    }
    // La dettatura si aggiunge in coda al testo già presente, non lo sovrascrive.
    final esistente = controller.text;
    _basePrimaDellaDettatura =
        esistente.isEmpty || esistente.endsWith(' ') ? esistente : '$esistente ';
    if (mounted) setState(() => _ascolto = true);
    try {
      await _speech.listen(
        onResult: (SpeechRecognitionResult r) {
          controller.text = _basePrimaDellaDettatura + r.recognizedWords;
          controller.selection =
              TextSelection.collapsed(offset: controller.text.length);
        },
        listenOptions: SpeechListenOptions(
          partialResults: true,
          listenMode: ListenMode.dictation,
          cancelOnError: true,
          localeId: 'it_IT',
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _ascolto = false);
    }
  }

  Future<void> _toggleLettura() async {
    if (_parlando) {
      await _tts.ferma();
      if (mounted) setState(() => _parlando = false);
      return;
    }
    final testo = (widget.controller?.text ?? widget.text ?? '').trim();
    if (testo.isEmpty) return;
    if (mounted) setState(() => _parlando = true);
    try {
      // Voce, tono e velocità scelti in Impostazioni (predefiniti se la
      // schermata non è dentro un ProviderScope).
      var impostazioni = const AppSettings();
      try {
        impostazioni =
            ProviderScope.containerOf(context, listen: false).read(settingsProvider);
      } catch (_) {}
      await _tts.applica(
          voce: impostazioni.voceLettura,
          tono: impostazioni.vocePitch,
          velocita: impostazioni.voceVelocita);
      await _tts.parla(testo);
    } catch (_) {
      if (mounted) setState(() => _parlando = false);
    }
  }

  @override
  void dispose() {
    if (_ascolto) _speech.stop();
    if (_parlando) _tts.ferma();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.enableTts)
          IconButton(
            tooltip: _parlando ? 'Interrompi lettura' : 'Leggi a voce alta',
            icon: Icon(
                _parlando ? Icons.volume_off_outlined : Icons.volume_up_outlined,
                color: AppColors.primary),
            onPressed: _toggleLettura,
          ),
        if (widget.enableSpeech && widget.controller != null)
          IconButton(
            tooltip: _ascolto ? 'Interrompi dettatura' : 'Detta a voce',
            icon: Icon(_ascolto ? Icons.mic : Icons.mic_none_outlined,
                color: _ascolto ? Colors.red : AppColors.primary),
            onPressed: _toggleDettatura,
          ),
      ],
    );
  }
}

class VoiceTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final int maxLines;
  final bool required;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final bool enableSpeech;
  final bool enableTts;

  const VoiceTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.maxLines = 1,
    this.required = false,
    this.validator,
    this.keyboardType,
    this.enableSpeech = true,
    this.enableTts = true,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        hintText: hint,
        alignLabelWithHint: maxLines > 1,
        suffixIcon: VoiceSuffixIcons(
            controller: controller,
            enableSpeech: enableSpeech,
            enableTts: enableTts),
      ),
    );
  }
}
