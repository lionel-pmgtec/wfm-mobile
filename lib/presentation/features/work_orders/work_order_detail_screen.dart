// PAGINA 4 — Dettaglio OdL con 5 schede e barra azioni ciclo di vita.

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/config/capabilities.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/services/geolocation_service.dart';
import '../../../core/services/image_compression_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';
import '../../providers/attachments_provider.dart';
import '../../providers/capabilities_provider.dart';
import '../../providers/odl_extension_provider.dart';
import '../../providers/work_orders_provider.dart';
import '../../widgets/sync_widgets.dart';
import '../esito/esito_screen.dart';
import 'widgets/lifecycle_action_bar.dart';
import 'widgets/odl_actions_menu.dart';
import 'widgets/odl_inline_sections.dart';

class WorkOrderDetailScreen extends ConsumerWidget {
  final String code;
  const WorkOrderDetailScreen({super.key, required this.code});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(workOrderDetailProvider(code));
    return async.when(
      loading: () => Scaffold(
        appBar: AppBar(
          title: Text('OdL $code'),
        ),
        body: const WfmLoading(message: 'Caricamento OdL…'),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(
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
    // Conteggio allegati dalla lista reale (locale + remoto), non da order.
    final attCount = ref.watch(attachmentsProvider(order.externalCode)).valueOrNull?.length ??
        order.attachmentsCount;
    // Materiali = pianificati SAP + impegnati sul campo (locali). Watch così il
    // contatore dell'etichetta si aggiorna a ogni aggiunta/rimozione.
    final matCount = order.plannedMaterials.length +
        ref.watch(odlExtensionProvider(order.externalCode)).materiali.length;
    return Scaffold(
      appBar: AppBar(
        title: Text('OdL ${order.externalCode}'),
        actions: [
          const SyncIconButton(color: Colors.white),
          OdlActionsMenu(code: order.externalCode, order: order),
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
            Tab(text: 'Materiali ($matCount)'),
            Tab(text: 'Allegati ($attCount)'),
            const Tab(text: 'Chiusura'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Ordine ancora solo sul tablet: l'invio è a un tocco, su ogni
          // scheda. Il banner sparisce da solo una volta inviato.
          SyncPendingBanner(
              id: order.externalCode,
              message: 'Questo ordine è stato creato sul tablet e non è '
                  'ancora stato inviato al cruscotto.'),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _DettaglioTab(order: order),
                _OperazioniTab(order: order),
                _ComponentiTab(order: order),
                _AllegatiTab(code: order.externalCode),
                _ChiusuraTab(order: order),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: LifecycleActionBar(order: order),
    );
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

class _DettaglioTab extends ConsumerWidget {
  final WorkOrder order;
  const _DettaglioTab({required this.order});

  /// Sezione con intestazione, spenta quando la sorgente dati non la alimenta.
  ///
  /// Tre casi distinti, che prima si confondevano in uno solo:
  ///  - alimentata e con dati        -> intestazione + contenuto;
  ///  - alimentata ma senza dati     -> niente (il form si adatta al tipo di OdL,
  ///                                    comportamento storico);
  ///  - non alimentata dalla sorgente -> intestazione + spiegazione + contenuto
  ///                                    spento. Il codice resta vivo: riaccendere
  ///                                    la capability lato middleware lo riporta
  ///                                    in funzione senza ricompilare l'app.
  List<Widget> _section({
    required bool enabled,
    required String reason,
    required bool hasData,
    required String title,
    required Widget child,
  }) {
    if (enabled && !hasData) return const [];
    return [
      SectionHeader(title: title),
      CapabilityGate(enabled: enabled, reason: reason, child: child),
    ];
  }

  /// "gg/mm/aaaa hh:mm" — o solo la data se manca l'ora, o '' se manca tutto.
  String _fmtDataOra(DateTime? d, String? ora) {
    if (d == null) return '';
    final data = Fmt.date(d);
    return (ora ?? '').trim().isEmpty ? data : '$data ${ora!.trim()}';
  }

  /// Modifica la nota ordine e la invia al backend (PATCH /work-orders/:id,
  /// che accetta solo `notes`).
  Future<void> _editNota(BuildContext context, WidgetRef ref) async {
    // Si modifica SOLO la nota del campo: la descrizione SAP resta intatta.
    final ctrl = TextEditingController(text: order.noteAggiunte);
    final nuovo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nota del campo'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 5,
          minLines: 3,
          decoration: const InputDecoration(
            hintText: 'Inserisci la nota del tecnico…',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annulla')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Salva')),
        ],
      ),
    );
    ctrl.dispose();
    if (nuovo == null || nuovo == order.noteAggiunte.trim()) return;
    if (!context.mounted) return;
    // `notes` = ciò che il PATCH invia al backend (→ nota del campo `a.note`);
    // `noteAggiunte` aggiorna subito la visualizzazione locale.
    final res = await ref
        .read(workOrderActionsProvider)
        .save(order.copyWith(notes: nuovo, noteAggiunte: nuovo));
    if (!context.mounted) return;
    res.when(
      success: (_) => showSapToast(context, 'Nota aggiornata'),
      failure: (f) =>
          showSapToast(context, 'Errore: ${f.message}', isError: true),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caps = ref.watch(capabilitiesProvider);
    final reason = caps.unavailableReason;

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
                  order.displayName,
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
          // Stringa stato reale SAP (CO_STTXT): distingue RIL. (aperto) da
          // TECO (chiuso tecnicamente), info che lo status applicativo perde.
          FieldRow(
              label: 'Stato SAP',
              value: order.statoSap ?? '',
              hideIfEmpty: true),
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
              unavailable: !caps.has(Cap.odlRisorse),
              unavailableReason: reason,
              trailing: caps.has(Cap.odlRisorse) && caps.has(Cap.writeSap)
                  ? IconButton(
                      tooltip: 'Cambia CID',
                      icon: const Icon(Icons.swap_horiz_rounded,
                          size: 18, color: AppColors.primary),
                      onPressed: () => context
                          .push(AppRoutes.cambioCidPath(order.externalCode)),
                    )
                  : null),
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
              hideIfEmpty: true,
              unavailable: !caps.has(Cap.odlAppuntamento),
              unavailableReason: reason),
          FieldRow(
              label: 'Ora Appuntamento',
              value: order.appointmentStartTime,
              hideIfEmpty: true,
              unavailable: !caps.has(Cap.odlAppuntamento),
              unavailableReason: reason),
          FieldRow(
              label: 'Settore Contabile',
              value: order.accountingSector,
              hideIfEmpty: true),
        ]),

        // ── 2. CLIENTE ──────────────────────────────────────────────
        // Non esposto da ZWFMT_SERVIZIO_PM: servirebbero i partner IHPA + ADRC.
        ..._section(
          enabled: caps.has(Cap.odlCliente),
          reason: reason,
          hasData: !order.customer.isEmpty || (order.referente ?? '').isNotEmpty,
          title: 'CLIENTE',
          child: FormGrid(children: [
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
        ),

        // ── 3. INDIRIZZI ────────────────────────────────────────────
        // Non esposti da ZWFMT_SERVIZIO_PM: servirebbero ILOA + ADRC.
        const SectionHeader(title: 'INDIRIZZI'),
        CapabilityGate(
          enabled: caps.has(Cap.odlIndirizzi),
          reason: reason,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FieldRow(
                label: 'Indirizzo Cliente',
                value: order.address.full,
                fullWidth: true,
                trailing: order.address.hasCoordinates
                    ? IconButton(
                        icon: const Icon(Icons.map_outlined,
                            color: AppColors.primary),
                        onPressed: () => context.go(AppRoutes.map))
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
                          onPressed: () => context.go(AppRoutes.map))
                      : null,
                ),
              ],
              const SizedBox(height: 8),
              FormGrid(children: [
                FieldRow(
                    label: 'Coordinate GPS',
                    value: (order.indirizzoIntervento ?? order.address)
                        .gpsCoordinates,
                    hideIfEmpty: true),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Fuori dal gate: sede tecnica ed equipment SAP li espone davvero.
        FormGrid(children: [
          FieldRow(
              label: 'Ubicazione Tecnica',
              value: order.ubicazione,
              hideIfEmpty: true),
          FieldRow(
              label: 'Equipment',
              value: order.equipment,
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
              hideIfEmpty: true,
              unavailable: !caps.has(Cap.odlContatore),
              unavailableReason: reason),
          FieldRow(
              label: 'Ubicazione Tecnica',
              value: order.ubicazione,
              hideIfEmpty: true),
          FieldRow(
              label: 'Impianto',
              value: order.impianto,
              hideIfEmpty: true),
        ]),

        // ── CONTATORE ───────────────────────────────────────────────
        // Non esposto da ZWFMT_SERVIZIO_PM: servirebbero i punti di misura
        // IMPTT/IMRG. Senza, ATTI/SOST/DISA restano senza letture.
        ..._section(
          enabled: caps.has(Cap.odlContatore),
          reason: reason,
          hasData: order.hasMeter,
          title: 'CONTATORE',
          child: order.hasMeter
              ? FormGrid(children: [
                  FieldRow(label: 'Matricola', value: order.meter!.matricola),
                  FieldRow(
                      label: 'Marca/Modello',
                      value: order.meter!.displayName,
                      hideIfEmpty: true),
                  FieldRow(
                      label: 'Calibro',
                      value: order.meter!.caliber,
                      hideIfEmpty: true),
                  FieldRow(
                      label: 'Settore',
                      value: order.meter!.sector,
                      hideIfEmpty: true),
                  FieldRow(
                      label: 'Ubicazione',
                      value: order.meter!.location,
                      hideIfEmpty: true),
                  // "Ultima Lettura" = lettura precedente reale (SAP PREC_VALORE),
                  // il campo `lastReading` (LETTURA corrente) di solito è vuoto.
                  FieldRow(
                      label: 'Ultima Lettura',
                      value: (order.meter!.previousReading ??
                                  order.meter!.lastReading)
                              ?.toString() ??
                          '',
                      hideIfEmpty: true),
                  FieldRow(
                      label: 'Data Lettura',
                      value: _fmtDataOra(
                          order.meter!.previousReadingDate ??
                              order.meter!.lastReadingDate,
                          order.meter!.previousReadingTime),
                      hideIfEmpty: true),
                  FieldRow(
                      label: 'Stato Lettura',
                      value: order.meter!.previousReadingStatus ?? '',
                      hideIfEmpty: true),
                ])
              // Capability spenta e nessun contatore: si mostra la forma della
              // sezione, spenta, invece di far sparire tutto senza spiegazione.
              : FormGrid(children: [
                  FieldRow(
                      label: 'Matricola',
                      value: '',
                      unavailable: true,
                      unavailableReason: reason),
                  FieldRow(
                      label: 'Ultima Lettura',
                      value: '',
                      unavailable: true,
                      unavailableReason: reason),
                ]),
        ),

        // ── 5. RISORSE ──────────────────────────────────────────────
        // Tecnico assegnato e squadra non sono esposti: servirebbe IHPA.
        // È anche il motivo per cui manca il filtro "i miei ODL".
        const SectionHeader(title: 'RISORSE'),
        CapabilityGate(
          enabled: caps.has(Cap.odlRisorse),
          reason: reason,
          child: FormGrid(children: [
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
        ),
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
        ..._section(
          enabled: caps.has(Cap.odlAmpliamento),
          reason: reason,
          hasData: (order.impiantoDis ?? '').isNotEmpty ||
              (order.contratto ?? '').isNotEmpty,
          title: 'AMPLIAMENTO',
          child: FormGrid(children: [
            FieldRow(
                label: 'Impianto Disattivazione',
                value: order.impiantoDis ?? '',
                hideIfEmpty: true,
                unavailable: !caps.has(Cap.odlAmpliamento),
                unavailableReason: reason),
            FieldRow(
                label: 'Contratto',
                value: order.contratto ?? '',
                hideIfEmpty: true,
                unavailable: !caps.has(Cap.odlAmpliamento),
                unavailableReason: reason),
          ]),
        ),

        // ── 7. PIANIFICAZIONE ──────────────────────────────────────
        // Data Esecuzione arriva da SAP (CO_GSTRP): la sezione è alimentata.
        ..._section(
          enabled: caps.has(Cap.odlPianificazione),
          reason: reason,
          hasData: (order.ultimoCicloManutenzione ?? '').isNotEmpty ||
              (order.postManut ?? '').isNotEmpty ||
              order.dataEsec != null ||
              order.dataFine != null,
          title: 'PIANIFICAZIONE',
          child: FormGrid(children: [
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
            // Data fine prevista SAP (CO_GLTRP): valorizzata al 100% e diversa
            // dall'inizio in ~1 ordine su 3.
            FieldRow(
                label: 'Data Fine Prevista',
                value: Fmt.date(order.dataFine),
                hideIfEmpty: true),
          ]),
        ),

        // ── NOTE OPERATIVE ────────────────────────────────────────
        // Unico campo del dettaglio modificabile: il backend persiste solo la
        // nota (PATCH /work-orders/:id accetta esclusivamente `notes`). Gli
        // altri campi sono dati SAP in sola lettura.
        const SectionHeader(title: 'NOTE'),
        // Nota SAP: descrizione dell'ordine, SOLA LETTURA (arriva da SAP).
        FieldRow(
            label: 'Descrizione ordine (SAP)',
            value: order.noteSap.trim().isEmpty
                ? (order.notes.trim().isEmpty ? '—' : order.notes)
                : order.noteSap,
            fullWidth: true,
            maxLines: 4),
        const SizedBox(height: 8),
        // Note del campo: aggiunte dal tecnico, modificabili (PATCH `notes`).
        if (caps.has(Cap.odlNote))
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FieldRow(
                  label: 'Note del campo',
                  value: order.noteAggiunte.trim().isEmpty
                      ? '—'
                      : order.noteAggiunte,
                  fullWidth: true,
                  maxLines: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _editNota(context, ref),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: Text(order.noteAggiunte.trim().isEmpty
                      ? 'Aggiungi nota'
                      : 'Modifica nota'),
                ),
              ),
            ],
          )
        else
          CapabilityGate(
            enabled: false,
            reason: reason,
            child: FieldRow(
                label: 'Note del campo',
                value: order.noteAggiunte,
                fullWidth: true,
                maxLines: 4,
                unavailable: true,
                unavailableReason: reason),
          ),

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
                enabled: caps.has(Cap.odlAppuntamento),
                disabledReason: reason,
                onTap: () =>
                    context.push(AppRoutes.appointmentsPath(order.externalCode))),
            _QuickActionChip(
                icon: Icons.history_rounded,
                label: 'Storico',
                enabled: caps.has(Cap.odlAppuntamento),
                disabledReason: reason,
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
                enabled: caps.has(Cap.odlMateriali),
                disabledReason: reason,
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

  /// Spento quando la sorgente dati non alimenta ciò su cui l'azione lavora:
  /// aprire la schermata mostrerebbe solo campi vuoti.
  final bool enabled;
  final String? disabledReason;

  const _QuickActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
    this.disabledReason,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return Tooltip(
        message: disabledReason ?? 'Dati non disponibile',
        triggerMode: TooltipTriggerMode.tap,
        child: Opacity(opacity: 0.4, child: _chip(onTap: null)),
      );
    }
    return _chip(onTap: onTap);
  }

  Widget _chip({required VoidCallback? onTap}) {
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
// Scorciatoia verso la schermata Esito, unico punto di chiusura reale dell'OdL
// (tempi, esito, causa/soluzione, ore/costi, firma → "Convalida e invia esito").
class _ChiusuraTab extends StatelessWidget {
  final WorkOrder order;
  const _ChiusuraTab({required this.order});

  @override
  Widget build(BuildContext context) {
    if (order.isClosed) {
      return ListView(
        padding: kPagePadding,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.statusDoneBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              const Icon(Icons.check_circle_outline, color: AppColors.accentGreen),
              const SizedBox(width: 10),
              Expanded(
                child: Text('OdL ${order.status.label.toLowerCase()}. Intervento concluso.',
                    style: AppTextStyles.bodyMedium),
              ),
            ]),
          ),
        ],
      );
    }
    // Niente pagina intermedia: la scheda "Chiusura" mostra direttamente il
    // form di esito (in modalità incorporata, senza Scaffold/AppBar propri).
    return EsitoScreen(code: order.externalCode, embedded: true);
  }
}

