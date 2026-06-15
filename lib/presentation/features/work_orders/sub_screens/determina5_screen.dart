// Determina 5 e Bilancio Idrico — calcoli regolatori
// specifici al settore acqua (ARERA - Determina 5/DSAI).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';

class Determina5Screen extends ConsumerStatefulWidget {
  final String code;
  const Determina5Screen({super.key, required this.code});

  @override
  ConsumerState<Determina5Screen> createState() => _Determina5ScreenState();
}

class _Determina5ScreenState extends ConsumerState<Determina5Screen> {
  String? _interventoPuntuale;
  String? _tipologiaIntervento;
  String? _causaIntervento;
  final _volumePrimaCtrl = TextEditingController(text: '0');
  final _volumeRiparazioneCtrl = TextEditingController(text: '0');
  String? _confermaRifiuto;
  bool _saving = false;

  static const _interventiPuntuali = [
    'IP01 — Rete adduzione',
    'IP02 — Rete distribuzione',
    'IP03 — Allaccio utente',
    'IP04 — Serbatoio',
    'IP05 — Pozzo',
  ];

  static const _tipologie = [
    'TIP01 — Perdita visibile',
    'TIP02 — Perdita occulta',
    'TIP03 — Rottura condotta',
    'TIP04 — Manutenzione programmata',
  ];

  static const _cause = [
    'CA01 — Vetustà',
    'CA02 — Scavi terzi',
    'CA03 — Gelo',
    'CA04 — Sovrappressione',
    'CA05 — Altro',
  ];

  static const _confermeRifiuti = [
    'C — Conferma',
    'R — Rifiuto',
    '— Da valutare',
  ];

  @override
  void dispose() {
    _volumePrimaCtrl.dispose();
    _volumeRiparazioneCtrl.dispose();
    super.dispose();
  }

  num get _volumeRecuperato {
    final pre = num.tryParse(_volumePrimaCtrl.text.replaceAll(',', '.')) ?? 0;
    final post =
        num.tryParse(_volumeRiparazioneCtrl.text.replaceAll(',', '.')) ?? 0;
    final diff = pre - post;
    return diff < 0 ? 0 : diff;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Determina 5 / Bilancio idrico')),
      body: ListView(
        padding: kPagePadding,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.statusReceivedBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: const [
              Icon(Icons.water_drop_outlined, color: AppColors.primary),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Calcolo regolatorio del recupero idrico post-intervento.',
                  style: AppTextStyles.bodySmall,
                ),
              ),
            ]),
          ),
          const SectionHeader(title: 'CLASSIFICAZIONE INTERVENTO'),
          DropdownButtonFormField<String>(
            initialValue: _interventoPuntuale,
            isExpanded: true,
            decoration:
                const InputDecoration(labelText: 'Intervento puntuale *'),
            items: _interventiPuntuali
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) => setState(() => _interventoPuntuale = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _tipologiaIntervento,
            isExpanded: true,
            decoration:
                const InputDecoration(labelText: 'Tipologia intervento *'),
            items: _tipologie
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) => setState(() => _tipologiaIntervento = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _causaIntervento,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Causa intervento'),
            items: _cause
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) => setState(() => _causaIntervento = v),
          ),
          const SectionHeader(title: 'BILANCIO IDRICO (m³)'),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _volumePrimaCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Volume perdita PRE riparazione',
                  suffixText: 'm³',
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _volumeRiparazioneCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Volume perdita POST riparazione',
                  suffixText: 'm³',
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.accentGreen.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppColors.accentGreen.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.eco_outlined,
                  color: AppColors.accentGreen),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Volume idrico recuperato',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accentGreen,
                            letterSpacing: 0.4)),
                    const SizedBox(height: 2),
                    Text(
                        '${_volumeRecuperato.toStringAsFixed(2)} m³',
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accentGreen)),
                  ],
                ),
              ),
            ]),
          ),
          const SectionHeader(title: 'CONFERMA / RIFIUTO'),
          DropdownButtonFormField<String>(
            initialValue: _confermaRifiuto,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Esito'),
            items: _confermeRifiuti
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) => setState(() => _confermaRifiuto = v),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _saving ? null : _submit,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Salvataggio…' : 'Salva Determina 5'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_interventoPuntuale == null || _tipologiaIntervento == null) {
      showSapToast(context,
          'Compilare intervento puntuale e tipologia', isError: true);
      return;
    }
    setState(() => _saving = true);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() => _saving = false);
    showSapToast(context,
        'Determina 5 salvata · recupero ${_volumeRecuperato.toStringAsFixed(2)} m³');
    context.pop();
  }
}
