// Esito Appuntamento — flussi D58/D59 verso Cruscotto.
// Diverso dall'esito tecnico : qui si registra l'esito del singolo sopralluogo.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../providers/anagrafica_provider.dart';
import '../../../providers/appointments_provider.dart';
import '../widgets/odl_actions_menu.dart';

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

  // Dominio SAP fisso dell'esito appuntamento (flussi D58/D59): non è un
  // catalogo anagrafico, è l'insieme chiuso dei codici di esito. Il backend
  // non espone un lookup per questi valori.
  static const _esitoOptions = [
    ('OK', 'OK — Esito positivo', AppColors.accentGreen),
    ('NO', 'NO — Esito negativo', AppColors.accentRed),
    ('ER', 'ER — Errore inserimento', AppColors.accentOrange),
    ('MN', 'MN — Mancato accesso', AppColors.statusSuspended),
  ];

  String? _esito;
  final _ritiroCtrl = TextEditingController();
  final _motivoCtrl = TextEditingController();
  String? _causaCode; // codice dal catalogo backend (/anagrafica/causes)
  final _causaRitardoCtrl = TextEditingController();
  final _motivoRitardoCtrl = TextEditingController();
  bool _dispAnticipazione = false;
  bool _presenzaCliente = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Ricarica l'esito salvato in precedenza per questo OdL (se presente).
    final saved = ref.read(esitoAppuntamentoProvider(widget.code));
    if (saved != null) {
      _dataSopralluogo = saved.dataSopralluogo;
      _oraSopralluogo = saved.oraSopralluogo;
      _esito = saved.esito;
      _ritiroCtrl.text = saved.ritiro;
      _motivoCtrl.text = saved.motivo;
      _causaCode = saved.causaCode;
      _causaRitardoCtrl.text = saved.causaRitardo;
      _motivoRitardoCtrl.text = saved.motivoRitardo;
      _dispAnticipazione = saved.dispAnticipazione;
      _presenzaCliente = saved.presenzaCliente;
    }
  }

  @override
  void dispose() {
    _ritiroCtrl.dispose();
    _motivoCtrl.dispose();
    _causaRitardoCtrl.dispose();
    _motivoRitardoCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_esito == null) {
      showSapToast(context, 'Selezionare l\'esito dell\'appuntamento',
          isError: true);
      return;
    }
    setState(() => _saving = true);
    // Salvataggio reale in locale (il backend non espone ancora la rotta).
    ref.read(esitoAppuntamentoProvider(widget.code).notifier).save(
          EsitoAppuntamentoData(
            dataSopralluogo: _dataSopralluogo,
            oraSopralluogo: _oraSopralluogo,
            esito: _esito!,
            ritiro: _ritiroCtrl.text.trim(),
            motivo: _motivoCtrl.text.trim(),
            causaCode: _causaCode,
            causaRitardo: _causaRitardoCtrl.text.trim(),
            motivoRitardo: _motivoRitardoCtrl.text.trim(),
            dispAnticipazione: _dispAnticipazione,
            presenzaCliente: _presenzaCliente,
          ),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    showSapToast(context, 'Esito appuntamento salvato sul dispositivo');
    context.pop();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Esito appuntamento'), actions: [OdlActionsMenu(code: widget.code, scope: OdlMenuScope.esitoAppuntamento)]),
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
          TextField(
            controller: _ritiroCtrl,
            decoration: const InputDecoration(labelText: 'Ritiro'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _motivoCtrl,
            decoration: const InputDecoration(labelText: 'Motivo (testo libero)'),
          ),
          const SizedBox(height: 12),
          // "Causa" dal catalogo reale del backend (/anagrafica/causes) —
          // niente più valori inventati.
          ref.watch(causeCodesProvider).when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Errore cause: $e',
                    style: AppTextStyles.bodySmall),
                data: (list) => DropdownButtonFormField<String>(
                  initialValue: _causaCode,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Causa'),
                  items: list
                      .map((c) => DropdownMenuItem(
                          value: c.code,
                          child: Text(c.label,
                              overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (v) => setState(() => _causaCode = v),
                ),
              ),
          const SizedBox(height: 12),
          TextField(
            controller: _causaRitardoCtrl,
            decoration: const InputDecoration(labelText: 'Causa ritardo'),
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
                : const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Salvataggio…' : 'Salva esito appuntamento'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