// ─── SCHEDA OPERAZIONI ─────────────────────────────────────────────────────
// Tabella operazioni editabile (spec).
// Colonne: Op | Codice | Testo Breve | CID | Descrizione | Inizio Prev |
//          Fine Prev | Durata Eff. | Tempo Lavoro
// L'operatore puo aggiungere righe (anche piu righe per lo stesso CID).

class _OperazioniTab extends ConsumerStatefulWidget {
  final WorkOrder order;
  const _OperazioniTab({required this.order});

  @override
  ConsumerState<_OperazioniTab> createState() => _OperazioniTabState();
}

class _OperazioniTabState extends ConsumerState<_OperazioniTab> {
  late List<Operation> _ops;
  final Map<String, TextEditingController> _hoursCtrls = {};

  @override
  void initState() {
    super.initState();
    _ops = List.of(widget.order.operations);
    // Ripristina le ore già digitate (persistite in locale, per la chiusura).
    final salvate = {
      for (final o
          in ref.read(odlExtensionProvider(widget.order.externalCode)).ore)
        o.operationNumber: o.hours,
    };
    if (salvate.isNotEmpty) {
      _ops = [
        for (final op in _ops)
          salvate.containsKey(op.number)
              ? op.copyWith(durataEffettiva: salvate[op.number])
              : op,
      ];
    }
  }

