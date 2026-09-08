// Sezioni inline editabili da inserire nel Dettaglio OdL :
//   • APPUNTAMENTI (CRUD inline)
//   • PREVENTIVO (summary + apri/crea)
//
// ATTIVITÀ e SOSPENSIONI rimosse: erano solo locali (Hive), il backend non le
// espone/persiste (nessun endpoint).
// Le firme (cliente + operatore) sono raccolte sul Preventivo, non qui.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../domain/entities/entities.dart';
import '../../../providers/avviso_extension_provider.dart';
import '../../../providers/odl_extension_provider.dart';
import '../../avvisi/widgets/wfm_collapsible_section.dart';

class OdlInlineSections extends ConsumerWidget {
  final WorkOrder order;
  const OdlInlineSections({super.key, required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = order.externalCode;
    final ext = ref.watch(odlExtensionProvider(code));
    final hasAvviso = (order.notificationNumberSap ?? '').isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ATTIVITÀ e SOSPENSIONI rimosse: erano solo locali (Hive), nessun
        // endpoint backend le persiste. Restano APPUNTAMENTI e PREVENTIVO.
        WfmCollapsibleSection(
          title: 'APPUNTAMENTI',
          icon: Icons.event_outlined,
          badge: ext.appuntamenti.isEmpty
              ? null
              : ext.appuntamenti.length.toString(),
          initiallyExpanded: false,
          child: _AppuntamentiInline(odlCode: code, ext: ext),
        ),
        if (hasAvviso || order.hasPreventivo)
          WfmCollapsibleSection(
            title: 'PREVENTIVO',
            icon: Icons.description_outlined,
            initiallyExpanded: order.hasPreventivo,
            child: _PreventivoSummary(
              // Preventivo INDIPENDENTE per OdL: chiave = codice OdL, così il
              // preventivo (e la sua firma) non è condiviso con l'Avviso di
              // origine né con altri OdL. Un nuovo OdL parte senza firma.
              preventivoKey: code,
            ),
          ),
        // La firma del preventivo è solo del preventivo (per il PDF del devis);
        // la firma di chiusura dell'OdL è separata (esito).
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// APPUNTAMENTI
// ═══════════════════════════════════════════════════════════════════════

class _AppuntamentiInline extends ConsumerWidget {
  final String odlCode;
  final OdlExtension ext;
  const _AppuntamentiInline({required this.odlCode, required this.ext});

  Future<void> _edit(BuildContext context, WidgetRef ref,
      OdlAppuntamento? existing) async {
    final res = await showModalBottomSheet<OdlAppuntamento>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AppuntamentoSheet(existing: existing),
    );
    if (res == null) return;
    final n = ref.read(odlExtensionProvider(odlCode).notifier);
    if (existing == null) {
      await n.addAppuntamento(res);
    } else {
      await n.updateAppuntamento(res);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (ext.appuntamenti.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text('Nessun appuntamento',
                style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: AppColors.textSecondary)),
          )
        else
          for (final a in ext.appuntamenti)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: InkWell(
                onTap: () => _edit(context, ref, a),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(a.modalita.icon,
                            size: 16, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                              '${Fmt.date(a.dataFissata)} ${a.oraFissata}',
                              style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w700)),
                        ),
                        Text(a.modalita.label,
                            style: AppTextStyles.bodySmall),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.delete_outline,
                              size: 16, color: AppColors.accentRed),
                          onPressed: () => ref
                              .read(odlExtensionProvider(odlCode).notifier)
                              .removeAppuntamento(a.id),
                        ),
                      ]),
                      if (a.isEffettuato) ...[
                        const Divider(height: 12),
                        Row(children: [
                          Icon(a.esito!.icon,
                              size: 14, color: a.esito!.color),
                          const SizedBox(width: 6),
                          Text(a.esito!.label,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: a.esito!.color)),
                          const SizedBox(width: 12),
                          if (a.clientePresente)
                            const Icon(Icons.person_outline,
                                size: 14, color: AppColors.accentGreen),
                          if (a.clientePresente)
                            const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Text('Cliente presente',
                                  style: AppTextStyles.bodySmall),
                            ),
                        ]),
                        if ((a.causa ?? '').isNotEmpty ||
                            (a.motivo ?? '').isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                                [a.causa, a.motivo]
                                    .where((s) => (s ?? '').isNotEmpty)
                                    .join(' · '),
                                style: AppTextStyles.bodySmall),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          onPressed: () => _edit(context, ref, null),
          icon: const Icon(Icons.add_circle_outline, size: 16),
          label: const Text('Aggiungi appuntamento'),
        ),
      ],
    );
  }
}

class _AppuntamentoSheet extends StatefulWidget {
  final OdlAppuntamento? existing;
  const _AppuntamentoSheet({this.existing});
  @override
  State<_AppuntamentoSheet> createState() => _AppuntamentoSheetState();
}

