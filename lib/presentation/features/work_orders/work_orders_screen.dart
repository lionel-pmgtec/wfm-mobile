// PAGINA — Elenco Ordini di Lavoro .

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';
import '../../../domain/repositories/work_order_repository.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/creation_provider.dart';
import '../../providers/realtime_provider.dart';
import '../../providers/work_orders_provider.dart';
import 'widgets/excel_import_sheet.dart';
import 'widgets/odl_actions_menu.dart';

class WorkOrdersScreen extends ConsumerStatefulWidget {
  const WorkOrdersScreen({super.key});

  @override
  ConsumerState<WorkOrdersScreen> createState() => _WorkOrdersScreenState();
}

class _WorkOrdersScreenState extends ConsumerState<WorkOrdersScreen> {
  bool _searching = false;
  final _searchCtrl = TextEditingController();

  // Paginazione incrementale lato app: SAP restituisce tutto in un colpo (nessuna
  // paginazione server), quindi si mostra la lista a blocchi per non costruire
  // centinaia di card in una volta. Il contatore riparte quando cambiano i filtri.
  static const int _pageSize = 15;
  int _visible = _pageSize;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _applyQuery(String q) {
    final current = ref.read(workOrderFilterProvider);
    ref.read(workOrderFilterProvider.notifier).state =
        current.copyWith(query: q);
  }

  /// Ricarica dal backend gli ordini assegnati (nuove assegnazioni, stati).
  Future<void> _refreshFromSap() async {
    try {
      await ref.read(refreshFromSapProvider)();
    } catch (_) {
      if (mounted) {
        showSapToast(context, 'Aggiornamento non riuscito', isError: true);
      }
    }
  }

  /// Conferma + eliminazione di un OdL. Ritorna true se eliminato (l'item
  /// scompare); false se annullato o in errore (l'item resta).
  Future<bool> _confirmAndDeleteOdl(String code) async { 
    final ok = await showWfmConfirmDialog(
      context: context,
      title: 'Eliminare l\'OdL?',
      message: 'L\'ordine di lavoro $code sarà eliminato definitivamente.',
      confirmLabel: 'Elimina',
      tone: WfmDialogTone.danger,
    );
    if (ok != true) return false;
    final res = await ref.read(workOrderActionsProvider).delete(code);
    if (!mounted) return true;
    return res.when(
      success: (_) {
        showSapToast(context, 'OdL $code eliminato');
        return true;
      },
      failure: (f) {
        showSapToast(context, 'Errore: ${f.message}', isError: true);
        return false;
      },
    );
  }

