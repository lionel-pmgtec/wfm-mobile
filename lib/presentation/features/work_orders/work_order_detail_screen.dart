// PAGINA 4 — Dettaglio OdL (M3) con 5 schede e barra azioni ciclo di vita (M4).

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/services/geolocation_service.dart';
import '../../../core/services/image_compression_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';
import '../../providers/attachments_provider.dart';
import '../../providers/work_orders_provider.dart';
import 'widgets/lifecycle_action_bar.dart';
import 'widgets/odl_inline_sections.dart';
import 'widgets/reassign_sheet.dart';

class WorkOrderDetailScreen extends ConsumerWidget {
  final String code;
  const WorkOrderDetailScreen({super.key, required this.code});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(workOrderDetailProvider(code));
    return async.when(
      loading: () => Scaffold(
        appBar: AppBar(
          leading: const BackButton(),
          title: Text('OdL $code'),
        ),
        body: const WfmLoading(message: 'Caricamento OdL…'),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(
          leading: const BackButton(),
          title: Text('OdL $code'),
        ),
        body: WfmErrorState(
            message: e.toString(),
            onRetry: () => ref.invalidate(workOrderDetailProvider(code))),
      ),
      data: (order) => _DetailView(order: order),
    );
  }
}

class _DetailView extends ConsumerStatefulWidget {
  final WorkOrder order;
  const _DetailView({required this.order});

  @override
  ConsumerState<_DetailView> createState() => _DetailViewState();
}

class _DetailViewState extends ConsumerState<_DetailView>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    // Tab spec : Dettaglio · Operazioni · Materiali · Allegati · Chiusura
    _tab = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  WorkOrder get order => widget.order;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text('OdL ${order.externalCode}'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) => _onMenu(context, v),
            itemBuilder: (_) => [
              const PopupMenuItem(
                  value: 'appointments', child: Text('Appuntamenti')),
              const PopupMenuItem(
                  value: 'storico',
                  child: Text('Storico appuntamenti')),
              const PopupMenuItem(
                  value: 'esito_app',
                  child: Text('Esito appuntamento')),
              const PopupMenuItem(
                  value: 'sospensioni',
                  child: Text('Sospensioni')),
              const PopupMenuItem(
                  value: 'gen_ore', child: Text('Genera ore')),
              const PopupMenuItem(
                  value: 'add_comp',
                  child: Text('Aggiungi componente')),
              const PopupMenuItem(
                  value: 'copia', child: Text('Copia OdL')),
              const PopupMenuItem(
                  value: 'cambio_cid', child: Text('Cambio CID')),
              if (order.hasInterventoRete) ...[
                const PopupMenuItem(
                    value: 'rqti', child: Text('Dati RQTI')),
                const PopupMenuItem(
                    value: 'determina5',
                    child: Text('Determina 5 / Bilancio idrico')),
              ],
              if (order.hasMeter)
                const PopupMenuItem(
                    value: 'meter', child: Text('Gestione contatore')),
              const PopupMenuItem(
                  value: 'scanner', child: Text('Scansiona barcode')),
              const PopupMenuItem(
                  value: 'map', child: Text('Apri mappa')),
              const PopupMenuItem(
                value: 'reassign',
                child: Row(
                  children: [
                    Icon(Icons.swap_horiz_rounded, size: 18, color: Colors.black54),
                    SizedBox(width: 8),
                    Text('Riassegna OdL'),
                  ],
                ),
              ),
              if (order.canCancel)
                const PopupMenuItem(value: 'cancel', child: Text('Annulla OdL')),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white,
          indicatorColor: Colors.white,
          dividerColor: Colors.white24,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
          tabs: [
            const Tab(text: 'Dettaglio'),
            Tab(text: 'Operazioni (${order.operations.length})'),
            Tab(text: 'Materiali (${order.plannedMaterials.length})'),
            Tab(text: 'Allegati (${order.attachmentsCount})'),
            const Tab(text: 'Chiusura'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _DettaglioTab(order: order),
          _OperazioniTab(order: order),
          _ComponentiTab(order: order),
          _AllegatiTab(code: order.externalCode),
          _ChiusuraTab(order: order),
        ],
      ),
      bottomNavigationBar: LifecycleActionBar(order: order),
    );
  }

  Future<void> _onMenu(BuildContext context, String value) async {
    final code = order.externalCode;
    switch (value) {
      case 'appointments':
        context.push(AppRoutes.appointmentsPath(code));
        break;
      case 'storico':
        context.push(AppRoutes.storicoAppuntamentiPath(code));
        break;
      case 'esito_app':
        context.push(AppRoutes.esitoAppuntamentoPath(code));
        break;
      case 'sospensioni':
        context.push(AppRoutes.sospensioniPath(code));
        break;
      case 'gen_ore':
        context.push(AppRoutes.genOrePath(code));
        break;
      case 'add_comp':
        context.push(AppRoutes.addComponentePath(code));
        break;
      case 'copia':
        context.push(AppRoutes.copiaOrdinePath(code));
        break;
      case 'cambio_cid':
        context.push(AppRoutes.cambioCidPath(code));
        break;
      case 'rqti':
        context.push(AppRoutes.datiRqtiPath(code));
        break;
      case 'determina5':
        context.push(AppRoutes.determina5Path(code));
        break;
      case 'meter':
        context.push(AppRoutes.meterPath(code));
        break;
      case 'scanner':
        context.push(AppRoutes.scanner);
        break;
      case 'map':
        context.push(AppRoutes.map);
        break;
      case 'reassign':
        await showReassignSheet(context, ref, code);
        break;
      case 'cancel':
        await _confirmCancel(context);
        break;
    }
  }

  Future<void> _confirmCancel(BuildContext context) async {
    final reasonCtrl = TextEditingController();
    final ok = await showWfmConfirmDialog(
      context: context,
      title: 'Annulla OdL',
      message:
          'L\'OdL verrà annullato e rimosso dal tablet. Inserisci un motivo per la chiusura.',
      confirmLabel: 'Annulla OdL',
      cancelLabel: 'Indietro',
      tone: WfmDialogTone.danger,
      icon: Icons.cancel_outlined,
      extraContent: TextField(
        controller: reasonCtrl,
        decoration: const InputDecoration(labelText: 'Motivo annullamento'),
        maxLines: 2,
      ),
    );
    if (ok == true && context.mounted) {
      final res = await ref.read(workOrderActionsProvider).changeStatus(
            order.externalCode,
            WorkOrderStatus.annullato,
            reason: reasonCtrl.text,
          );
      if (context.mounted) {
        res.isSuccess
            ? context.pop()
            : showSapToast(context, 'Errore annullamento', isError: true);
      }
    }
  }
}

