// Copia Ordine / Aggiunta Template Ordine.
// Pre-popola un nuovo OdL a partire dai dati dell'OdL corrente.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../widgets/odl_actions_menu.dart';
import '../../../../domain/entities/entities.dart';
import '../../../providers/anagrafica_provider.dart';
import '../../../providers/work_orders_provider.dart';

class CopiaOrdineScreen extends ConsumerStatefulWidget {
  final String code;
  const CopiaOrdineScreen({super.key, required this.code});

  @override
  ConsumerState<CopiaOrdineScreen> createState() => _CopiaOrdineScreenState();
}

class _CopiaOrdineScreenState extends ConsumerState<CopiaOrdineScreen> {
  // Nessun catalogo hardcoded: tipo ordine / attività PM / ciclo di lavoro
  // arrivano dal cruscotto. Le selezioni conservano il CODICE.
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
      _selectedType = order.woType; // il dropdown lo aggancia quando carica
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
      appBar: AppBar(title: const Text('Copia ordine'), actions: [OdlActionsMenu(code: widget.code)]),
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
        _catalogDropdown(
          label: 'Tipo ordine *',
          async: ref.watch(workOrderTypesProvider).whenData(
              (l) => l.map((t) => CodeLabel(t.code, t.label)).toList()),
          value: _selectedType,
          onChanged: (v) => setState(() => _selectedType = v),
        ),
        const SizedBox(height: 12),
        _catalogDropdown(
          label: 'Tipo attività PM *',
          async: ref.watch(lookupProvider('pm-activities')),
          value: _selectedActivity,
          onChanged: (v) => setState(() => _selectedActivity = v),
        ),
        const SizedBox(height: 12),
        _catalogDropdown(
          label: 'Ciclo di Lavoro',
          async: ref.watch(lookupProvider('work-cycles')),
          value: _selectedCiclo,
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

  /// Dropdown alimentata dal cruscotto (niente valori hardcoded).
  /// Mostra il caricamento e un riquadro "nessun dato dal cruscotto" se vuoto.
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
      error: (_, __) => _catalogEmpty(label, 'Errore dal cruscotto'),
      data: (items) {
        if (items.isEmpty) {
          return _catalogEmpty(label, 'Nessun dato dal cruscotto');
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

  Widget _catalogEmpty(String label, String message) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: Row(children: [
        const Icon(Icons.cloud_off_rounded,
            size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
            child: Text(message,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary))),
      ]),
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
