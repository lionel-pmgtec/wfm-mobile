// Sezioni inline editabili da inserire nel Dettaglio OdL :
//   • ATTIVITÀ (CRUD inline)
//   • APPUNTAMENTI (CRUD inline)
//   • SOSPENSIONI (CRUD inline)
//   • PREVENTIVO COLLEGATO (summary read-only)
//   • FIRME (Cliente + Tecnico)
//
// Tutte le sezioni usano [WfmCollapsibleSection] e [odlExtensionProvider].

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/widgets.dart';
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
        WfmCollapsibleSection(
          title: 'ATTIVITÀ',
          icon: Icons.task_outlined,
          badge: ext.attivita.isEmpty ? null : ext.attivita.length.toString(),
          initiallyExpanded: false,
          child: _AttivitaInline(odlCode: code, ext: ext),
        ),
        WfmCollapsibleSection(
          title: 'APPUNTAMENTI',
          icon: Icons.event_outlined,
          badge: ext.appuntamenti.isEmpty
              ? null
              : ext.appuntamenti.length.toString(),
          initiallyExpanded: false,
          child: _AppuntamentiInline(odlCode: code, ext: ext),
        ),
        WfmCollapsibleSection(
          title: 'SOSPENSIONI',
          icon: Icons.pause_circle_outline,
          badge: ext.sospensioni.isEmpty
              ? null
              : ext.sospensioni.length.toString(),
          initiallyExpanded: false,
          child: _SospensioniInline(odlCode: code, ext: ext),
        ),
        if (hasAvviso)
          WfmCollapsibleSection(
            title: 'PREVENTIVO COLLEGATO',
            icon: Icons.description_outlined,
            initiallyExpanded: false,
            child: _PreventivoSummary(
                avvisoNumero: order.notificationNumberSap!),
          ),
        WfmCollapsibleSection(
          title: 'FIRME',
          icon: Icons.draw_outlined,
          initiallyExpanded: false,
          child: _FirmeInline(odlCode: code, ext: ext),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// ATTIVITÀ
// ═══════════════════════════════════════════════════════════════════════

class _AttivitaInline extends ConsumerWidget {
  final String odlCode;
  final OdlExtension ext;
  const _AttivitaInline({required this.odlCode, required this.ext});

  Future<void> _edit(BuildContext context, WidgetRef ref,
      OdlAttivita? existing) async {
    final res = await showModalBottomSheet<OdlAttivita>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AttivitaSheet(existing: existing),
    );
    if (res == null) return;
    final n = ref.read(odlExtensionProvider(odlCode).notifier);
    if (existing == null) {
      await n.addAttivita(res);
    } else {
      await n.updateAttivita(res);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (ext.attivita.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text('Nessuna attività registrata',
                style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: AppColors.textSecondary)),
          )
        else
          for (final a in ext.attivita)
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
                  child: Row(children: [
                    Icon(a.stato.icon, size: 18, color: a.stato.color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${a.codice} — ${a.descrizione}',
                              style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w600)),
                          if (a.note.isNotEmpty)
                            Text(a.note,
                                style: AppTextStyles.bodySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: a.stato.color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(a.stato.label,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: a.stato.color)),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.delete_outline,
                          size: 16, color: AppColors.accentRed),
                      onPressed: () => ref
                          .read(odlExtensionProvider(odlCode).notifier)
                          .removeAttivita(a.id),
                    ),
                  ]),
                ),
              ),
            ),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          onPressed: () => _edit(context, ref, null),
          icon: const Icon(Icons.add_circle_outline, size: 16),
          label: const Text('Aggiungi attività'),
        ),
      ],
    );
  }
}

class _AttivitaSheet extends StatefulWidget {
  final OdlAttivita? existing;
  const _AttivitaSheet({this.existing});
  @override
  State<_AttivitaSheet> createState() => _AttivitaSheetState();
}