  /// Salva le ore in locale così che la chiusura possa trasmetterle
  /// (POST /esiti → `hoursWorked`, di cui il backend conserva la somma).
  void _persistOre() {
    final ore = [
      for (final op in _ops)
        if (op.effectiveHours != null)
          OdlOreLavorate(
            operationNumber: op.number,
            description:
                op.testoBreve.isNotEmpty ? op.testoBreve : op.description,
            hours: op.effectiveHours!,
            isAutomezzo: _isAutomezzo(op),
          ),
    ];
    ref
        .read(odlExtensionProvider(widget.order.externalCode).notifier)
        .setOre(ore);
  }

  @override
  void dispose() {
    for (final c in _hoursCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _opKey(Operation op) => op.id.isNotEmpty ? op.id : op.number;

  /// Automezzo = voce le cui ore NON si scrivono: sono la somma delle voci di
  /// lavoro. Il backend non manda un tipo (A_LAVO/A_AUTO), quindi lo si
  /// riconosce dal testo ("Automezzi"/"Automezzo").
  bool _isAutomezzo(Operation op) =>
      '${op.testoBreve} ${op.description}'.toLowerCase().contains('automezz');

  /// Somma delle ore effettive delle voci di LAVORO (non automezzo).
  num _lavoroSum() => _ops
      .where((o) => !_isAutomezzo(o))
      .fold<num>(0, (s, o) => s + (o.effectiveHours ?? 0));

  TextEditingController _hoursCtrl(Operation op) => _hoursCtrls.putIfAbsent(
        _opKey(op),
        () => TextEditingController(
            text: op.effectiveHours == null ? '' : '${op.effectiveHours}'),
      );

  void _setHoursAt(int i, String raw) {
    final v = num.tryParse(raw.replaceAll(',', '.'));
    setState(() => _ops[i] = _ops[i].copyWith(durataEffettiva: v));
    _persistOre();
  }

  void _remove(Operation op) {
    setState(() => _ops.removeWhere((o) => o.id == op.id));
    _persistOre();
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
                'Le operazioni arrivano da SAP con l\'ordine (Trasferimento, Lavori Idraulici, Automezzi).',
            icon: Icons.list_alt_outlined,
          )
        else
          ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
            itemCount: _ops.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final op = _ops[i];
              final auto = _isAutomezzo(op);
              return _OperazioneRow(
                op: op,
                isAutomezzo: auto,
                computedHours: auto ? _lavoroSum() : null,
                hoursCtrl: auto ? null : _hoursCtrl(op),
                onHoursChanged: (v) => _setHoursAt(i, v),
                onDelete: () => _remove(op),
                onToggleDone: () => _toggleDone(op),
              );
            },
          ),
      ],
    );
  }
}

