// PAGINA 3 — Elenco Ordini di Lavoro (M2).

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
import '../../providers/work_orders_provider.dart';
import 'widgets/excel_import_sheet.dart';

class WorkOrdersScreen extends ConsumerStatefulWidget {
  const WorkOrdersScreen({super.key});

  @override
  ConsumerState<WorkOrdersScreen> createState() => _WorkOrdersScreenState();
}

class _WorkOrdersScreenState extends ConsumerState<WorkOrdersScreen> {
  bool _searching = false;
  final _searchCtrl = TextEditingController();

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

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(workOrdersProvider);
    final filter = ref.watch(workOrderFilterProvider);
    final online = ref.watch(connectivityStatusProvider);
    final pending = ref.watch(pendingSyncCountProvider).valueOrNull ?? 0;
    final advancedCount = _advancedFilterCount(filter);

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
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
                icon: const Icon(Icons.filter_list_rounded),
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
            tooltip: 'Importa Excel',
            icon: const Icon(Icons.table_chart_outlined),
            onPressed: () => showExcelImportSheet(context, ref),
          ),
          IconButton(
            tooltip: 'Mappa OdL',
            icon: const Icon(Icons.map_outlined),
            onPressed: () => context.push(AppRoutes.map),
          ),
          IconButton(
            tooltip: 'Sincronizza',
            icon: Badge(
              isLabelVisible: pending > 0,
              label: Text('$pending'),
              child: const Icon(Icons.cloud_sync_outlined),
            ),
            onPressed: () => context.push(AppRoutes.syncQueue),
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
              onRefresh: () async => ref.invalidate(workOrdersProvider),
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
                data: (orders) => orders.isEmpty
                    ? ListView(children: const [
                        SizedBox(height: 80),
                        EmptyState(
                          title: 'Nessun OdL trovato',
                          subtitle:
                              'Modifica i filtri o aggiorna per sincronizzare con SAP.',
                          icon: Icons.assignment_outlined,
                        ),
                      ])
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 6, bottom: 90),
                        itemCount: orders.length,
                        itemBuilder: (_, i) => _WorkOrderItem(
                          order: orders[i],
                          onTap: () => context.push(
                              AppRoutes.workOrderDetailPath(
                                  orders[i].externalCode)),
                        ),
                      ),
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
    if (f.squadra != null && f.squadra!.isNotEmpty) c++;
    if (f.centroLavoro != null && f.centroLavoro!.isNotEmpty) c++;
    if (f.tecnico != null && f.tecnico!.isNotEmpty) c++;
    return c;
  }

  Widget _activeFiltersRow(WorkOrderFilter filter) {
    final chips = <Widget>[];
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
  late final TextEditingController _squadraCtrl;
  late final TextEditingController _centroLavoroCtrl;
  late final TextEditingController _tecnicoCtrl;

  @override
  void initState() {
    super.initState();
    _date = widget.current.date;
    _squadraCtrl = TextEditingController(text: widget.current.squadra ?? '');
    _centroLavoroCtrl =
        TextEditingController(text: widget.current.centroLavoro ?? '');
    _tecnicoCtrl = TextEditingController(text: widget.current.tecnico ?? '');
  }

  @override
  void dispose() {
    _squadraCtrl.dispose();
    _centroLavoroCtrl.dispose();
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
          // Filtro data appuntamento
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

  void _clearAll() {
    setState(() {
      _date = null;
      _squadraCtrl.clear();
      _centroLavoroCtrl.clear();
      _tecnicoCtrl.clear();
    });
  }

  void _apply() {
    final current = ref.read(workOrderFilterProvider);
    ref.read(workOrderFilterProvider.notifier).state = current.copyWith(
      date: _date,
      clearDate: _date == null,
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
                Text(order.typeEmoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text(order.externalCode,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary)),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(4)),
                  child: Text(order.woType,
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary)),
                ),
                const Spacer(),
                WoStatusBadge(status: order.status, small: true),
              ],
            ),
            const SizedBox(height: 8),
            Text(order.woTypeDescription,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyLarge
                    .copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.place_outlined,
                  size: 14, color: AppColors.textHint),
              const SizedBox(width: 4),
              Expanded(
                child: Text(order.address.short,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium),
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.event_outlined,
                  size: 14, color: AppColors.textHint),
              const SizedBox(width: 4),
              Text(
                  '${Fmt.date(order.appointmentDate)} · ${order.appointmentStartTime}',
                  style: AppTextStyles.bodySmall),
              const Spacer(),
              if (order.status == WorkOrderStatus.inPausa)
                const Icon(Icons.pause_circle_outline,
                    size: 15, color: AppColors.accentOrange),
              if (order.localStatus == LocalSyncStatus.pendingUpload)
                const Icon(Icons.cloud_upload_outlined,
                    size: 15, color: AppColors.accentOrange),
            ]),
          ],
        ),
      ),
    );
  }
}