  /// Invia al cruscotto gli OdL/avvisi creati sul tablet. Se non ce ne sono,
  /// apre la coda delle operazioni offline (comportamento precedente).
  Future<void> _syncAll() async {
    final created = ref.read(pendingCreationCountProvider).valueOrNull ?? 0;
    if (created == 0) {
      context.push(AppRoutes.syncQueue);
      return;
    }
    showSapToast(context, 'Sincronizzazione in corso…');
    final res = await ref.read(creationControllerProvider).syncAll();
    if (!mounted) return;
    if (res.failed == 0) {
      showSapToast(context, 'Sincronizzati ${res.ok} elementi');
    } else {
      showSapToast(
        context,
        '${res.ok} inviati, ${res.failed} in attesa — ${res.firstError ?? 'cruscotto non pronto'}',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Al cambio dei filtri la lista riparte dalla prima pagina.
    ref.listen(workOrderFilterProvider, (_, __) {
      if (_visible != _pageSize) setState(() => _visible = _pageSize);
    });
    final ordersAsync = ref.watch(workOrdersProvider);
    final filter = ref.watch(workOrderFilterProvider);
    final online = ref.watch(connectivityStatusProvider);
    final pending = ref.watch(pendingSyncCountProvider).valueOrNull ?? 0;
    final createdPending =
        ref.watch(pendingCreationCountProvider).valueOrNull ?? 0;
    final advancedCount = _advancedFilterCount(filter);

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? Theme(
                data: Theme.of(context).copyWith(
                  inputDecorationTheme: const InputDecorationTheme(
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  cursorColor: Colors.white,
                  decoration: const InputDecoration(
                    hintText: 'Cerca per numero, indirizzo, cliente…',
                    hintStyle: TextStyle(color: Colors.white60, fontSize: 14),
                  ),
                  onChanged: _applyQuery,
                ),
              )
            : const Text('Ordini di Lavoro'),
        actions: [
          IconButton(
            tooltip: _searching ? 'Chiudi ricerca' : 'Cerca',
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() => _searching = !_searching);
              if (!_searching) {
                _searchCtrl.clear();
                _applyQuery('');
              }
            },
          ),
          // Filtri avanzati
          Stack(
            alignment: Alignment.topRight,
            children: [
              IconButton(
                tooltip: 'Filtri avanzati',
                icon: const Icon(Icons.tune_rounded),
                onPressed: () => _showAdvancedFilters(context, filter),
              ),
              if (advancedCount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: AppColors.accentOrange,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$advancedCount',
                        style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            tooltip: 'Aggiorna',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refreshFromSap,
          ),
          IconButton(
            tooltip: 'Importa Excel',
            icon: const Icon(Icons.table_chart_outlined),
            onPressed: () => showExcelImportSheet(context, ref),
          ),
          IconButton(
            tooltip: 'Mappa OdL',
            icon: const Icon(Icons.map_outlined),
            onPressed: () => context.go(AppRoutes.map),
          ),
          IconButton(
            tooltip: 'Sincronizza',
            icon: Badge(
              isLabelVisible: (pending + createdPending) > 0,
              label: Text('${pending + createdPending}'),
              child: const Icon(Icons.cloud_sync_outlined),
            ),
            onPressed: _syncAll,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.createOrder),
        icon: const Icon(Icons.add),
        label: const Text('Nuovo OdL'),
      ),
      body: Column(
        children: [
          if (!online || pending > 0)
            Container(
              width: double.infinity,
              color: AppColors.statusInProgressBg,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(children: [
                WfmOfflineBadge(offline: !online, pendingCount: pending),
              ]),
            ),
          _statusFilterBar(filter),
          // Mostra chip filtri attivi (data, squadra, centroLavoro, tecnico)
          if (advancedCount > 0) _activeFiltersRow(filter),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshFromSap,
              child: ordersAsync.when(
                loading: () => ListView.builder(
                  itemCount: 6,
                  itemBuilder: (_, __) => const WorkOrderShimmerItem(),
                ),
                error: (e, _) => ListView(children: [
                  const SizedBox(height: 80),
                  WfmErrorState(
                      message: e.toString(),
                      onRetry: () => ref.invalidate(workOrdersProvider)),
                ]),
                data: (orders) {
                  if (orders.isEmpty) {
                    return ListView(children: const [
                      SizedBox(height: 80),
                      EmptyState(
                        title: 'Nessun OdL trovato',
                        subtitle:
                            'Modifica i filtri o aggiorna per sincronizzare con SAP.',
                        icon: Icons.assignment_outlined,
                      ),
                    ]);
                  }
                  final visible =
                      _visible >= orders.length ? orders.length : _visible;
                  final hasMore = orders.length > visible;
                  return ListView.builder(
                    padding: const EdgeInsets.only(top: 6, bottom: 90),
                    itemCount: visible + (hasMore ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i >= visible) {
                        return _LoadMoreTile(
                          shown: visible,
                          total: orders.length,
                          onTap: () => setState(() => _visible += _pageSize),
                        );
                      }
                      final o = orders[i];
                      return Dismissible(
                        key: ValueKey('odl_${o.externalCode}'),
                        direction: DismissDirection.endToStart,
                        background: const WfmSwipeDeleteBackground(),
                        confirmDismiss: (_) =>
                            _confirmAndDeleteOdl(o.externalCode),
                        child: _WorkOrderItem(
                          order: o,
                          onTap: () => context.push(
                              AppRoutes.workOrderDetailPath(o.externalCode)),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _advancedFilterCount(WorkOrderFilter f) {
    int c = 0;
    if (f.date != null) c++;
    if (f.dateFrom != null) c++;
    if (f.dateTo != null) c++;
    if (f.centro != null && f.centro!.isNotEmpty) c++;
    if (f.squadra != null && f.squadra!.isNotEmpty) c++;
    if (f.centroLavoro != null && f.centroLavoro!.isNotEmpty) c++;
    if (f.tecnico != null && f.tecnico!.isNotEmpty) c++;
    return c;
  }

  Widget _activeFiltersRow(WorkOrderFilter filter) {
    final chips = <Widget>[];
    if (filter.dateFrom != null || filter.dateTo != null) {
      final da = filter.dateFrom != null ? Fmt.date(filter.dateFrom) : '…';
      final a = filter.dateTo != null ? Fmt.date(filter.dateTo) : '…';
      chips.add(_filterChip('Creati: $da → $a', () {
        ref.read(workOrderFilterProvider.notifier).state =
            filter.copyWith(clearDateFrom: true, clearDateTo: true);
      }));
    }
    if (filter.centro != null && filter.centro!.isNotEmpty) {
      chips.add(_filterChip('Centro: ${filter.centro}', () {
        ref.read(workOrderFilterProvider.notifier).state =
            filter.copyWith(clearCentro: true);
      }));
    }
    if (filter.date != null) {
      chips.add(_filterChip('Data: ${Fmt.date(filter.date)}', () {
        ref.read(workOrderFilterProvider.notifier).state =
            filter.copyWith(clearDate: true);
      }));
    }
    if (filter.squadra != null && filter.squadra!.isNotEmpty) {
      chips.add(_filterChip('Squadra: ${filter.squadra}', () {
        ref.read(workOrderFilterProvider.notifier).state =
            filter.copyWith(clearSquadra: true);
      }));
    }
    if (filter.centroLavoro != null && filter.centroLavoro!.isNotEmpty) {
      chips.add(_filterChip('CL: ${filter.centroLavoro}', () {
        ref.read(workOrderFilterProvider.notifier).state =
            filter.copyWith(clearCentroLavoro: true);
      }));
    }
    if (filter.tecnico != null && filter.tecnico!.isNotEmpty) {
      chips.add(_filterChip('Tecnico: ${filter.tecnico}', () {
        ref.read(workOrderFilterProvider.notifier).state =
            filter.copyWith(clearTecnico: true);
      }));
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(children: chips),
    );
  }

  Widget _filterChip(String label, VoidCallback onDelete) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Chip(
          label: Text(label, style: const TextStyle(fontSize: 11)),
          deleteIcon: const Icon(Icons.close, size: 14),
          onDeleted: onDelete,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.symmetric(horizontal: 4),
        ),
      );

  Widget _statusFilterBar(WorkOrderFilter filter) {
    final chips = <(String, WorkOrderStatus?)>[
      ('Tutti', null),
      ('Assegnato', WorkOrderStatus.ricevuto),
      ('In esecuzione', WorkOrderStatus.inEsecuzione),
      ('In pausa', WorkOrderStatus.inPausa),
      ('Sospeso', WorkOrderStatus.sospeso),
      ('Chiuso', WorkOrderStatus.completato),
      ('Inviato SAP', WorkOrderStatus.inviatoSAP),
    ];
    return SizedBox(
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final selected = filter.status == chips[i].$2;
          return ChoiceChip(
            label: Text(chips[i].$1),
            selected: selected,
            labelStyle: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? AppColors.primary : AppColors.textPrimary,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            visualDensity: const VisualDensity(horizontal: 0.5, vertical: 0.5),
            materialTapTargetSize: MaterialTapTargetSize.padded,
            onSelected: (_) {
              final notifier = ref.read(workOrderFilterProvider.notifier);
              notifier.state = chips[i].$2 == null
                  ? filter.copyWith(clearStatus: true)
                  : filter.copyWith(status: chips[i].$2);
            },
          );
        },
      ),
    );
  }

  Future<void> _showAdvancedFilters(
      BuildContext context, WorkOrderFilter current) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AdvancedFilterSheet(current: current),
    );
  }
}

// ─── PANNELLO FILTRI AVANZATI ─────────────────────────────────────────────────

class _AdvancedFilterSheet extends ConsumerStatefulWidget {
  final WorkOrderFilter current;
  const _AdvancedFilterSheet({required this.current});

  @override
  ConsumerState<_AdvancedFilterSheet> createState() =>
      _AdvancedFilterSheetState();
}

class _AdvancedFilterSheetState extends ConsumerState<_AdvancedFilterSheet> {
  late DateTime? _date;
  late DateTime? _dateFrom;
  late DateTime? _dateTo;
  late final TextEditingController _squadraCtrl;
  late final TextEditingController _centroLavoroCtrl;
  late final TextEditingController _centroCtrl;
  late final TextEditingController _tecnicoCtrl;

  @override
  void initState() {
    super.initState();
    _date = widget.current.date;
    _dateFrom = widget.current.dateFrom;
    _dateTo = widget.current.dateTo;
    _squadraCtrl = TextEditingController(text: widget.current.squadra ?? '');
    _centroLavoroCtrl =
        TextEditingController(text: widget.current.centroLavoro ?? '');
    _centroCtrl = TextEditingController(text: widget.current.centro ?? '');
    _tecnicoCtrl = TextEditingController(text: widget.current.tecnico ?? '');
  }

  @override
  void dispose() {
    _squadraCtrl.dispose();
    _centroLavoroCtrl.dispose();
    _centroCtrl.dispose();
    _tecnicoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('Filtri avanzati', style: AppTextStyles.headingMedium),
            const Spacer(),
            TextButton(
              onPressed: _clearAll,
              child: const Text('Pulisci tutto'),
            ),
          ]),
          const SizedBox(height: 16),
          // ── Finestra di estrazione SAP (data di creazione ordine) ──────────
          const Text('ESTRAZIONE SAP (data creazione)',
              style: AppTextStyles.fieldLabel),
          const SizedBox(height: 4),
          const Text(
            'Amplia la finestra per vedere gli ordini più vecchi: di default '
            'SAP restituisce solo quelli creati di recente.',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: InkWell(
                onTap: () => _pickWindowDate(isFrom: true),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Dal',
                    prefixIcon: Icon(Icons.event_available_outlined),
                  ),
                  child: Text(
                    _dateFrom != null ? Fmt.date(_dateFrom) : '—',
                    style: AppTextStyles.fieldValue,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                onTap: () => _pickWindowDate(isFrom: false),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Al',
                    prefixIcon: Icon(Icons.event_busy_outlined),
                  ),
                  child: Text(
                    _dateTo != null ? Fmt.date(_dateTo) : '—',
                    style: AppTextStyles.fieldValue,
                  ),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: _centroCtrl,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Centro di Manutenzione',
              prefixIcon: Icon(Icons.factory_outlined),
              hintText: 'es. SP1',
            ),
          ),
          const Divider(height: 28),
          // Filtro data appuntamento (locale, sul risultato)
          InkWell(
            onTap: _pickDate,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Data appuntamento',
                prefixIcon: Icon(Icons.event_outlined),
                suffixIcon: Icon(Icons.chevron_right),
              ),
              child: Text(
                _date != null ? Fmt.date(_date) : 'Tutte le date',
                style: AppTextStyles.fieldValue,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _squadraCtrl,
            decoration: const InputDecoration(
              labelText: 'Squadra',
              prefixIcon: Icon(Icons.groups_outlined),
              hintText: 'es. Squadra Nord',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _centroLavoroCtrl,
            decoration: const InputDecoration(
              labelText: 'Centro di Lavoro',
              prefixIcon: Icon(Icons.business_outlined),
              hintText: 'es. WC01',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tecnicoCtrl,
            decoration: const InputDecoration(
              labelText: 'Tecnico (CID)',
              prefixIcon: Icon(Icons.person_outlined),
              hintText: 'es. VAIOTTIM',
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _apply,
              child: const Text('Applica filtri'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickWindowDate({required bool isFrom}) async {
    final d = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _dateFrom : _dateTo) ?? DateTime.now(),
      firstDate: DateTime(2015),
      lastDate: DateTime(2035),
    );
    if (d == null) return;
    setState(() {
      if (isFrom) {
        _dateFrom = d;
      } else {
        _dateTo = d;
      }
    });
  }

  void _clearAll() {
    setState(() {
      _date = null;
      _dateFrom = null;
      _dateTo = null;
      _squadraCtrl.clear();
      _centroLavoroCtrl.clear();
      _centroCtrl.clear();
      _tecnicoCtrl.clear();
    });
  }

  void _apply() {
    final current = ref.read(workOrderFilterProvider);
    final centro = _centroCtrl.text.trim();
    ref.read(workOrderFilterProvider.notifier).state = current.copyWith(
      date: _date,
      clearDate: _date == null,
      dateFrom: _dateFrom,
      clearDateFrom: _dateFrom == null,
      dateTo: _dateTo,
      clearDateTo: _dateTo == null,
      centro: centro.isEmpty ? null : centro,
      clearCentro: centro.isEmpty,
      squadra: _squadraCtrl.text.trim().isEmpty ? null : _squadraCtrl.text.trim(),
      clearSquadra: _squadraCtrl.text.trim().isEmpty,
      centroLavoro: _centroLavoroCtrl.text.trim().isEmpty
          ? null
          : _centroLavoroCtrl.text.trim(),
      clearCentroLavoro: _centroLavoroCtrl.text.trim().isEmpty,
      tecnico: _tecnicoCtrl.text.trim().isEmpty ? null : _tecnicoCtrl.text.trim(),
      clearTecnico: _tecnicoCtrl.text.trim().isEmpty,
    );
    Navigator.pop(context);
  }
}

// ─── PULSANTE "CARICA ALTRI" (paginazione incrementale) ───────────────────────

class _LoadMoreTile extends StatelessWidget {
  final int shown;
  final int total;
  final VoidCallback onTap;
  const _LoadMoreTile(
      {required this.shown, required this.total, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          Text('Mostrati $shown di $total',
              style: AppTextStyles.bodySmall),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.expand_more_rounded, size: 18),
            label: Text('Carica altri (${total - shown})'),
          ),
        ],
      ),
    );
  }
}

// ─── ITEM LISTA OdL ───────────────────────────────────────────────────────────

class _WorkOrderItem extends StatelessWidget {
  final WorkOrder order;
  final VoidCallback onTap;
  const _WorkOrderItem({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: WfmCard(
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Gruppo sinistro elastico: il numero si accorcia con ellissi
                // se lo spazio è poco, così badge + menu restano sempre visibili.
                Expanded(
                  child: Row(
                    children: [
                      Text(order.typeEmoji,
                          style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(order.externalCode,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary)),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: AppColors.primarySurface,
                            borderRadius: BorderRadius.circular(4)),
                        child: Text(order.woType,
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                WoStatusBadge(status: order.status, small: true),
                OdlActionsMenu(
                  code: order.externalCode,
                  order: order,
                  iconColor: AppColors.textSecondary,
                ),
              ],
            ),
            Text(order.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyLarge
                    .copyWith(fontWeight: FontWeight.w600)),
            if (order.externalCode.startsWith('TMP-'))
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.accentOrange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: const [
                      Icon(Icons.cloud_off_rounded,
                          size: 11, color: AppColors.accentOrange),
                      SizedBox(width: 4),
                      Text('DA SINCRONIZZARE',
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accentOrange)),
                    ]),
                  ),
                ]),
              ),
            const SizedBox(height: 4),
            // Indirizzo · data (+ priorità). Stesso formato degli avvisi.
            // L'indirizzo non è ancora esposto da SAP (ILOA/ADRC): fino ad allora
            // resta la sola icona come segnaposto. La data è l'appuntamento se
            // presente, altrimenti esecuzione/creazione SAP.
            Row(children: [
              const Icon(Icons.place_outlined,
                  size: 14, color: AppColors.textHint),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  (order.address.short.isNotEmpty &&
                          order.address.short != '—')
                      ? '${order.address.short} · ${Fmt.date(order.appointmentDate ?? order.dataEsec ?? order.createdAt)}'
                      : '· ${Fmt.date(order.appointmentDate ?? order.dataEsec ?? order.createdAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall,
                ),
              ),
              if (order.priorita.isNotEmpty) ...[
                const SizedBox(width: 8),
                const Icon(Icons.flag_outlined,
                    size: 13, color: AppColors.textHint),
                const SizedBox(width: 3),
                Text(order.priorita, style: AppTextStyles.bodySmall),
              ],
              if (order.status == WorkOrderStatus.inPausa) ...[
                const SizedBox(width: 6),
                const Icon(Icons.pause_circle_outline,
                    size: 15, color: AppColors.accentOrange),
              ],
              if (order.localStatus == LocalSyncStatus.pendingUpload) ...[
                const SizedBox(width: 6),
                const Icon(Icons.cloud_upload_outlined,
                    size: 15, color: AppColors.accentOrange),
              ],
            ]),
            const SizedBox(height: 6),
            // Sede tecnica · equipment: il riferimento tecnico dell'ordine,
            // utile a distinguere ordini con descrizione simile.
            if (order.sedeTecnica.isNotEmpty || order.equipment.isNotEmpty)
              Row(children: [
                const Icon(Icons.engineering_outlined,
                    size: 13, color: AppColors.textHint),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    [
                      if (order.sedeTecnica.isNotEmpty) order.sedeTecnica,
                      if (order.equipment.isNotEmpty) 'Eq. ${order.equipment}',
                    ].join('  ·  '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary),
                  ),
                ),
              ]),
          ],
        ),
      ),
    );
  }
}