// ─── SCHEDA DETTAGLIO ──────────────────────────────────────────────────────
// Struttura conforme spec ODL :
//   1. Banner categoria + DATI ORDINE
//   2. CLIENTE
//   3. INDIRIZZI (Cliente / Oggetto / Intervento)
//   4. DATI TECNICI
//   5. RISORSE
//   6. AMPLIAMENTO (impianto + contratto)
//   7. PIANIFICAZIONE

class _DettaglioTab extends StatelessWidget {
  final WorkOrder order;
  const _DettaglioTab({required this.order});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: kPagePadding,
      children: [
        // Banner categoria + tipo
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primarySurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Text(order.typeEmoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  order.typeCategoryLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  order.woType,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── 1. DATI ORDINE ──────────────────────────────────────────
        const SectionHeader(title: 'DATI ORDINE'),
        FieldRow(
            label: 'Descrizione',
            value: order.woTypeDescription,
            fullWidth: true),
        const SizedBox(height: 8),
        FormGrid(children: [
          FieldRow(label: 'Numero ODL', value: order.externalCode),
          FieldRow(label: 'Tipo Ordine', value: order.woType),
          FieldRow(
              label: 'Tipo Attività',
              value: order.tipoAttivitaCodice != null &&
                      order.tipoAttivitaCodice!.isNotEmpty
                  ? '${order.tipoAttivitaCodice} - ${order.tipoAttivitaNome ?? order.subTam}'
                  : order.subTam,
              hideIfEmpty: true),
          FieldRow(label: 'Stato ODL', value: order.status.label),
          FieldRow(
              label: 'Priorità',
              value: order.priorita,
              hideIfEmpty: true),
          FieldRow(
              label: 'Data Creazione',
              value: Fmt.date(order.createdAt),
              hideIfEmpty: true),
          FieldRow(
              label: 'Creato Da',
              value: order.creatoDa ?? '',
              hideIfEmpty: true),
          FieldRow(
              label: 'Avviso Origine',
              value:
                  order.avvisoOrigine ?? order.notificationNumberSap ?? '',
              hideIfEmpty: true),
          FieldRow(
              label: 'CID Assegnato',
              value: order.cidAssegnato ?? '',
              hideIfEmpty: true,
              trailing: IconButton(
                tooltip: 'Cambia CID',
                icon: const Icon(Icons.swap_horiz_rounded,
                    size: 18, color: AppColors.primary),
                onPressed: () =>
                    context.push(AppRoutes.cambioCidPath(order.externalCode)),
              )),
          FieldRow(
              label: 'Centro Pianificazione',
              value: order.centroPianificazione,
              hideIfEmpty: true),
          FieldRow(
              label: 'Centro di Lavoro',
              value: order.centroLavoro,
              hideIfEmpty: true),
          FieldRow(
              label: 'Data Appuntamento',
              value: Fmt.date(order.appointmentDate),
              hideIfEmpty: true),
          FieldRow(
              label: 'Ora Appuntamento',
              value: order.appointmentStartTime,
              hideIfEmpty: true),
          FieldRow(
              label: 'Settore Contabile',
              value: order.accountingSector,
              hideIfEmpty: true),
        ]),

        // ── 2. CLIENTE ──────────────────────────────────────────────
        if (!order.customer.isEmpty || (order.referente ?? '').isNotEmpty) ...[
          const SectionHeader(title: 'CLIENTE'),
          FormGrid(children: [
            FieldRow(
                label: 'Codice Cliente',
                value: order.codiceCliente ?? order.customer.codCli ?? '',
                hideIfEmpty: true),
            FieldRow(
                label: 'Ragione Sociale',
                value: order.customer.isBusiness
                    ? (order.customer.ragioneSociale ?? '')
                    : order.customer.fullName,
                hideIfEmpty: true),
            FieldRow(
                label: 'Referente',
                value: order.referente ?? '',
                hideIfEmpty: true),
            FieldRow(
                label: 'Telefono',
                value: order.telefonoCliente ??
                    order.customer.telefono ??
                    '',
                hideIfEmpty: true),
            FieldRow(
                label: 'Cod. BP',
                value: order.customer.codBp ?? '',
                hideIfEmpty: true),
            FieldRow(
                label: 'Email',
                value: order.customer.email ?? '',
                hideIfEmpty: true),
          ]),
        ],

        // ── 3. INDIRIZZI ────────────────────────────────────────────
        const SectionHeader(title: 'INDIRIZZI'),
        FieldRow(
          label: 'Indirizzo Cliente',
          value: order.address.full,
          fullWidth: true,
          trailing: order.address.hasCoordinates
              ? IconButton(
                  icon: const Icon(Icons.map_outlined,
                      color: AppColors.primary),
                  onPressed: () => context.push(AppRoutes.map))
              : null,
        ),
        if (order.indirizzoOggetto != null) ...[
          const SizedBox(height: 8),
          FieldRow(
              label: 'Indirizzo Oggetto',
              value: order.indirizzoOggetto!.full,
              fullWidth: true),
        ],
        if (order.indirizzoIntervento != null) ...[
          const SizedBox(height: 8),
          FieldRow(
            label: 'Indirizzo Intervento',
            value: order.indirizzoIntervento!.full,
            fullWidth: true,
            trailing: order.indirizzoIntervento!.hasCoordinates
                ? IconButton(
                    icon: const Icon(Icons.map_outlined,
                        color: AppColors.primary),
                    onPressed: () => context.push(AppRoutes.map))
                : null,
          ),
        ],
        const SizedBox(height: 8),
        FormGrid(children: [
          FieldRow(
              label: 'Ubicazione Tecnica',
              value: order.ubicazione,
              hideIfEmpty: true),
          FieldRow(
              label: 'Equipment',
              value: order.equipment,
              hideIfEmpty: true),
          FieldRow(
              label: 'Coordinate GPS',
              value: (order.indirizzoIntervento ?? order.address)
                  .gpsCoordinates,
              hideIfEmpty: true),
        ]),

        // ── 4. DATI TECNICI ────────────────────────────────────────
        const SectionHeader(title: 'DATI TECNICI'),
        FormGrid(children: [
          FieldRow(
              label: 'Sede Tecnica',
              value: order.sedeTecnica,
              hideIfEmpty: true),
          FieldRow(
              label: 'Equipment',
              value: order.equipment,
              hideIfEmpty: true),
          FieldRow(
              label: 'Matricola',
              value: order.matricola ?? order.meter?.matricola ?? '',
              hideIfEmpty: true),
          FieldRow(
              label: 'Ubicazione Tecnica',
              value: order.ubicazione,
              hideIfEmpty: true),
          FieldRow(
              label: 'Impianto',
              value: order.impianto,
              hideIfEmpty: true),
        ]),

        if (order.hasMeter) ...[
          const SectionHeader(title: 'CONTATORE'),
          FormGrid(children: [
            FieldRow(label: 'Matricola', value: order.meter!.matricola),
            FieldRow(label: 'Marca/Modello', value: order.meter!.displayName),
            FieldRow(
                label: 'Calibro',
                value: order.meter!.caliber,
                hideIfEmpty: true),
            FieldRow(
                label: 'Ubicazione',
                value: order.meter!.location,
                hideIfEmpty: true),
            FieldRow(
                label: 'Ultima Lettura',
                value: order.meter!.lastReading?.toString() ?? '',
                hideIfEmpty: true),
            FieldRow(
                label: 'Data Lettura',
                value: Fmt.date(order.meter!.lastReadingDate),
                hideIfEmpty: true),
          ]),
        ],

        // ── 5. RISORSE ──────────────────────────────────────────────
        const SectionHeader(title: 'RISORSE'),
        FormGrid(children: [
          FieldRow(
              label: 'Tecnico Assegnato',
              value: order.cidAssegnato ?? '',
              hideIfEmpty: true),
          FieldRow(
              label: 'Squadra',
              value: order.squadra,
              hideIfEmpty: true),
          FieldRow(
              label: 'Responsabile',
              value: order.responsabile ?? '',
              hideIfEmpty: true),
          FieldRow(
              label: 'Fornitore Esterno',
              value: order.fornitoreEsterno ?? '',
              hideIfEmpty: true),
        ]),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: order.reperibilita
                ? AppColors.primary.withValues(alpha: 0.08)
                : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: order.reperibilita
                    ? AppColors.primary.withValues(alpha: 0.3)
                    : AppColors.border),
          ),
          child: Row(children: [
            Icon(
                order.reperibilita
                    ? Icons.check_circle_outline
                    : Icons.remove_circle_outline,
                size: 18,
                color: order.reperibilita
                    ? AppColors.primary
                    : AppColors.textHint),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Reperibilità Attiva',
                  style: AppTextStyles.bodyMedium
                      .copyWith(fontWeight: FontWeight.w600)),
            ),
            Text(order.reperibilita ? 'Sì' : 'No',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: order.reperibilita
                        ? AppColors.primary
                        : AppColors.textHint)),
          ]),
        ),

        // ── 6. AMPLIAMENTO ──────────────────────────────────────────
        if ((order.impiantoDis ?? '').isNotEmpty ||
            (order.contratto ?? '').isNotEmpty) ...[
          const SectionHeader(title: 'AMPLIAMENTO'),
          FormGrid(children: [
            FieldRow(
                label: 'Impianto Disattivazione',
                value: order.impiantoDis ?? '',
                hideIfEmpty: true),
            FieldRow(
                label: 'Contratto',
                value: order.contratto ?? '',
                hideIfEmpty: true),
          ]),
        ],

        // ── 7. PIANIFICAZIONE ──────────────────────────────────────
        if ((order.ultimoCicloManutenzione ?? '').isNotEmpty ||
            (order.postManut ?? '').isNotEmpty ||
            order.dataEsec != null) ...[
          const SectionHeader(title: 'PIANIFICAZIONE'),
          FormGrid(children: [
            FieldRow(
                label: 'Ultimo Ciclo Manutenzione',
                value: order.ultimoCicloManutenzione ?? '',
                hideIfEmpty: true,
                fullWidth: true),
            FieldRow(
                label: 'Post. Manut.',
                value: order.postManut ?? '',
                hideIfEmpty: true),
            FieldRow(
                label: 'Data Esecuzione',
                value: Fmt.date(order.dataEsec),
                hideIfEmpty: true),
          ]),
        ],

        // ── NOTE OPERATIVE ────────────────────────────────────────
        if (order.notes.trim().isNotEmpty) ...[
          const SectionHeader(title: 'NOTE'),
          FieldRow(
              label: 'Nota Ordine',
              value: order.notes,
              fullWidth: true,
              maxLines: 4),
        ],

        // ── SEZIONI INLINE (Attività · Appuntamenti · Sospensioni ·
        //                    Preventivo collegato · Firme) ─────────
        const SizedBox(height: 12),
        OdlInlineSections(order: order),

        // ── ACCESSI RAPIDI (azioni dal popup menu) ────────────────
        const SectionHeader(title: 'AZIONI RAPIDE'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _QuickActionChip(
                icon: Icons.event_outlined,
                label: 'Appuntamenti',
                onTap: () =>
                    context.push(AppRoutes.appointmentsPath(order.externalCode))),
            _QuickActionChip(
                icon: Icons.history_rounded,
                label: 'Storico',
                onTap: () => context.push(
                    AppRoutes.storicoAppuntamentiPath(order.externalCode))),
            _QuickActionChip(
                icon: Icons.fact_check_outlined,
                label: 'Esito',
                onTap: () => context.push(
                    AppRoutes.esitoAppuntamentoPath(order.externalCode))),
            _QuickActionChip(
                icon: Icons.pause_circle_outline,
                label: 'Sospensioni',
                onTap: () => context
                    .push(AppRoutes.sospensioniPath(order.externalCode))),
            _QuickActionChip(
                icon: Icons.access_time_outlined,
                label: 'Genera ore',
                onTap: () =>
                    context.push(AppRoutes.genOrePath(order.externalCode))),
            _QuickActionChip(
                icon: Icons.inventory_2_outlined,
                label: 'Componente',
                onTap: () => context
                    .push(AppRoutes.addComponentePath(order.externalCode))),
          ],
        ),

        const SizedBox(height: 100),
      ],
    );
  }
}