class _OperazioneRow extends StatelessWidget {
  final Operation op;
  final bool isAutomezzo;
  final num? computedHours; // ore = somma (solo automezzo)
  final TextEditingController? hoursCtrl; // editabile (solo voci di lavoro)
  final ValueChanged<String>? onHoursChanged;
  final VoidCallback onDelete;
  final VoidCallback onToggleDone;
  const _OperazioneRow({
    required this.op,
    this.isAutomezzo = false,
    this.computedHours,
    this.hoursCtrl,
    this.onHoursChanged,
    required this.onDelete,
    required this.onToggleDone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
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
                radius: 15,
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
              child: Text(
                  op.testoBreve.isEmpty ? op.description : op.testoBreve,
                  style: AppTextStyles.bodyLarge
                      .copyWith(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
            if (op.cid.isNotEmpty) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(op.cid,
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary)),
              ),
            ],
          ]),
          const SizedBox(height: 6),
          // Una sola riga: info + ore (editabili o somma automezzo) + azioni.
          Row(children: [
            if (op.codice.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child:
                    Text('Cod. ${op.codice}', style: AppTextStyles.bodySmall),
              ),
            if (op.plannedHours != null)
              Text('Pianif. ${op.plannedHours}h',
                  style: AppTextStyles.bodySmall),
            const Spacer(),
            if (isAutomezzo)
              Text('Automezzo: ${computedHours ?? 0} h',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.accentGreen))
            else
              SizedBox(
                width: 150,
                child: TextField(
                  controller: hoursCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Durata Effettiva',
                    isDense: true,
                    suffixText: 'h',
                  ),
                  onChanged: onHoursChanged,
                ),
              ),
            const SizedBox(width: 4),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Elimina',
              icon: const Icon(Icons.delete_outline,
                  size: 18, color: AppColors.accentRed),
              onPressed: onDelete,
            ),
          ]),
        ],
      ),
    );
  }
}