class _AppuntamentoSheetState extends State<_AppuntamentoSheet> {
  late DateTime _dataFissata;
  late TextEditingController _oraFissataCtrl;
  late AppuntamentoModalita _modalita;
  AppuntamentoEsito? _esito;
  bool _clientePresente = false;
  late TextEditingController _causaCtrl;
  late TextEditingController _motivoCtrl;
  late TextEditingController _noteCtrl;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _dataFissata = e?.dataFissata ?? DateTime.now();
    _oraFissataCtrl =
        TextEditingController(text: e?.oraFissata ?? '');
    _modalita = e?.modalita ?? AppuntamentoModalita.presenza;
    _esito = e?.esito;
    _clientePresente = e?.clientePresente ?? false;
    _causaCtrl = TextEditingController(text: e?.causa ?? '');
    _motivoCtrl = TextEditingController(text: e?.motivo ?? '');
    _noteCtrl = TextEditingController(text: e?.note ?? '');
  }

  @override
  void dispose() {
    _oraFissataCtrl.dispose();
    _causaCtrl.dispose();
    _motivoCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickData() async {
    final d = await showDatePicker(
        context: context,
        initialDate: _dataFissata,
        firstDate: DateTime(2020),
        lastDate: DateTime(2035));
    if (d != null) setState(() => _dataFissata = d);
  }

  void _save() {
    final a = (widget.existing ??
            OdlAppuntamento(
                id: 'APP-${DateTime.now().millisecondsSinceEpoch}',
                dataFissata: DateTime.now(),
                createdAt: DateTime.now()))
        .copyWith(
      dataFissata: _dataFissata,
      oraFissata: _oraFissataCtrl.text.trim(),
      modalita: _modalita,
      esito: _esito,
      clientePresente: _clientePresente,
      causa: _causaCtrl.text.trim().isEmpty
          ? null
          : _causaCtrl.text.trim(),
      motivo: _motivoCtrl.text.trim().isEmpty
          ? null
          : _motivoCtrl.text.trim(),
      note: _noteCtrl.text.trim(),
      dataEffettuato: _esito != null ? DateTime.now() : null,
    );
    Navigator.pop(context, a);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.backgroundPage,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
                widget.existing == null
                    ? 'Nuovo appuntamento'
                    : 'Modifica appuntamento',
                style: AppTextStyles.headingMedium),
            const SizedBox(height: 12),
            const Text('FISSATO',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.6)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: InkWell(
                  onTap: _pickData,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Data',
                      prefixIcon: Icon(Icons.event_outlined),
                    ),
                    child: Text(Fmt.date(_dataFissata)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _oraFissataCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Ora (HH:mm)',
                    prefixIcon: Icon(Icons.access_time),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            DropdownButtonFormField<AppuntamentoModalita>(
              initialValue: _modalita,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Modalità'),
              items: AppuntamentoModalita.values
                  .map((m) => DropdownMenuItem(
                      value: m,
                      child: Row(children: [
                        Icon(m.icon,
                            size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(m.label),
                      ])))
                  .toList(),
              onChanged: (v) => setState(() => _modalita = v ?? _modalita),
            ),
            const SizedBox(height: 16),
            const Text('EFFETTUATO (opzionale)',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.6)),
            const SizedBox(height: 8),
            DropdownButtonFormField<AppuntamentoEsito?>(
              initialValue: _esito,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Esito'),
              items: [
                const DropdownMenuItem<AppuntamentoEsito?>(
                    value: null, child: Text('— Non ancora —')),
                for (final e in AppuntamentoEsito.values)
                  DropdownMenuItem(
                      value: e,
                      child: Row(children: [
                        Icon(e.icon, size: 16, color: e.color),
                        const SizedBox(width: 8),
                        Text(e.label),
                      ])),
              ],
              onChanged: (v) => setState(() => _esito = v),
            ),
            const SizedBox(height: 10),
            CheckboxListTile(
              value: _clientePresente,
              onChanged: (v) =>
                  setState(() => _clientePresente = v ?? false),
              title: const Text('Cliente presente'),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _causaCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Causa'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _motivoCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Motivo'),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            TextField(
              controller: _noteCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                  labelText: 'Note', alignLabelWithHint: true),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Salva appuntamento'),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// PREVENTIVO COLLEGATO (summary read-only)
// ═══════════════════════════════════════════════════════════════════════

class _PreventivoSummary extends ConsumerWidget {
  final String preventivoKey;
  const _PreventivoSummary({required this.preventivoKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ext = ref.watch(avvisoExtensionProvider(preventivoKey));
    final p = ext.preventivo;
    if (p == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Nessun preventivo per questo OdL.',
              style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: () =>
                context.push(AppRoutes.preventivoPath(preventivoKey)),
            icon: const Icon(Icons.add_circle_outline_rounded),
            label: const Text('Crea preventivo'),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(p.stato.icon, size: 18, color: p.stato.color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
                p.numeroPreventivo.isEmpty ? p.id : p.numeroPreventivo,
                style: AppTextStyles.bodyMedium
                    .copyWith(fontWeight: FontWeight.w700)),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: p.stato.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(p.stato.label,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: p.stato.color)),
          ),
        ]),
        const SizedBox(height: 8),
        _kv('Totale materiali',
            'EUR ${p.totaleMateriali.toStringAsFixed(2)}'),
        if (p.totaleManodopera > 0)
          _kv('Totale manodopera',
              'EUR ${p.totaleManodopera.toStringAsFixed(2)}'),
        if (p.totaleTrasferta > 0)
          _kv('Totale trasferta',
              'EUR ${p.totaleTrasferta.toStringAsFixed(2)}'),
        _kv(
            'IVA ${p.aliquotaIva.toStringAsFixed(0)}%',
            'EUR ${p.importoIva.toStringAsFixed(2)}'),
        const Divider(),
        _kv('TOTALE DOCUMENTO',
            'EUR ${p.totaleConIva.toStringAsFixed(2)}',
            bold: true),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () =>
                context.push(AppRoutes.preventivoPath(preventivoKey)),
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('Apri preventivo'),
          ),
        ),
      ],
    );
  }

  Widget _kv(String k, String v, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Expanded(
              child: Text(k,
                  style: AppTextStyles.bodySmall.copyWith(
                      fontWeight:
                          bold ? FontWeight.w700 : FontWeight.w400,
                      color: bold
                          ? AppColors.primary
                          : AppColors.textSecondary))),
          Text(v,
              style: TextStyle(
                  fontSize: bold ? 14 : 12,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                  color:
                      bold ? AppColors.primary : AppColors.textPrimary)),
        ]),
      );
}