class _AttivitaSheetState extends State<_AttivitaSheet> {
  late final TextEditingController _codiceCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _noteCtrl;
  late OdlAttivitaStato _stato;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _codiceCtrl = TextEditingController(text: e?.codice ?? '');
    _descCtrl = TextEditingController(text: e?.descrizione ?? '');
    _noteCtrl = TextEditingController(text: e?.note ?? '');
    _stato = e?.stato ?? OdlAttivitaStato.pianificata;
  }

  @override
  void dispose() {
    _codiceCtrl.dispose();
    _descCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (_codiceCtrl.text.trim().isEmpty ||
        _descCtrl.text.trim().isEmpty) {
      showSapToast(context, 'Codice e descrizione obbligatori',
          isError: true);
      return;
    }
    final a = (widget.existing ??
            OdlAttivita(
                id: 'ATT-${DateTime.now().millisecondsSinceEpoch}',
                codice: '',
                descrizione: '',
                createdAt: DateTime.now()))
        .copyWith(
      codice: _codiceCtrl.text.trim(),
      descrizione: _descCtrl.text.trim(),
      stato: _stato,
      note: _noteCtrl.text.trim(),
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
                    ? 'Nuova attività'
                    : 'Modifica attività',
                style: AppTextStyles.headingMedium),
            const SizedBox(height: 12),
            TextField(
              controller: _codiceCtrl,
              decoration: const InputDecoration(
                  labelText: 'Codice Attività *',
                  hintText: 'es. ADS-001'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _descCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                  labelText: 'Descrizione Attività *'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<OdlAttivitaStato>(
              initialValue: _stato,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Stato'),
              items: OdlAttivitaStato.values
                  .map((s) => DropdownMenuItem(
                      value: s, child: Text(s.label)))
                  .toList(),
              onChanged: (v) => setState(() => _stato = v ?? _stato),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _noteCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                  labelText: 'Note Tecnico', alignLabelWithHint: true),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Salva attività'),
            ),
          ],
        ),
      ),
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
// SOSPENSIONI INLINE
// ═══════════════════════════════════════════════════════════════════════

class _SospensioniInline extends ConsumerWidget {
  final String odlCode;
  final OdlExtension ext;
  const _SospensioniInline({required this.odlCode, required this.ext});

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final res = await showModalBottomSheet<Suspension>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SospensioneSheet(parentCode: odlCode),
    );
    if (res != null) {
      await ref
          .read(odlExtensionProvider(odlCode).notifier)
          .addSospensione(res);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ext.sospensioni;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (list.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text('Nessuna sospensione',
                style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: AppColors.textSecondary)),
          )
        else
          for (final s in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Icon(
                    s.isActive
                        ? Icons.pause_circle_outline
                        : Icons.check_circle_outline,
                    size: 18,
                    color: s.isActive
                        ? AppColors.accentOrange
                        : AppColors.accentGreen),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.type.label,
                          style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600)),
                      Text(Fmt.dateTime(s.startDateTime),
                          style: AppTextStyles.bodySmall),
                    ],
                  ),
                ),
                if (s.isActive)
                  IconButton(
                    tooltip: 'Chiudi',
                    icon: const Icon(Icons.check, size: 16),
                    onPressed: () => ref
                        .read(odlExtensionProvider(odlCode).notifier)
                        .closeSospensione(s.id, DateTime.now()),
                  ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 16, color: AppColors.accentRed),
                  onPressed: () => ref
                      .read(odlExtensionProvider(odlCode).notifier)
                      .removeSospensione(s.id),
                ),
              ]),
            ),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          onPressed: () => _add(context, ref),
          icon: const Icon(Icons.add_circle_outline, size: 16),
          label: const Text('Aggiungi sospensione'),
        ),
      ],
    );
  }
}

class _SospensioneSheet extends StatefulWidget {
  final String parentCode;
  const _SospensioneSheet({required this.parentCode});
  @override
  State<_SospensioneSheet> createState() => _SospensioneSheetState();
}