// ─── SCHEDA COMPONENTI ─────────────────────────────────────────────────────

class _ComponentiTab extends ConsumerWidget {
  final WorkOrder order;
  const _ComponentiTab({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caps = ref.watch(capabilitiesProvider);
    final materialiDisponibili = caps.has(Cap.odlMateriali);

    // Materiali dell'ordine (SAP) + quelli impegnati sul campo, che restano
    // sul tablet finché non partono con l'esito.
    final locali = ref.watch(odlExtensionProvider(order.externalCode)).materiali;
    final materiali = [...order.plannedMaterials, ...locali];

    final addButton = Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: materialiDisponibili
              ? () => context.push(AppRoutes.addComponentePath(order.externalCode))
              : null,
          icon: const Icon(Icons.add),
          label: const Text('Aggiungi materiale'),
        ),
      ),
    );

    // I materiali pianificati stanno in RESB, che il servizio SAP esclude di
    // proposito: dirlo è meglio che lasciar credere che l'OdL non ne abbia.
    if (!materialiDisponibili && materiali.isEmpty) {
      return Column(
        children: [
          Expanded(
            child: EmptyState(
              title: 'Materiali non disponibili',
              subtitle: caps.unavailableReason,
              icon: Icons.inventory_2_outlined,
            ),
          ),
          addButton,
        ],
      );
    }

    if (materiali.isEmpty) {
      return Column(
        children: [
          const Expanded(
            child: EmptyState(
              title: 'Nessun materiale',
              subtitle: 'Aggiungi i materiali utilizzati durante l\'intervento.',
              icon: Icons.inventory_2_outlined,
            ),
          ),
          addButton,
        ],
      );
    }
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: kPagePadding,
            itemCount: materiali.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final m = materiali[i];
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
          ),
        ),
        addButton,
      ],
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