/// Chip d'azione rapida per la sezione "AZIONI RAPIDE".
class _QuickActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickActionChip(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary)),
          ],
        ),
      ),
    );
  }
}

// ─── SCHEDA CHIUSURA OdL ───────────────────────────────────────────────────
//
// Sezione spec : Esito Intervento, Problema risolto, Da riprogrammare,
// Data Chiusura, Chiuso Da, Note Finali.
class _ChiusuraTab extends StatefulWidget {
  final WorkOrder order;
  const _ChiusuraTab({required this.order});

  @override
  State<_ChiusuraTab> createState() => _ChiusuraTabState();
}

class _ChiusuraTabState extends State<_ChiusuraTab> {
  OdlEsitoIntervento? _esito;
  bool _problemaRisolto = false;
  bool _daRiprogrammare = false;
  DateTime? _dataChiusura;
  final _chiusoDaCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _chiusoDaCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickData() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _dataChiusura ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (d != null) setState(() => _dataChiusura = d);
  }

  @override
  Widget build(BuildContext context) {
    final isClosed = widget.order.isClosed;
    return ListView(
      padding: kPagePadding,
      children: [
        if (isClosed)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.statusDoneBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              const Icon(Icons.check_circle_outline,
                  color: AppColors.accentGreen),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                    'OdL chiuso (${widget.order.status.label}). Dati di chiusura disponibili in sola lettura.',
                    style: AppTextStyles.bodyMedium),
              ),
            ]),
          ),
        const SectionHeader(title: 'ESITO INTERVENTO'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: OdlEsitoIntervento.values
              .map((e) => ChoiceChip(
                    label: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(e.icon,
                          size: 16,
                          color:
                              _esito == e ? Colors.white : e.color),
                      const SizedBox(width: 6),
                      Text(e.label),
                    ]),
                    selected: _esito == e,
                    selectedColor: e.color,
                    onSelected: isClosed
                        ? null
                        : (_) => setState(() => _esito = e),
                    labelStyle: TextStyle(
                        color:
                            _esito == e ? Colors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.w700),
                  ))
              .toList(),
        ),
        const SizedBox(height: 12),
        const SectionHeader(title: 'DETTAGLI CHIUSURA'),
        CheckboxListTile(
          value: _problemaRisolto,
          onChanged: isClosed
              ? null
              : (v) => setState(() => _problemaRisolto = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('Problema risolto'),
          contentPadding: EdgeInsets.zero,
        ),
        CheckboxListTile(
          value: _daRiprogrammare,
          onChanged: isClosed
              ? null
              : (v) => setState(() => _daRiprogrammare = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('Da riprogrammare'),
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: InkWell(
              onTap: isClosed ? null : _pickData,
              borderRadius: BorderRadius.circular(8),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Data Chiusura',
                  prefixIcon: Icon(Icons.event_outlined),
                ),
                child: Text(
                  _dataChiusura == null
                      ? (isClosed ? '—' : 'Seleziona…')
                      : Fmt.date(_dataChiusura),
                  style: AppTextStyles.bodyMedium,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _chiusoDaCtrl,
              enabled: !isClosed,
              decoration: const InputDecoration(
                labelText: 'Chiuso Da',
                prefixIcon: Icon(Icons.engineering_outlined),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        TextField(
          controller: _noteCtrl,
          maxLines: 4,
          enabled: !isClosed,
          decoration: const InputDecoration(
            labelText: 'Note Finali',
            alignLabelWithHint: true,
            hintText: 'Annotazioni di chiusura intervento…',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 18),
        if (!isClosed)
          ElevatedButton.icon(
            onPressed: _esito == null
                ? null
                : () {
                    showSapToast(context,
                        'Chiusura salvata localmente — completa il ciclo tramite "Concludi"');
                  },
            icon: const Icon(Icons.save_outlined),
            label: const Text('Salva chiusura'),
          ),
        const SizedBox(height: 80),
      ],
    );
  }
}

// ─── SCHEDA OPERAZIONI ─────────────────────────────────────────────────────
// Tabella operazioni editabile (spec).
// Colonne: Op | Codice | Testo Breve | CID | Descrizione | Inizio Prev |
//          Fine Prev | Durata Eff. | Tempo Lavoro
// L'operatore puo aggiungere righe (anche piu righe per lo stesso CID).

class _OperazioniTab extends StatefulWidget {
  final WorkOrder order;
  const _OperazioniTab({required this.order});

  @override
  State<_OperazioniTab> createState() => _OperazioniTabState();
}

class _OperazioniTabState extends State<_OperazioniTab> {
  late List<Operation> _ops;

  @override
  void initState() {
    super.initState();
    _ops = List.of(widget.order.operations);
  }

  Future<void> _editRow(Operation? existing) async {
    final res = await showModalBottomSheet<Operation>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OperazioneSheet(
        existing: existing,
        defaultCid: widget.order.cidAssegnato ?? '',
        defaultNumber: _ops.isEmpty
            ? '0010'
            : _nextNumber(_ops.last.number),
      ),
    );
    if (res == null) return;
    setState(() {
      if (existing == null) {
        _ops.add(res);
      } else {
        final i = _ops.indexWhere((o) => o.id == existing.id);
        if (i >= 0) _ops[i] = res;
      }
    });
  }

  String _nextNumber(String last) {
    final n = int.tryParse(last) ?? 0;
    return (n + 10).toString().padLeft(4, '0');
  }

  void _remove(Operation op) {
    setState(() => _ops.removeWhere((o) => o.id == op.id));
  }

  void _toggleDone(Operation op) {
    setState(() {
      final i = _ops.indexWhere((o) => o.id == op.id);
      if (i >= 0) _ops[i] = _ops[i].copyWith(completed: !_ops[i].completed);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (_ops.isEmpty)
          const EmptyState(
            title: 'Nessuna operazione',
            subtitle:
                'Tocca "Aggiungi operazione" in basso a destra per inserire la prima riga.',
            icon: Icons.list_alt_outlined,
          )
        else
          ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
            itemCount: _ops.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _OperazioneRow(
              op: _ops[i],
              onEdit: () => _editRow(_ops[i]),
              onDelete: () => _remove(_ops[i]),
              onToggleDone: () => _toggleDone(_ops[i]),
            ),
          ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            onPressed: () => _editRow(null),
            icon: const Icon(Icons.add),
            label: const Text('Aggiungi operazione'),
          ),
        ),
      ],
    );
  }
}