class _SospensioneSheetState extends State<_SospensioneSheet> {
  SuspensionType _type = SuspensionType.lavoro;
  final _causaCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _causaCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
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
            const Text('Aggiungi sospensione',
                style: AppTextStyles.headingMedium),
            const SizedBox(height: 12),
            DropdownButtonFormField<SuspensionType>(
              initialValue: _type,
              isExpanded: true,
              decoration:
                  const InputDecoration(labelText: 'Tipo sospensione *'),
              items: SuspensionType.values
                  .map((t) => DropdownMenuItem(
                      value: t, child: Text(t.label)))
                  .toList(),
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _causaCtrl,
              decoration: const InputDecoration(labelText: 'Causa'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _noteCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                  labelText: 'Note', alignLabelWithHint: true),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(
                  context,
                  Suspension(
                    id: 'SOSP-${DateTime.now().millisecondsSinceEpoch}',
                    parentCode: widget.parentCode,
                    type: _type,
                    cause: _causaCtrl.text.trim(),
                    note: _noteCtrl.text.trim(),
                    startDateTime: DateTime.now(),
                  )),
              icon: const Icon(Icons.save_outlined),
              label: const Text('Salva'),
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
  final String avvisoNumero;
  const _PreventivoSummary({required this.avvisoNumero});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ext = ref.watch(avvisoExtensionProvider(avvisoNumero));
    final p = ext.preventivo;
    if (p == null) {
      return const Text(
          'Nessun preventivo collegato. Apri l\'Avviso per gestirlo.',
          style: TextStyle(
              fontStyle: FontStyle.italic,
              color: AppColors.textSecondary));
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

// ═══════════════════════════════════════════════════════════════════════
// FIRME (Cliente + Tecnico)
// ═══════════════════════════════════════════════════════════════════════

class _FirmeInline extends ConsumerWidget {
  final String odlCode;
  final OdlExtension ext;
  const _FirmeInline({required this.odlCode, required this.ext});

  Future<void> _firma(BuildContext context, WidgetRef ref,
      {required bool isCliente}) async {
    final res = await showModalBottomSheet<FirmaCliente>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _NomeFirmatarioSheet(isCliente: isCliente),
    );
    if (res == null) return;
    final n = ref.read(odlExtensionProvider(odlCode).notifier);
    if (isCliente) {
      await n.setFirmaCliente(res);
    } else {
      await n.setFirmaTecnico(res);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(children: [
      _FirmaCard(
        title: 'Firma Cliente',
        firma: ext.firmaCliente,
        onSign: () => _firma(context, ref, isCliente: true),
        onClear: () => ref
            .read(odlExtensionProvider(odlCode).notifier)
            .clearFirmaCliente(),
      ),
      const SizedBox(height: 8),
      _FirmaCard(
        title: 'Firma Tecnico',
        firma: ext.firmaTecnico,
        onSign: () => _firma(context, ref, isCliente: false),
        onClear: () => ref
            .read(odlExtensionProvider(odlCode).notifier)
            .clearFirmaTecnico(),
      ),
    ]);
  }
}

class _FirmaCard extends StatelessWidget {
  final String title;
  final FirmaCliente? firma;
  final VoidCallback onSign;
  final VoidCallback onClear;
  const _FirmaCard({
    required this.title,
    required this.firma,
    required this.onSign,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
            Icon(
                firma == null
                    ? Icons.draw_outlined
                    : Icons.check_circle_outline,
                size: 18,
                color: firma == null
                    ? AppColors.textSecondary
                    : AppColors.accentGreen),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title,
                  style: AppTextStyles.headingSmall.copyWith(fontSize: 13)),
            ),
            if (firma == null)
              OutlinedButton.icon(
                onPressed: onSign,
                icon: const Icon(Icons.draw_outlined, size: 14),
                label: const Text('Firma'),
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 32)),
              )
            else
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.delete_outline,
                    size: 16, color: AppColors.accentRed),
                onPressed: onClear,
              ),
          ]),
          if (firma != null) ...[
            const SizedBox(height: 6),
            Text('Nome: ${firma!.nomeFirmatario}',
                style: AppTextStyles.bodySmall),
            Text(
                'Data: ${firma!.dataFormattata}  •  Ora: ${firma!.oraFormattata}',
                style: AppTextStyles.bodySmall),
          ],
        ],
      ),
    );
  }
}

/// Sheet semplificato : raccoglie solo il nome del firmatario.
/// Per la firma grafometrica vera vai dal Preventivo dell'Avviso collegato
/// (che ha la canvas tactile). Qui salviamo nome + data per registro OdL.
class _NomeFirmatarioSheet extends StatefulWidget {
  final bool isCliente;
  const _NomeFirmatarioSheet({required this.isCliente});
  @override
  State<_NomeFirmatarioSheet> createState() => _NomeFirmatarioSheetState();
}

class _NomeFirmatarioSheetState extends State<_NomeFirmatarioSheet> {
  final _nomeCtrl = TextEditingController();

  @override
  void dispose() {
    _nomeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label =
        widget.isCliente ? 'Firma Cliente' : 'Firma Tecnico';
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: AppTextStyles.headingMedium),
          const SizedBox(height: 4),
          const Text(
              'Inserisci il nome del firmatario. Per la firma grafometrica '
              'completa apri il Preventivo dall\'Avviso collegato.',
              style: AppTextStyles.bodySmall),
          const SizedBox(height: 12),
          TextField(
            controller: _nomeCtrl,
            textCapitalization: TextCapitalization.words,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Nome firmatario *',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              final nome = _nomeCtrl.text.trim();
              if (nome.isEmpty) {
                showSapToast(context, 'Inserisci il nome firmatario',
                    isError: true);
                return;
              }
              Navigator.pop(
                  context,
                  FirmaCliente(
                    id: 'FIRMA-${DateTime.now().millisecondsSinceEpoch}',
                    nomeFirmatario: nome,
                    firmataIl: DateTime.now(),
                    pngBase64: '',
                  ));
            },
            icon: const Icon(Icons.check),
            label: const Text('Conferma firma'),
          ),
        ],
      ),
    );
  }
}
