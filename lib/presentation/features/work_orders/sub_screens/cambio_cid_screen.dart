// Cambio CID : riassegna l'OdL a un altro tecnico.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../domain/entities/entities.dart';
import '../../../providers/work_orders_provider.dart';

class CambioCidScreen extends ConsumerStatefulWidget {
  final String code;
  const CambioCidScreen({super.key, required this.code});

  @override
  ConsumerState<CambioCidScreen> createState() => _CambioCidScreenState();
}

class _CambioCidScreenState extends ConsumerState<CambioCidScreen> {
  final _cidCtrl = TextEditingController();
  final _motivoCtrl = TextEditingController();
  bool _saving = false;

  // Lista di tecnici "trovati" (mock; in produzione = ricerca SAP).
  static const _suggestedTechs = [
    'VAIOTTIM — Vaiotti M.',
    'ROSSIPAO — Rossi P.',
    'BIANCRG — Bianchi R.G.',
    'TECN001 — Tecnico Standard',
    'TECN002 — Tecnico Senior',
  ];

  @override
  void dispose() {
    _cidCtrl.dispose();
    _motivoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(workOrderDetailProvider(widget.code));
    return Scaffold(
      appBar: AppBar(title: const Text('Cambio CID')),
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
        const SectionHeader(title: 'ORDINE DI LAVORO'),
        FieldRow(label: 'Numero ordine', value: order.externalCode),
        const SizedBox(height: 12),
        FieldRow(
            label: 'Descrizione', value: order.woTypeDescription, fullWidth: true),
        const SizedBox(height: 12),
        FieldRow(label: 'CID corrente', value: order.cidAssegnato ?? '—'),
        const SectionHeader(title: 'NUOVO CID'),
        TextField(
          controller: _cidCtrl,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Codice tecnico (CID) *',
            prefixIcon: Icon(Icons.person_search_outlined),
            hintText: 'es. VAIOTTIM',
          ),
        ),
        const SizedBox(height: 12),
        Text('Suggerimenti', style: AppTextStyles.labelMedium),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _suggestedTechs.map((s) {
            final code = s.split(' — ').first;
            return ActionChip(
              avatar: const Icon(Icons.person_outline, size: 16),
              label: Text(s),
              onPressed: () => setState(() => _cidCtrl.text = code),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _motivoCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
              labelText: 'Motivo (facoltativo)',
              alignLabelWithHint: true,
              hintText: 'Es. tecnico in ferie, competenza specifica…'),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _saving ? null : () => _submit(order),
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.swap_horiz_rounded),
          label: Text(_saving ? 'Invio…' : 'Riassegna OdL'),
        ),
      ],
    );
  }

  Future<void> _submit(WorkOrder order) async {
    final newCid = _cidCtrl.text.trim().toUpperCase();
    if (newCid.isEmpty) {
      showSapToast(context, 'Inserire un CID valido', isError: true);
      return;
    }
    if (newCid == order.cidAssegnato) {
      showSapToast(context, 'CID identico al corrente', isError: true);
      return;
    }
    final ok = await showWfmConfirmDialog(
      context: context,
      title: 'Conferma riassegnazione',
      message:
          'Riassegnare l\'OdL ${order.externalCode} a "$newCid"? L\'OdL non sarà più visibile su questo tablet.',
      confirmLabel: 'Riassegna',
      cancelLabel: 'Annulla',
      tone: WfmDialogTone.warning,
      icon: Icons.swap_horiz_rounded,
    );
    if (ok != true || !mounted) return;
    setState(() => _saving = true);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() => _saving = false);
    showSapToast(context, 'OdL ${order.externalCode} riassegnato a $newCid');
    // Navigazione: torna 2 livelli (cambio-cid + detail) → lista OdL.
    context.go('/work-orders');
  }
}