class _OperazioneRow extends StatelessWidget {
  final Operation op;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleDone;
  const _OperazioneRow({
    required this.op,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleDone,
  });

  @override
  Widget build(BuildContext context) {
    final hours = op.effectiveHours;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: op.completed
                ? AppColors.accentGreen.withValues(alpha: 0.4)
                : AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            InkWell(
              onTap: onToggleDone,
              borderRadius: BorderRadius.circular(20),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: op.completed
                    ? AppColors.accentGreen.withValues(alpha: 0.14)
                    : AppColors.primarySurface,
                child: Text(
                  op.number,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: op.completed
                          ? AppColors.accentGreen
                          : AppColors.primary),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      op.testoBreve.isEmpty
                          ? op.description
                          : op.testoBreve,
                      style: AppTextStyles.headingSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  if (op.codice.isNotEmpty)
                    Text('Codice: ${op.codice}',
                        style: AppTextStyles.bodySmall),
                ],
              ),
            ),
            // Badge CID
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.person_outline,
                    size: 12, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(op.cid.isEmpty ? '—' : op.cid,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary)),
              ]),
            ),
          ]),
          if (op.description.isNotEmpty &&
              op.description != op.testoBreve) ...[
            const SizedBox(height: 6),
            Text(op.description,
                style: AppTextStyles.bodySmall,
                maxLines: 3,
                overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 8),
          // Date + ore
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              if (op.dataInizioPrevista != null)
                _MiniInfo(
                    icon: Icons.event_outlined,
                    label: 'Inizio',
                    value: Fmt.date(op.dataInizioPrevista)),
              if (op.dataFinePrevista != null)
                _MiniInfo(
                    icon: Icons.event_outlined,
                    label: 'Fine',
                    value: Fmt.date(op.dataFinePrevista)),
              if (op.plannedHours != null)
                _MiniInfo(
                    icon: Icons.schedule_outlined,
                    label: 'Pianif.',
                    value: '${op.plannedHours}h'),
              if (hours != null)
                _MiniInfo(
                    icon: Icons.timer_outlined,
                    label: 'Durata',
                    value: '${hours}h',
                    color: AppColors.accentGreen),
              if ((op.tempoLavoroFase ?? '').isNotEmpty)
                _MiniInfo(
                    icon: Icons.label_outline,
                    label: 'Fase',
                    value: op.tempoLavoroFase!),
            ],
          ),
          const SizedBox(height: 8),
          Row(children: [
            const Spacer(),
            TextButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Modifica'),
            ),
            const SizedBox(width: 4),
            TextButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline,
                  size: 16, color: AppColors.accentRed),
              label: const Text('Elimina',
                  style: TextStyle(color: AppColors.accentRed)),
            ),
          ]),
        ],
      ),
    );
  }
}

