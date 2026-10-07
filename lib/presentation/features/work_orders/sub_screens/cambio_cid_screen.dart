// Cambio CID : riassegna l'OdL a un altro tecnico.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../widgets/odl_actions_menu.dart';
import '../../../../domain/entities/entities.dart';
import '../../../providers/anagrafica_provider.dart';
import '../../../providers/creation_provider.dart';
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
      appBar: AppBar(title: const Text('Cambio CID'), actions: [OdlActionsMenu(code: widget.code, scope: OdlMenuScope.cambioCid)]),
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
        // OdL non ancora inviato con un collega già scelto: passerà a lui.
        if (order.assegnaA != null) ...[
          const SizedBox(height: 12),
          FieldRow(
              label: "Da passare a (all'invio)", value: order.assegnaA!),
        ],
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
        ref.watch(techniciansProvider('')).when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              error: (_, __) => const Text('Elenco tecnici non disponibile',
                  style: AppTextStyles.bodySmall),
              data: (techs) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: techs
                    .where((t) =>
                        t.cid != (order.assegnaA ?? order.cidAssegnato))
                    .map((t) => ActionChip(
                          avatar: const Icon(Icons.person_outline, size: 16),
                          label: Text('${t.cid} — ${t.fullName}'),
                          onPressed: () =>
                              setState(() => _cidCtrl.text = t.cid),
                        ))
                    .toList(),
              ),
            ),
        const SizedBox(height: 16),
        TextField(
          controller: _motivoCtrl,
          maxLines: 3,
          decoration: InputDecoration(
              labelText: 'Motivo (facoltativo)',
              alignLabelWithHint: true,
              hintText: 'Es. tecnico in ferie, competenza specifica…',
              suffixIcon: VoiceSuffixIcons(controller: _motivoCtrl)),
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
    // Per un OdL non ancora inviato con un collega già scelto, il "corrente"
    // è il collega: si può tornare a sé stessi.
    if (newCid == (order.assegnaA ?? order.cidAssegnato)) {
      showSapToast(context, 'CID identico al corrente', isError: true);
      return;
    }
    // OdL creato qui e non ancora inviato: il passaggio avverrà all'invio.
    final inAttesa =
        await ref.read(isPendingCreationProvider(order.externalCode).future);
    if (!mounted) return;
    final ok = await showWfmConfirmDialog(
      context: context,
      title: 'Conferma riassegnazione',
      message: inAttesa
          ? 'L\'OdL ${order.externalCode} non è ancora sul cruscotto: '
              'passerà a "$newCid" appena lo invii.'
          : 'Riassegnare l\'OdL ${order.externalCode} a "$newCid"? L\'OdL non sarà più visibile su questo tablet.',
      confirmLabel: 'Riassegna',
      cancelLabel: 'Annulla',
      tone: WfmDialogTone.warning,
      icon: Icons.swap_horiz_rounded,
    );
    if (ok != true || !mounted) return;
    setState(() => _saving = true);
    final motivo = _motivoCtrl.text.trim();
    final res = await ref.read(workOrderActionsProvider).reassign(
        order.externalCode, newCid,
        note: motivo.isEmpty ? null : motivo);
    if (!mounted) return;
    setState(() => _saving = false);
    res.when(
      success: (esito) {
        switch (esito) {
          case EsitoRiassegnazione.passato:
            showSapToast(
                context, 'OdL ${order.externalCode} riassegnato a $newCid');
            // L'OdL non è più di questo tablet: si torna alla lista.
            context.go(AppRoutes.workOrders);
          case EsitoRiassegnazione.allInvio:
            showSapToast(context,
                'OdL ${order.externalCode}: passerà a $newCid appena inviato al cruscotto');
            context.pop();
          case EsitoRiassegnazione.resta:
            showSapToast(
                context, 'OdL ${order.externalCode}: resta assegnato a te');
            context.pop();
        }
      },
      // Messaggio del backend: tecnico inesistente, lavoro chiuso, già
      // inviato a SAP, rete assente…
      failure: (f) => showSapToast(context, f.message, isError: true),
    );
  }
}
