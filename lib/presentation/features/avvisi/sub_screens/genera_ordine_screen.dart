// Wizard "Genera OdL da Avviso".
// 3 step: tipo ordine → dati operativi → conferma.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../providers/avvisi_provider.dart';

class GeneraOrdineScreen extends ConsumerStatefulWidget {
  final String numero;
  const GeneraOrdineScreen({super.key, required this.numero});

  @override
  ConsumerState<GeneraOrdineScreen> createState() =>
      _GeneraOrdineScreenState();
}

class _GeneraOrdineScreenState extends ConsumerState<GeneraOrdineScreen> {
  int _step = 0;

  // Step 1
  String? _woType;
  // Step 2
  String? _tipoAttivita;
  String? _ciclo;
  final _descCtrl = TextEditingController();
  final _altroBpCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  // Tipi OdL ammessi (spec aziendale).
  static const _woTypes = [
    ('ATTI', 'Attivazione fornitura', Icons.lock_open_rounded),
    ('DISA', 'Disattivazione fornitura', Icons.block_rounded),
    ('ZA01', 'Manutenzione servizio idrico', Icons.water_drop_outlined),
    ('ZA02', 'Manutenzione acqua', Icons.opacity_outlined),
    ('PA', 'Generazione preventivo', Icons.description_outlined),
  ];
  static const _attivita = [
    'ADS — Apertura disco',
    'CHS — Chiusura sigillo',
    'LET — Lettura periodica',
    'RIP — Riparazione',
    'VER — Verifica',
    'EMG — Emergenza',
  ];
  static const _cicli = ['STD-001', 'STD-002', 'RAP-010', 'EMG-030'];

  @override
  void dispose() {
    _descCtrl.dispose();
    _altroBpCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(avvisoDetailProvider(widget.numero));
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Genera OdL da avviso'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(8),
          child: LinearProgressIndicator(
            value: (_step + 1) / 3,
            backgroundColor: Colors.white24,
            valueColor:
                const AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      ),
      body: async.when(
        loading: () => const WfmLoading(),
        error: (e, _) => WfmErrorState(message: e.toString()),
        data: (a) {
          // Pre-popola dalla descrizione avviso al primo build.
          if (_descCtrl.text.isEmpty) _descCtrl.text = a.descrizione;
          return Column(children: [
            Expanded(
              child: IndexedStack(
                index: _step,
                children: [
                  _step1Type(a.numeroAvviso),
                  _step2Details(),
                  _step3Confirm(a),
                ],
              ),
            ),
            _navBar(a),
          ]);
        },
      ),
    );
  }

  Widget _step1Type(String numero) {
    return ListView(
      padding: kPagePadding,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primarySurface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            const Icon(Icons.info_outline, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Genera un OdL a partire dall\'avviso $numero.',
                  style: AppTextStyles.bodyMedium),
            ),
          ]),
        ),
        const SectionHeader(title: 'TIPO ORDINE'),
        ..._woTypes.map((t) {
          final selected = _woType == t.$1;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => setState(() => _woType = t.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary.withValues(alpha: 0.08)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: selected
                          ? AppColors.primary
                          : AppColors.border,
                      width: selected ? 1.5 : 1),
                ),
                child: Row(children: [
                  Icon(t.$3, color: AppColors.primary, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.$1,
                            style: AppTextStyles.headingSmall
                                .copyWith(color: AppColors.primary)),
                        const SizedBox(height: 2),
                        Text(t.$2, style: AppTextStyles.bodyMedium),
                      ],
                    ),
                  ),
                  if (selected)
                    const Icon(Icons.check_circle,
                        color: AppColors.primary),
                ]),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _step2Details() {
    return ListView(
      padding: kPagePadding,
      children: [
        const SectionHeader(title: 'ATTIVITÀ'),
        DropdownButtonFormField<String>(
          initialValue: _tipoAttivita,
          isExpanded: true,
          decoration:
              const InputDecoration(labelText: 'Tipo attività PM *'),
          items: _attivita
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: (v) => setState(() => _tipoAttivita = v),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _ciclo,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Ciclo di Lavoro'),
          items: _cicli
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (v) => setState(() => _ciclo = v),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _descCtrl,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Descrizione *'),
        ),
        const SectionHeader(title: 'PARTI'),
        TextField(
          controller: _altroBpCtrl,
          decoration: const InputDecoration(labelText: 'Altro BP'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _noteCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
              labelText: 'Note', alignLabelWithHint: true),
        ),
      ],
    );
  }

  Widget _step3Confirm(a) {
    return ListView(
      padding: kPagePadding,
      children: [
        const SectionHeader(title: 'RIEPILOGO'),
        FormGrid(children: [
          FieldRow(label: 'Avviso origine', value: a.numeroAvviso),
          FieldRow(label: 'Tipo ordine', value: _woType ?? '—'),
          FieldRow(label: 'Tipo attività', value: _tipoAttivita ?? '—'),
          FieldRow(label: 'Ciclo lavoro', value: _ciclo ?? '—'),
        ]),
        const SizedBox(height: 12),
        FieldRow(label: 'Descrizione', value: _descCtrl.text, fullWidth: true),
        const SectionHeader(title: 'DATI PRE-COMPILATI'),
        FormGrid(children: [
          FieldRow(label: 'Cliente', value: a.customer.fullName, hideIfEmpty: true),
          FieldRow(label: 'Indirizzo', value: a.address.full, fullWidth: true),
          FieldRow(label: 'Notifica precedente', value: a.numeroAvviso),
        ]),
        const SizedBox(height: 12),
        if (_altroBpCtrl.text.isNotEmpty)
          FieldRow(label: 'Altro BP', value: _altroBpCtrl.text),
        if (_noteCtrl.text.isNotEmpty)
          FieldRow(label: 'Note', value: _noteCtrl.text, fullWidth: true),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.accentGreen.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: const [
            Icon(Icons.check_circle_outline, color: AppColors.accentGreen),
            SizedBox(width: 8),
            Expanded(
              child: Text('Verifica i dati e conferma la creazione dell\'OdL.',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.accentGreen)),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _navBar(dynamic a) {
    return Material(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          if (_step > 0)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _step--),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Indietro'),
              ),
            ),
          if (_step > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _canProceed() ? () => _next(a) : null,
              icon: Icon(_step == 2
                  ? Icons.send_rounded
                  : Icons.arrow_forward),
              label:
                  Text(_step == 2 ? 'Crea OdL' : 'Avanti'),
            ),
          ),
        ]),
      ),
    );
  }

  bool _canProceed() {
    if (_step == 0) return _woType != null;
    if (_step == 1) {
      return _tipoAttivita != null && _descCtrl.text.trim().isNotEmpty;
    }
    return true;
  }

  Future<void> _next(dynamic a) async {
    if (_step < 2) {
      setState(() => _step++);
      return;
    }
    // Step finale: crea OdL
    final res = await ref.read(generateWorkOrderProvider)(widget.numero);
    if (!mounted) return;
    res.when(
      success: (wo) {
        showSapToast(
            context, 'OdL ${wo.externalCode} creato da avviso ${widget.numero}');
        context.go(AppRoutes.workOrderDetailPath(wo.externalCode));
      },
      failure: (f) => showSapToast(context, f.message, isError: true),
    );
  }
}