class _MiniInfo extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;
  const _MiniInfo({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textSecondary;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: c),
      const SizedBox(width: 4),
      Text('$label: ',
          style: TextStyle(
              fontSize: 11, color: c, fontWeight: FontWeight.w500)),
      Text(value,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color ?? AppColors.textPrimary)),
    ]);
  }
}

/// Bottom sheet di edit operazione : tutti i campi spec.
class _OperazioneSheet extends StatefulWidget {
  final Operation? existing;
  final String defaultCid;
  final String defaultNumber;
  const _OperazioneSheet({
    required this.existing,
    required this.defaultCid,
    required this.defaultNumber,
  });
  @override
  State<_OperazioneSheet> createState() => _OperazioneSheetState();
}

class _OperazioneSheetState extends State<_OperazioneSheet> {
  late final TextEditingController _numberCtrl;
  late final TextEditingController _codiceCtrl;
  late final TextEditingController _testoBreveCtrl;
  late final TextEditingController _cidCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _faseCtrl;
  late final TextEditingController _orePianifCtrl;
  late final TextEditingController _durataEffCtrl;
  DateTime? _dataInizio;
  DateTime? _dataFine;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _numberCtrl =
        TextEditingController(text: e?.number ?? widget.defaultNumber);
    _codiceCtrl = TextEditingController(text: e?.codice ?? '');
    _testoBreveCtrl = TextEditingController(text: e?.testoBreve ?? '');
    _cidCtrl =
        TextEditingController(text: e?.cid ?? widget.defaultCid);
    _descCtrl = TextEditingController(text: e?.description ?? '');
    _faseCtrl =
        TextEditingController(text: e?.tempoLavoroFase ?? '');
    _orePianifCtrl =
        TextEditingController(text: e?.plannedHours?.toString() ?? '');
    _durataEffCtrl = TextEditingController(
        text: e?.effectiveHours?.toString() ?? '');
    _dataInizio = e?.dataInizioPrevista;
    _dataFine = e?.dataFinePrevista;
  }

  @override
  void dispose() {
    _numberCtrl.dispose();
    _codiceCtrl.dispose();
    _testoBreveCtrl.dispose();
    _cidCtrl.dispose();
    _descCtrl.dispose();
    _faseCtrl.dispose();
    _orePianifCtrl.dispose();
    _durataEffCtrl.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDate(DateTime? initial) => showDatePicker(
        context: context,
        initialDate: initial ?? DateTime.now(),
        firstDate: DateTime(2020),
        lastDate: DateTime(2035),
      );

  void _save() {
    if (_numberCtrl.text.trim().isEmpty ||
        _testoBreveCtrl.text.trim().isEmpty) {
      showSapToast(context, 'Op. e testo breve sono obbligatori',
          isError: true);
      return;
    }
    final pianif = num.tryParse(_orePianifCtrl.text.replaceAll(',', '.'));
    final eff = num.tryParse(_durataEffCtrl.text.replaceAll(',', '.'));
    final op = (widget.existing ??
            Operation(
                id: 'OP-${DateTime.now().millisecondsSinceEpoch}',
                number: '',
                description: ''))
        .copyWith(
      number: _numberCtrl.text.trim(),
      codice: _codiceCtrl.text.trim(),
      testoBreve: _testoBreveCtrl.text.trim(),
      cid: _cidCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      dataInizioPrevista: _dataInizio,
      dataFinePrevista: _dataFine,
      plannedHours: pianif,
      durataEffettiva: eff,
      tempoLavoroFase: _faseCtrl.text.trim(),
    );
    Navigator.pop(context, op);
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
                    ? 'Nuova operazione'
                    : 'Modifica operazione',
                style: AppTextStyles.headingMedium),
            const SizedBox(height: 12),
            Row(children: [
              SizedBox(
                width: 90,
                child: TextField(
                  controller: _numberCtrl,
                  decoration: const InputDecoration(labelText: 'Op. *'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _codiceCtrl,
                  decoration: const InputDecoration(labelText: 'Codice'),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            TextField(
              controller: _testoBreveCtrl,
              decoration: const InputDecoration(labelText: 'Testo Breve *'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _cidCtrl,
              decoration: const InputDecoration(
                labelText: 'CID',
                prefixIcon: Icon(Icons.person_outline),
                helperText:
                    'Identico al CID dell\'OdL per row aggiuntive sullo stesso operatore.',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Descrizione',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: _DateField(
                    label: 'Inizio Prev.',
                    value: _dataInizio,
                    onPick: () async {
                      final d = await _pickDate(_dataInizio);
                      if (d != null) setState(() => _dataInizio = d);
                    }),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DateField(
                    label: 'Fine Prev.',
                    value: _dataFine,
                    onPick: () async {
                      final d = await _pickDate(_dataFine);
                      if (d != null) setState(() => _dataFine = d);
                    }),
              ),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _orePianifCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Ore Pianificate', suffixText: 'h'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _durataEffCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Durata Effettiva', suffixText: 'h'),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            TextField(
              controller: _faseCtrl,
              decoration: const InputDecoration(
                labelText: 'Tempo Lavoro / Fase',
                hintText: 'es. Scavo, Allaccio, Collaudo…',
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Salva operazione'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onPick;
  const _DateField(
      {required this.label, required this.value, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.event_outlined),
        ),
        child: Text(
          value == null ? '—' : Fmt.date(value),
          style: AppTextStyles.bodyMedium,
        ),
      ),
    );
  }
}

// ─── SCHEDA COMPONENTI ─────────────────────────────────────────────────────

class _ComponentiTab extends StatelessWidget {
  final WorkOrder order;
  const _ComponentiTab({required this.order});

  @override
  Widget build(BuildContext context) {
    if (order.plannedMaterials.isEmpty) {
      return const EmptyState(
          title: 'Nessun materiale',
          subtitle: 'Aggiungi i materiali utilizzati durante l\'intervento.',
          icon: Icons.inventory_2_outlined);
    }
    return ListView.separated(
      padding: kPagePadding,
      itemCount: order.plannedMaterials.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final m = order.plannedMaterials[i];
        return WfmCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                    child: Text(m.description.isEmpty ? m.materialCode : m.description,
                        style: AppTextStyles.headingSmall)),
                Text(m.materialCode, style: AppTextStyles.bodySmall),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                _qty('Previsto', m.plannedQuantity, m.unitOfMeasure),
                const SizedBox(width: 16),
                _qty('Utilizzato', m.usedQuantity, m.unitOfMeasure),
                const Spacer(),
                Text('Mag. ${Fmt.orDash(m.warehouseCode)}',
                    style: AppTextStyles.bodySmall),
              ]),
            ],
          ),
        );
      },
    );
  }

  Widget _qty(String label, num value, String uom) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.labelSmall),
          Text('${Fmt.quantity(value)} $uom',
              style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600)),
        ],
      );
}

