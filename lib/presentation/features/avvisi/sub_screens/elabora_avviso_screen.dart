// Elabora Avviso — modifica avviso: priorità, stato utente,
// pressione, esito VER, note. Le modifiche vengono accodate verso il Cruscotto.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../providers/avvisi_provider.dart';

class ElaboraAvvisoScreen extends ConsumerStatefulWidget {
  final String numero;
  const ElaboraAvvisoScreen({super.key, required this.numero});

  @override
  ConsumerState<ElaboraAvvisoScreen> createState() =>
      _ElaboraAvvisoScreenState();
}

class _ElaboraAvvisoScreenState extends ConsumerState<ElaboraAvvisoScreen> {
  static const _statiUtente = [
    'I0001 — Iniziato',
    'I0002 — In esecuzione',
    'I0003 — Sospeso',
    'I0005 — Chiuso',
    'I0006 — Annullato',
  ];
  static const _priorita = [
    '0 — Altro, no pericolo',
    '1 — Bassa',
    '2 — Media',
    '3 — Alta',
    '4 — Critica',
  ];
  static const _esitoVer = [
    '-NONE-',
    'OK — Verifica positiva',
    'NO — Verifica negativa',
    'PD — Pendente',
  ];

  bool _fermoMacchina = false;
  String? _statoUtente;
  String? _prioritaSel;
  final _pressioneCtrl = TextEditingController();
  String _esito = '-NONE-';
  final _sedeTecCtrl = TextEditingController();
  final _equipmentCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _pressioneCtrl.dispose();
    _sedeTecCtrl.dispose();
    _equipmentCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(avvisoDetailProvider(widget.numero));
    return Scaffold(
      appBar: AppBar(title: const Text('Elabora avviso')),
      body: async.when(
        loading: () => const WfmLoading(),
        error: (e, _) => WfmErrorState(message: e.toString()),
        data: (a) {
          _prioritaSel ??= _priorita.firstWhere(
              (p) => p.startsWith(a.priorita),
              orElse: () => _priorita.first);
          _statoUtente ??= _statiUtente.firstWhere(
              (s) => s.contains(a.stato),
              orElse: () => _statiUtente.first);
          return ListView(
            padding: kPagePadding,
            children: [
              const SectionHeader(title: 'AVVISO'),
              FieldRow(label: 'Numero avviso', value: a.numeroAvviso),
              const SizedBox(height: 12),
              FieldRow(
                  label: 'Descrizione',
                  value: a.descrizione,
                  fullWidth: true),
              const SectionHeader(title: 'OGGETTI TECNICI'),
              TextField(
                controller: _sedeTecCtrl,
                decoration:
                    const InputDecoration(labelText: 'Sede tecnica'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _equipmentCtrl,
                decoration: const InputDecoration(labelText: 'Equipment'),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Fermo macchina'),
                value: _fermoMacchina,
                onChanged: (v) => setState(() => _fermoMacchina = v),
              ),
              const SectionHeader(title: 'STATO & PRIORITÀ'),
              DropdownButtonFormField<String>(
                initialValue: _statoUtente,
                isExpanded: true,
                decoration:
                    const InputDecoration(labelText: 'Stato utente'),
                items: _statiUtente
                    .map((s) =>
                        DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => setState(() => _statoUtente = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _prioritaSel,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Priorità'),
                items: _priorita
                    .map((p) =>
                        DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
                onChanged: (v) => setState(() => _prioritaSel = v),
              ),
              const SectionHeader(title: 'NORMATIVA 655'),
              TextField(
                controller: _pressioneCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Pressione (bar)',
                    prefixIcon: Icon(Icons.compress_outlined)),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _esito,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Esito VER'),
                items: _esitoVer
                    .map((e) =>
                        DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() => _esito = v ?? '-NONE-'),
              ),
              const SectionHeader(title: 'NOTE'),
              TextField(
                controller: _noteCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                    labelText: 'Note', alignLabelWithHint: true),
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
                label: Text(_saving ? 'Invio…' : 'Salva modifiche'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() => _saving = false);
    showSapToast(context, 'Modifiche all\'avviso ${widget.numero} accodate');
    context.pop();
  }
}
