// Copia Ordine / Aggiunta Template Ordine.
// Pre-popola un nuovo OdL a partire dai dati dell'OdL corrente.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../domain/entities/entities.dart';
import '../../../providers/work_orders_provider.dart';

class CopiaOrdineScreen extends ConsumerStatefulWidget {
  final String code;
  const CopiaOrdineScreen({super.key, required this.code});

  @override
  ConsumerState<CopiaOrdineScreen> createState() => _CopiaOrdineScreenState();
}

class _CopiaOrdineScreenState extends ConsumerState<CopiaOrdineScreen> {
  static const _woTypes = [
    'ATTI — Apertura contatore',
    'SOST — Sostituzione contatore',
    'DISA — Disattivazione fornitura',
    'ZA02 — Riparazione perdita',
    'PA — Preventivo',
  ];
  static const _activities = [
    'ADS — Apertura disco',
    'CHS — Chiusura sigillo',
    'LET — Lettura periodica',
    'RIP — Riparazione',
    'VER — Verifica',
  ];
  static const _cicli = ['STD-001', 'STD-002', 'RAP-010', 'EMG-030'];

  String? _selectedType;
  String? _selectedActivity;
  String? _selectedCiclo;
  final _descCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _altroBpCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Pre-popola con i dati dell'OdL corrente.
    final order = ref.read(workOrderDetailProvider(widget.code)).valueOrNull;
    if (order != null) {
      _selectedType = _woTypes.firstWhere(
        (t) => t.startsWith(order.woType),
        orElse: () => _woTypes.first,
      );
      _descCtrl.text = order.woTypeDescription;
      _noteCtrl.text = order.notes;
    }
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _noteCtrl.dispose();
    _altroBpCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(workOrderDetailProvider(widget.code));
    return Scaffold(
      appBar: AppBar(title: const Text('Copia ordine')),
      body: async.when(
        loading: () => const WfmLoading(),
        error: (e, _) => WfmErrorState(message: e.toString()),
        data: (order) => _form(order),
      ),
    );
  }

  Widget _form(WorkOrder order) {
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
            const Icon(Icons.content_copy_rounded, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Stai duplicando l\'OdL ${order.externalCode}',
                  style: AppTextStyles.bodyMedium),
            ),
          ]),
        ),
        const SectionHeader(title: 'DATI ORDINE'),
        DropdownButtonFormField<String>(
          initialValue: _selectedType,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Tipo ordine *'),
          items: _woTypes
              .map((t) => DropdownMenuItem(value: t, child: Text(t)))
              .toList(),
          onChanged: (v) => setState(() => _selectedType = v),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _selectedActivity,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Tipo attività PM *'),
          items: _activities
              .map((t) => DropdownMenuItem(value: t, child: Text(t)))
              .toList(),
          onChanged: (v) => setState(() => _selectedActivity = v),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _selectedCiclo,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Ciclo di Lavoro'),
          items: _cicli
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (v) => setState(() => _selectedCiclo = v),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _descCtrl,
          decoration: const InputDecoration(labelText: 'Descrizione'),
          maxLines: 2,
        ),
        const SectionHeader(title: 'DATI PRE-COMPILATI (da OdL origine)'),
        FormGrid(children: [
          FieldRow(label: 'Sede tecnica', value: order.sedeTecnica, hideIfEmpty: true),
          FieldRow(label: 'Equipment', value: order.equipment, hideIfEmpty: true),
          FieldRow(
              label: 'CID assegnato', value: order.cidAssegnato ?? '', hideIfEmpty: true),
          FieldRow(label: 'Settore contabile', value: order.accountingSector),
          FieldRow(
              label: 'Cliente (BP)', value: order.customer.fullName, hideIfEmpty: true),
          FieldRow(label: 'Indirizzo', value: order.address.full, fullWidth: true),
          FieldRow(label: 'Notifica precedente',
              value: order.notificationNumberSap ?? '', hideIfEmpty: true),
        ]),
        const SectionHeader(title: 'CAMPI AGGIUNTIVI'),
        TextField(
          controller: _altroBpCtrl,
          decoration: const InputDecoration(
              labelText: 'Altro BP (facoltativo)',
              hintText: 'Codice business partner alternativo'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _noteCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
              labelText: 'Note', alignLabelWithHint: true),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _saving ? null : () => _confirm(order),
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child:
                      CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.send_rounded),
          label: Text(_saving ? 'Invio…' : 'Crea copia'),
        ),
      ],
    );
  }

  Future<void> _confirm(WorkOrder order) async {
    if (_selectedType == null || _selectedActivity == null) {
      showSapToast(context,
          'Selezionare tipo ordine e tipo attività', isError: true);
      return;
    }
    final ok = await showWfmConfirmDialog(
      context: context,
      title: 'Conferma copia',
      message:
          'Verrà creato un nuovo OdL basato su ${order.externalCode}. Procedere?',
      confirmLabel: 'Crea',
      cancelLabel: 'Annulla',
      tone: WfmDialogTone.primary,
      icon: Icons.content_copy_rounded,
    );
    if (ok != true || !mounted) return;
    setState(() => _saving = true);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() => _saving = false);
    showSapToast(context, 'Copia OdL accodata per invio');
    context.pop();
  }
}