// ─── SCHEDA ALLEGATI ───────────────────────────────────────────────────────

class _AllegatiTab extends ConsumerStatefulWidget {
  final String code;
  const _AllegatiTab({required this.code});

  @override
  ConsumerState<_AllegatiTab> createState() => _AllegatiTabState();
}

class _AllegatiTabState extends ConsumerState<_AllegatiTab> {
  final _picker = ImagePicker();
  bool _uploading = false;

  String get _code => widget.code;

  // ─── Acquisizione foto (fotocamera o galleria) ────────────────────────────

  Future<void> _pickImage(ImageSource source) async {
    try {
      final xFile = await _picker.pickImage(
        source: source,
        imageQuality: 95,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (xFile == null || !mounted) return;

      setState(() => _uploading = true);

      // Cattura posizione in parallelo (no-op se permessi negati).
      final geoFuture = source == ImageSource.camera
          ? GeolocationService.instance.getCurrentPosition()
          : Future.value(null);

      // Comprime la foto prima di registrarla come allegato.
      final compressed =
          await ImageCompressionService.instance.compress(xFile.path);
      final path = compressed?.path ?? xFile.path;
      final size = compressed?.sizeBytes ?? await File(xFile.path).length();
      final geo = await geoFuture;

      final attachment = Attachment(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        workOrderCode: _code,
        type: AttachmentType.fotoDopo,
        filePath: path,
        fileName: xFile.name,
        mimeType: 'image/jpeg',
        sizeBytes: size,
        geolocation: geo,
        capturedAt: DateTime.now(),
        author: '',
      );
      await ref.read(attachmentActionsProvider).add(attachment);
    } catch (e) {
      if (mounted) showSapToast(context, 'Errore acquisizione foto', isError: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  // ─── Selezione file (PDF, documenti) ────────────────────────────────────

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'png', 'jpg', 'jpeg'],
      );
      if (result == null || result.files.isEmpty || !mounted) return;

      setState(() => _uploading = true);
      final pf = result.files.first;
      final mimeType = _mimeFromExtension(pf.extension ?? '');
      final attachment = Attachment(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        workOrderCode: _code,
        type: AttachmentType.documento,
        filePath: pf.path ?? '',
        fileName: pf.name,
        mimeType: mimeType,
        sizeBytes: pf.size,
        capturedAt: DateTime.now(),
        author: '',
      );
      await ref.read(attachmentActionsProvider).add(attachment);
    } catch (e) {
      if (mounted) showSapToast(context, 'Errore selezione file', isError: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  // ─── Sostituzione allegato ────────────────────────────────────────────────

  Future<void> _replaceAttachment(Attachment old) async {
    try {
      XFile? xFile;
      if (old.isImage) {
        xFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 95);
      } else {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'png', 'jpg', 'jpeg'],
        );
        if (result != null && result.files.isNotEmpty) {
          final pf = result.files.first;
          xFile = XFile(pf.path ?? '');
        }
      }
      if (xFile == null || !mounted) return;

      setState(() => _uploading = true);
      // Per le immagini comprime; per i file generici mantieni l'originale.
      String path = xFile.path;
      int size;
      if (old.isImage) {
        final compressed =
            await ImageCompressionService.instance.compress(xFile.path);
        path = compressed?.path ?? xFile.path;
        size = compressed?.sizeBytes ?? await File(xFile.path).length();
      } else {
        size = await File(xFile.path).length();
      }
      final newAttachment = Attachment(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        workOrderCode: _code,
        type: old.type,
        filePath: path,
        fileName: xFile.name,
        mimeType: old.isImage ? 'image/jpeg' : _mimeFromExtension(xFile.path.split('.').last),
        sizeBytes: size,
        capturedAt: DateTime.now(),
        author: old.author,
      );
      await ref.read(attachmentActionsProvider).replace(_code, old.id, newAttachment);
    } catch (e) {
      if (mounted) showSapToast(context, 'Errore sostituzione', isError: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  // ─── Eliminazione allegato ────────────────────────────────────────────────

  Future<void> _deleteAttachment(Attachment a) async {
    final ok = await showWfmConfirmDialog(
      context: context,
      title: 'Elimina allegato',
      message: 'Eliminare "${a.fileName}"? L\'operazione non è reversibile.',
      confirmLabel: 'Elimina',
      cancelLabel: 'Annulla',
      tone: WfmDialogTone.danger,
      icon: Icons.delete_outline,
    );
    if (ok == true && mounted) {
      await ref.read(attachmentActionsProvider).remove(_code, a.id);
      showSapToast(context, 'Allegato eliminato');
    }
  }

  // ─── Apertura/visualizzazione allegato ──────────────────────────────────

  void _openAttachment(Attachment a) {
    if (a.isImage && a.filePath.isNotEmpty) {
      showDialog(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: Colors.black,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  child: _imageWidget(a),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    a.fileName,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      showSapToast(context, 'Apri: ${a.fileName}');
    }
  }

  // ─── Menu contestuale (long press) ───────────────────────────────────────

  void _showAttachmentMenu(Attachment a) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.visibility_outlined),
              title: const Text('Visualizza'),
              onTap: () { Navigator.pop(context); _openAttachment(a); },
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz_rounded),
              title: const Text('Sostituisci'),
              onTap: () { Navigator.pop(context); _replaceAttachment(a); },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outlined, color: AppColors.accentRed),
              title: const Text('Elimina', style: TextStyle(color: AppColors.accentRed)),
              onTap: () { Navigator.pop(context); _deleteAttachment(a); },
            ),
          ],
        ),
      ),
    );
  }

  // ─── Widget immagine (locale o remota) ───────────────────────────────────

  Widget _imageWidget(Attachment a) {
    if (a.filePath.startsWith('http')) {
      return Image.network(
        a.filePath,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, size: 32, color: AppColors.textHint),
      );
    }
    final file = File(a.filePath);
    if (file.existsSync()) {
      return Image.file(file, fit: BoxFit.cover);
    }
    return const Icon(Icons.broken_image_outlined, size: 32, color: AppColors.textHint);
  }

  IconData _fileIcon(String mimeType) {
    if (mimeType.contains('pdf')) return Icons.picture_as_pdf_outlined;
    if (mimeType.contains('word') || mimeType.contains('document')) return Icons.description_outlined;
    if (mimeType.startsWith('image')) return Icons.image_outlined;
    return Icons.insert_drive_file_outlined;
  }

  String _mimeFromExtension(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf': return 'application/pdf';
      case 'doc': case 'docx': return 'application/msword';
      case 'png': return 'image/png';
      case 'jpg': case 'jpeg': return 'image/jpeg';
      default: return 'application/octet-stream';
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(attachmentsProvider(_code));

    return Column(
      children: [
        // Barra azioni caricamento
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          child: Column(
            children: [
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _uploading ? null : () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera_outlined, size: 18),
                    label: const Text('Fotocamera'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _uploading ? null : () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: const Text('Galleria'),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _uploading ? null : _pickFile,
                    icon: const Icon(Icons.upload_file_outlined, size: 18),
                    label: const Text('Documento / PDF'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _uploading
                        ? null
                        : () => context.push(AppRoutes.signature),
                    icon: const Icon(Icons.draw_outlined, size: 18),
                    label: const Text('Firma'),
                  ),
                ),
              ]),
              if (_uploading) ...[
                const SizedBox(height: 8),
                const LinearProgressIndicator(),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
        // Griglia allegati
        Expanded(
          child: async.when(
            loading: () => const WfmLoading(),
            error: (e, _) => WfmErrorState(message: e.toString()),
            data: (list) => list.isEmpty
                ? const EmptyState(
                    title: 'Nessun allegato',
                    subtitle: 'Aggiungi foto, documenti o acquisisci la firma.',
                    icon: Icons.attachment_outlined,
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: list.length,
                    itemBuilder: (_, i) => _AttachmentTile(
                      attachment: list[i],
                      onTap: () => _openAttachment(list[i]),
                      onLongPress: () => _showAttachmentMenu(list[i]),
                      imageWidget: list[i].isImage ? _imageWidget(list[i]) : null,
                      fileIcon: _fileIcon(list[i].mimeType),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

// Tile singolo allegato
class _AttachmentTile extends StatelessWidget {
  final Attachment attachment;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final Widget? imageWidget;
  final IconData fileIcon;

  const _AttachmentTile({
    required this.attachment,
    required this.onTap,
    required this.onLongPress,
    required this.imageWidget,
    required this.fileIcon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Stack(
          children: [
            // Anteprima
            if (imageWidget != null)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: imageWidget,
                ),
              )
            else
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(fileIcon, color: AppColors.primary, size: 28),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        attachment.type.label,
                        style: AppTextStyles.labelSmall,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            // Badge upload status
            if (attachment.uploadStatus == UploadStatus.local)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    color: AppColors.accentOrange,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.cloud_upload_outlined, size: 10, color: Colors.white),
                ),
              ),
            if (attachment.uploadStatus == UploadStatus.uploading)
              const Positioned(
                top: 4,
                right: 4,
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.primary),
                ),
              ),
            // Icona long-press hint (angolo in basso a destra)
            const Positioned(
              bottom: 4,
              right: 4,
              child: Icon(Icons.more_vert, size: 12, color: Colors.black38),
            ),
          ],
        ),
      ),
    );
  }
}

