// Schermata Esito intervento (M5): tecnico + economico + validazione finale.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';
import '../../../core/utils/validators.dart';
import '../../providers/anagrafica_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/esito_provider.dart';
import '../../providers/work_orders_provider.dart';

class EsitoScreen extends ConsumerStatefulWidget {
  final String code;
  const EsitoScreen({super.key, required this.code});

  @override
  ConsumerState<EsitoScreen> createState() => _EsitoScreenState();
}

class _EsitoScreenState extends ConsumerState<EsitoScreen> {
  final _formKey = GlobalKey<FormState>();
  EsitoResult? _result;
  String? _causeCode;
  String? _solutionCode;
  final _notesCtrl = TextEditingController();
  final _hoursCtrl = TextEditingController(text: '1.0');
  final _extraCtrl = TextEditingController();
  final _finalReadingCtrl = TextEditingController();
  final _sealCtrl = TextEditingController();
  bool _customerSigned = false;
  bool _submitting = false;
  final DateTime _start = DateTime.now().subtract(const Duration(minutes: 45));

  @override
  void dispose() {
    _notesCtrl.dispose();
    _hoursCtrl.dispose();
    _extraCtrl.dispose();
    _finalReadingCtrl.dispose();
    _sealCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_result == null) {
      showSapToast(context, 'Selezionare un esito', isError: true);
      return;
    }
    setState(() => _submitting = true);
    final cid = ref.read(authControllerProvider.notifier).user?.cid ?? 'TEC001';
    final order = ref.read(workOrderDetailProvider(widget.code)).valueOrNull;

    // DISA: registra la lettura finale del contatore nell'esito.
    final readings = <MeterReading>[];
    if ((order?.hasDisattivazione ?? false) &&
        order?.meter != null &&
        _finalReadingCtrl.text.trim().isNotEmpty) {
      readings.add(MeterReading(
        matricola: order!.meter!.matricola,
        previousReading: order.meter!.lastReading,
        readingValue:
            num.tryParse(_finalReadingCtrl.text.replaceAll(',', '.')) ?? 0,
        readingDateTime: DateTime.now(),
      ));
    }

    final esito = Esito(
      workOrderCode: widget.code,
      technicianCid: cid,
      startDateTime: _start,
      endDateTime: DateTime.now(),
      result: _result,
      causeCode: _causeCode,
      solutionCode: _solutionCode,
      notes: _notesCtrl.text,
      meterReadings: readings,
      hoursWorked: [
        HoursWorked(
            technicianCid: cid,
            hours: num.tryParse(_hoursCtrl.text.replaceAll(',', '.')) ?? 0),
      ],
      extraCosts: num.tryParse(_extraCtrl.text.replaceAll(',', '.')),
      customerSigned: _customerSigned,
    );
    final res = await ref.read(esitoControllerProvider).submit(esito);
    if (!mounted) return;
    setState(() => _submitting = false);
    res.when(
      success: (status) {
        showSapToast(context,
            status == 'PENDING' ? 'Esito in coda (offline)' : 'Esito inviato');
        context.go('/work-orders');
      },
      failure: (f) => showSapToast(context, f.message, isError: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final causes = ref.watch(causeCodesProvider);
    final solutions = ref.watch(solutionCodesProvider);
    final order = ref.watch(workOrderDetailProvider(widget.code)).valueOrNull;
    final isDisa = order?.hasDisattivazione ?? false;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
          title: Text(isDisa
              ? 'Esito Disattivazione ${widget.code}'
              : 'Esito OdL ${widget.code}')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: kPagePadding,
          children: [
            const SectionHeader(title: 'TEMPI INTERVENTO'),
            FormGrid(children: [
              FieldRow(label: 'Inizio', value: Fmt.dateTime(_start)),
              FieldRow(label: 'Fine', value: Fmt.dateTime(DateTime.now())),
            ]),
            const SectionHeader(title: 'ESITO'),
            Row(
              children: EsitoResult.values.map((r) {
                final selected = _result == r;
                final color = switch (r) {
                  EsitoResult.success => AppColors.accentGreen,
                  EsitoResult.rinviato => AppColors.accentOrange,
                  EsitoResult.impossibile => AppColors.accentRed,
                };
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(r.label),
                      selected: selected,
                      selectedColor: color.withValues(alpha: 0.18),
                      labelStyle: TextStyle(
                          color: selected ? color : AppColors.textSecondary,
                          fontWeight: FontWeight.w600),
                      onSelected: (_) => setState(() => _result = r),
                    ),
                  ),
                );
              }).toList(),
            ),
            if (isDisa) ...[
              const SectionHeader(title: 'DISATTIVAZIONE FORNITURA'),
              if (order?.meter != null)
                FieldRow(
                    label: 'Matricola contatore',
                    value: order!.meter!.matricola),
              const SizedBox(height: 12),
              FieldRow(
                  label: 'Lettura precedente',
                  value: order?.meter?.lastReading?.toString() ?? '0'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _finalReadingCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Lettura finale contatore *'),
                validator: (v) => Validators.meterReading(v,
                    previous: order?.meter?.lastReading),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _sealCtrl,
                decoration:
                    const InputDecoration(labelText: 'Numero sigillo'),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: AppColors.statusReceivedBg,
                    borderRadius: BorderRadius.circular(8)),
                child: const Row(children: [
                  Icon(Icons.info_outline, size: 18, color: AppColors.primary),
                  SizedBox(width: 8),
                  Expanded(
                      child: Text(
                          'Seleziona «Riuscito» per confermare la disattivazione, «Impossibile» in caso negativo.',
                          style: AppTextStyles.bodySmall)),
                ]),
              ),
            ],
            const SectionHeader(title: 'CAUSA E SOLUZIONE'),
            causes.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Errore: $e', style: AppTextStyles.bodySmall),
              data: (list) => DropdownButtonFormField<String>(
                initialValue: _causeCode,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Motivo intervento'),
                items: list
                    .map((c) => DropdownMenuItem(
                        value: c.code, child: Text(c.label, overflow: TextOverflow.ellipsis)))
                    .toList(),
                validator: (v) => v == null ? 'Selezionare un motivo' : null,
                onChanged: (v) => setState(() => _causeCode = v),
              ),
            ),
            const SizedBox(height: 12),
            solutions.when(
              loading: () => const SizedBox.shrink(),
              error: (e, _) => const SizedBox.shrink(),
              data: (list) => DropdownButtonFormField<String>(
                initialValue: _solutionCode,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Soluzione fornita'),
                items: list
                    .map((c) => DropdownMenuItem(
                        value: c.code, child: Text(c.label, overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (v) => setState(() => _solutionCode = v),
              ),
            ),
            const SectionHeader(title: 'ANALISI ECONOMICA'),
            FormGrid(children: [
              TextFormField(
                controller: _hoursCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Ore lavorate'),
              ),
              TextFormField(
                controller: _extraCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Costi extra (€)'),
              ),
            ]),
            const SectionHeader(title: 'COMMENTI'),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                  labelText: 'Commenti liberi', alignLabelWithHint: true),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Firma cliente acquisita'),
              value: _customerSigned,
              onChanged: (v) => setState(() => _customerSigned = v),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded),
                label: Text(_submitting ? 'Invio…' : 'Convalida e invia esito'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
