// Dati RQTI — Referenziale Qualità Tecnica Interruzioni.
// Visibile solo per categorie di rete (ZA*, interruzioni di servizio).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../domain/entities/entities.dart';

class DatiRqtiScreen extends ConsumerStatefulWidget {
  final String code;
  const DatiRqtiScreen({super.key, required this.code});

  @override
  ConsumerState<DatiRqtiScreen> createState() => _DatiRqtiScreenState();
}

class _DatiRqtiScreenState extends ConsumerState<DatiRqtiScreen> {
  InterventionMode? _mode;
  DateTime? _start;
  DateTime? _end;
  final _affectedCtrl = TextEditingController(text: '0');
  final _pressureCtrl = TextEditingController();
  String? _schemaSato;
  String? _stato;
  bool _saving = false;

  static const _schemi = ['ZORDI', 'ZSPEC', 'ZURGE'];
  static const _stati = [
    'E0001 — Valido',
    'E0002 — In attesa',
    'E0003 — Annullato',
  ];

  @override
  void dispose() {
    _affectedCtrl.dispose();
    _pressureCtrl.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDateTime(DateTime? initial) async {
    final d = await showDatePicker(
        context: context,
        initialDate: initial ?? DateTime.now(),
        firstDate: DateTime(2020),
        lastDate: DateTime(2035));
    if (d == null || !mounted) return null;
    final t = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initial ?? DateTime.now()));
    return DateTime(d.year, d.month, d.day, t?.hour ?? 0, t?.minute ?? 0);
  }

  Duration? get _duration {
    if (_start == null || _end == null) return null;
    return _end!.difference(_start!);
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h == 0) return '$m min';
    return '${h}h ${m}min';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dati RQTI')),
      body: ListView(
        padding: kPagePadding,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.statusReceivedBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(children: [
              Icon(Icons.info_outline, color: AppColors.primary),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Compila i dati RQTI per il calcolo regolatorio dell\'interruzione.',
                  style: AppTextStyles.bodySmall,
                ),
              ),
            ]),
          ),
          const SectionHeader(title: 'MODALITÀ INTERVENTO'),
          DropdownButtonFormField<InterventionMode>(
            initialValue: _mode,
            isExpanded: true,
            decoration:
                const InputDecoration(labelText: 'Modalità intervento *'),
            items: InterventionMode.values
                .map((m) =>
                    DropdownMenuItem(value: m, child: Text(m.label)))
                .toList(),
            onChanged: (v) => setState(() => _mode = v),
          ),
          const SectionHeader(title: 'INTERRUZIONE'),
          Row(children: [
            Expanded(
              child: InkWell(
                onTap: () async {
                  final d = await _pickDateTime(_start);
                  if (d != null) setState(() => _start = d);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                      labelText: 'Inizio interruzione',
                      prefixIcon: Icon(Icons.play_arrow_rounded)),
                  child: Text(_start == null ? '—' : Fmt.dateTime(_start!),
                      style: AppTextStyles.fieldValue),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: () async {
                  final d = await _pickDateTime(_end);
                  if (d != null) setState(() => _end = d);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                      labelText: 'Fine interruzione',
                      prefixIcon: Icon(Icons.stop_rounded)),
                  child: Text(_end == null ? '—' : Fmt.dateTime(_end!),
                      style: AppTextStyles.fieldValue),
                ),
              ),
            ),
          ]),
          if (_duration != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.accentGreen.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(children: [
                const Icon(Icons.schedule,
                    size: 16, color: AppColors.accentGreen),
                const SizedBox(width: 6),
                Text('Durata interruzione: ${_formatDuration(_duration!)}',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accentGreen)),
              ]),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _affectedCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Utenze disservite (numero)',
              prefixIcon: Icon(Icons.groups_outlined),
            ),
          ),
          const SectionHeader(title: 'PRESSIONE & SCHEMA'),
          TextField(
            controller: _pressureCtrl,
            decoration: const InputDecoration(
              labelText: 'Livello pressione (bar)',
              hintText: 'es. 3.5',
            ),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _schemaSato,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Schema SATO'),
            items: _schemi
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) => setState(() => _schemaSato = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _stato,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Stato'),
            items: _stati
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) => setState(() => _stato = v),
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
            label: Text(_saving ? 'Salvataggio…' : 'Salva dati RQTI'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_mode == null) {
      showSapToast(context, 'Selezionare la modalità intervento',
          isError: true);
      return;
    }
    setState(() => _saving = true);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() => _saving = false);
    showSapToast(context, 'Dati RQTI salvati');
    context.pop();
  }
}
