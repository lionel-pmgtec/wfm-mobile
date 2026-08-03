// Wizard "Genera OdL da Avviso".
// 3 step: tipo ordine → dati operativi → conferma.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../domain/entities/entities.dart';
import '../../../providers/anagrafica_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/avvisi_provider.dart';
import '../../../providers/creation_provider.dart';
import '../../../widgets/sync_widgets.dart';

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

  // Nessun catalogo hardcoded: tipi OdL / attività PM / cicli dal cruscotto.
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
        ref.watch(workOrderTypesProvider).when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) =>
                  _catalogInfo('Impossibile caricare i tipi OdL dal cruscotto.'),
              data: (types) {
                if (types.isEmpty) {
                  return _catalogInfo(
                      'Nessun tipo OdL ricevuto dal cruscotto.');
                }
                return Column(
                  children: types.map((t) {
                    final selected = _woType == t.code;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => setState(() => _woType = t.code),
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
                            Icon(_typeIcon(t), color: AppColors.primary, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(t.code,
                                      style: AppTextStyles.headingSmall
                                          .copyWith(color: AppColors.primary)),
                                  const SizedBox(height: 2),
                                  Text(t.label,
                                      style: AppTextStyles.bodyMedium),
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
                  }).toList(),
                );
              },
            ),
      ],
    );
  }

  IconData _typeIcon(WorkOrderTypeOption t) {
    switch ((t.category ?? t.code).toUpperCase()) {
      case 'ATTI':
        return Icons.lock_open_rounded;
      case 'DISA':
        return Icons.block_rounded;
      case 'ZA01':
        return Icons.water_drop_outlined;
      case 'ZA02':
        return Icons.opacity_outlined;
      case 'SOST':
        return Icons.swap_horiz_rounded;
      case 'PA':
        return Icons.description_outlined;
      default:
        return Icons.category_rounded;
    }
  }

  Widget _catalogInfo(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        const Icon(Icons.cloud_off_rounded,
            size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Expanded(
            child: Text(message,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary))),
      ]),
    );
  }

  Widget _catalogDropdown({
    required String label,
    required AsyncValue<List<CodeLabel>> async,
    required String? value,
    required ValueChanged<String?> onChanged,
  }) {
    return async.when(
      loading: () => InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: const SizedBox(
            height: 18,
            child: Center(
                child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2)))),
      ),
      error: (_, __) => _catalogInfo('$label: errore dal cruscotto'),
      data: (items) {
        if (items.isEmpty) {
          return _catalogInfo('$label: nessun dato dal cruscotto');
        }
        final v = items.any((e) => e.code == value) ? value : null;
        return DropdownButtonFormField<String>(
          initialValue: v,
          isExpanded: true,
          decoration: InputDecoration(labelText: label),
          items: items
              .map((e) => DropdownMenuItem(
                    value: e.code,
                    child: Text('${e.code} — ${e.label}',
                        overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: onChanged,
        );
      },
    );
  }

  Widget _step2Details() {
    return ListView(
      padding: kPagePadding,
      children: [
        const SectionHeader(title: 'ATTIVITÀ'),
        _catalogDropdown(
          label: 'Tipo attività PM *',
          async: ref.watch(lookupProvider('pm-activities')),
          value: _tipoAttivita,
          onChanged: (v) => setState(() => _tipoAttivita = v),
        ),
        const SizedBox(height: 12),
        _catalogDropdown(
          label: 'Ciclo di Lavoro',
          async: ref.watch(lookupProvider('work-cycles')),
          value: _ciclo,
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
          child: const Row(children: const [
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
    // Step finale: genera un OdL sul tablet a partire dall'avviso (local-first).
    // Resta locale finché l'operatore non sincronizza verso il cruscotto.
    final utente = ref.read(authControllerProvider.notifier).user;
    final cid = utente?.cid ?? '';
    final creatore =
        utente == null ? 'wfm.mobile' : '${utente.fullName} ($cid)';
    final now = DateTime.now();
    final code = ref.read(creationControllerProvider).newWorkOrderId();
    final note = [
      _noteCtrl.text.trim(),
      if (_tipoAttivita != null) 'Attività PM: $_tipoAttivita',
      if (_ciclo != null) 'Ciclo: $_ciclo',
    ].where((s) => s.isNotEmpty).join('\n');
    final order = WorkOrder(
      externalCode: code,
      notificationNumberSap: a.numeroAvviso as String,
      avvisoOrigine: a.numeroAvviso as String,
      woType: _woType!,
      woTypeDescription: _descCtrl.text.trim(),
      tam: _woType!,
      status: WorkOrderStatus.ricevuto,
      priorita: 'Media',
      creatoDa: creatore,
      appointmentDate: now,
      appointmentStartTime: '08:00',
      address: a.address as Address,
      customer: a.customer as Customer,
      referente: (a.referente as String?) ?? (a.customer as Customer).fullName,
      telefonoCliente:
          (a.cellulare as String?) ?? (a.customer as Customer).telefono,
      sedeTecnica: (a.sedeTecnica as String?) ?? '',
      notes: note,
      cidAssegnato: cid,
      createdAt: now,
      localStatus: LocalSyncStatus.pendingUpload,
    );
    await ref.read(creationControllerProvider).addWorkOrder(order);
    if (!mounted) return;

    // Conferma con invio proposto subito, senza tornare alla Home.
    await showCreatedSyncDialog(
      context,
      ref,
      title: 'Ordine generato',
      message: 'L\'ordine creato dall\'avviso ${widget.numero} è salvato sul '
          'tablet. Vuoi inviarlo subito al cruscotto?',
    );
    if (!mounted) return;
    context.pushReplacement(AppRoutes.workOrderDetailPath(code));
  }
}
