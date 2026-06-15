// Esito Appuntamento — flussi D58/D59 verso Cruscotto.
// Diverso dall'esito tecnico : qui si registra l'esito del singolo sopralluogo.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/widgets.dart';

class EsitoAppuntamentoScreen extends ConsumerStatefulWidget {
  final String code;
  const EsitoAppuntamentoScreen({super.key, required this.code});

  @override
  ConsumerState<EsitoAppuntamentoScreen> createState() =>
      _EsitoAppuntamentoScreenState();
}

class _EsitoAppuntamentoScreenState
    extends ConsumerState<EsitoAppuntamentoScreen> {
  DateTime _dataSopralluogo = DateTime.now();
  String _oraSopralluogo = '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}';

  static const _esitoOptions = [
    ('OK', 'OK — Esito positivo', AppColors.accentGreen),
    ('NO', 'NO — Esito negativo', AppColors.accentRed),
    ('ER', 'ER — Errore inserimento', AppColors.accentOrange),
    ('MN', 'MN — Mancato accesso', AppColors.statusSuspended),
  ];
  static const _ritiroOptions = [
    '-NONE-',
    'Documento ritirato',
    'Materiale ritirato',
    'Chiavi ritirate',
  ];
  static const _causaOptions = [
    '-NONE-',
    'C001 — Cliente assente',
    'C002 — Indirizzo errato',
    'C003 — Maltempo',
    'C004 — Materiale mancante',
    'C005 — Problema tecnico',
  ];
  static const _causaRitardoOptions = [
    '-NONE-',
    'CR01 — Traffico',
    'CR02 — Intervento precedente più lungo',
    'CR03 — Comunicazione tardiva',
  ];

  String? _esito;
  String _ritiro = '-NONE-';
  final _motivoCtrl = TextEditingController();
  String _causa = '-NONE-';
  String _causaRitardo = '-NONE-';
  final _motivoRitardoCtrl = TextEditingController();
  bool _dispAnticipazione = false;
  bool _presenzaCliente = true;
  bool _saving = false;

  @override
  void dispose() {
    _motivoCtrl.dispose();
    _motivoRitardoCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
        context: context,
        initialDate: _dataSopralluogo,
        firstDate: DateTime(2020),
        lastDate: DateTime(2030));
    if (d != null) setState(() => _dataSopralluogo = d);
  }

  Future<void> _pickTime() async {
    final parts = _oraSopralluogo.split(':');
    final initial = TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 9,
        minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0);
    final t = await showTimePicker(context: context, initialTime: initial);
    if (t != null) {
      setState(() {
        _oraSopralluogo =
            '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _submit() async {
    if (_esito == null) {
      showSapToast(context, 'Selezionare l\'esito dell\'appuntamento',
          isError: true);
      return;
    }
    setState(() => _saving = true);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() => _saving = false);
    showSapToast(context, 'Esito appuntamento "$_esito" registrato');
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Esito appuntamento')),
      body: ListView(
        padding: kPagePadding,
        children: [
          const SectionHeader(title: 'SOPRALLUOGO'),
          Row(children: [
            Expanded(
              child: InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                      labelText: 'Data sopralluogo *',
                      prefixIcon: Icon(Icons.event_outlined)),
                  child: Text(Fmt.date(_dataSopralluogo),
                      style: AppTextStyles.fieldValue),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: _pickTime,
                child: InputDecorator(
                  decoration: const InputDecoration(
                      labelText: 'Ora',
                      prefixIcon: Icon(Icons.access_time_outlined)),
                  child:
                      Text(_oraSopralluogo, style: AppTextStyles.fieldValue),
                ),
              ),
            ),
          ]),
          const SectionHeader(title: 'ESITO'),
          ...List.generate(_esitoOptions.length, (i) {
            final (code, label, color) = _esitoOptions[i];
            final selected = _esito == code;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: InkWell(
                onTap: () => setState(() => _esito = code),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: selected
                        ? color.withValues(alpha: 0.10)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: selected ? color : AppColors.border,
                        width: selected ? 1.6 : 1),
                  ),
                  child: Row(children: [
                    Icon(
                        selected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: selected ? color : AppColors.textHint),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(label,
                          style: AppTextStyles.fieldValue.copyWith(
                              fontWeight:
                                  selected ? FontWeight.w600 : FontWeight.w400)),
                    ),
                  ]),
                ),
              ),
            );
          }),
          const SectionHeader(title: 'DETTAGLI'),
          DropdownButtonFormField<String>(
            initialValue: _ritiro,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Ritiro'),
            items: _ritiroOptions
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) => setState(() => _ritiro = v ?? '-NONE-'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _motivoCtrl,
            decoration: const InputDecoration(labelText: 'Motivo (testo libero)'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _causa,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Causa'),
            items: _causaOptions
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) => setState(() => _causa = v ?? '-NONE-'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _causaRitardo,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Causa ritardo'),
            items: _causaRitardoOptions
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) =>
                setState(() => _causaRitardo = v ?? '-NONE-'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _motivoRitardoCtrl,
            decoration: const InputDecoration(labelText: 'Motivo ritardo'),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Disponibilità all\'anticipazione'),
            value: _dispAnticipazione,
            onChanged: (v) => setState(() => _dispAnticipazione = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Presenza cliente'),
            value: _presenzaCliente,
            onChanged: (v) => setState(() => _presenzaCliente = v),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _saving ? null : _submit,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_rounded),
            label: Text(_saving ? 'Invio…' : 'Salva esito appuntamento'),
          ),
        ],
      ),
    );
  }
}
