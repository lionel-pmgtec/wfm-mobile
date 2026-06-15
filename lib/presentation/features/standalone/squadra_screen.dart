// Configurazione Squadra : Targhe, Magazzino, Membri squadra.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';

// Provider in-memory per la configurazione di squadra.
final vehiclesProvider =
    StateNotifierProvider<_VehiclesNotifier, List<Vehicle>>(
        (ref) => _VehiclesNotifier());

class _VehiclesNotifier extends StateNotifier<List<Vehicle>> {
  _VehiclesNotifier()
      : super(const [
          Vehicle(
              id: 'V001',
              targa: 'AB123CD',
              tipo: 'Furgone',
              descrizione: 'Fiat Ducato',
              assegnatoA: 'VAIOTTIM'),
          Vehicle(
              id: 'V002',
              targa: 'EF456GH',
              tipo: 'Utility',
              descrizione: 'Panda 4x4',
              assegnatoA: 'ROSSIPAO'),
        ]);

  void add(Vehicle v) => state = [...state, v];
  void remove(String id) => state = state.where((v) => v.id != id).toList();
}

final warehouseSlotsProvider =
    StateNotifierProvider<_WarehouseNotifier, List<WarehouseSlot>>(
        (ref) => _WarehouseNotifier());

class _WarehouseNotifier extends StateNotifier<List<WarehouseSlot>> {
  _WarehouseNotifier()
      : super(const [
          WarehouseSlot(
              materialCode: 'MAT-001',
              description: 'Tubo PVC Ø32',
              quantity: 15,
              unitOfMeasure: 'M'),
          WarehouseSlot(
              materialCode: 'MAT-002',
              description: 'Raccordo a T 32mm',
              quantity: 24,
              unitOfMeasure: 'PZ'),
          WarehouseSlot(
              materialCode: 'MAT-003',
              description: 'Contatore 015',
              quantity: 4,
              unitOfMeasure: 'PZ'),
        ]);

  void add(WarehouseSlot s) => state = [...state, s];
}

final teamMembersProvider =
    StateNotifierProvider<_TeamNotifier, List<TeamMember>>(
        (ref) => _TeamNotifier());

class _TeamNotifier extends StateNotifier<List<TeamMember>> {
  _TeamNotifier()
      : super(const [
          TeamMember(
              cid: 'VAIOTTIM',
              nome: 'Mario',
              cognome: 'Vaiotti',
              ruolo: 'Caposquadra'),
          TeamMember(
              cid: 'ROSSIPAO',
              nome: 'Paolo',
              cognome: 'Rossi',
              ruolo: 'Tecnico senior'),
        ]);

  void add(TeamMember m) => state = [...state, m];
  void remove(String cid) =>
      state = state.where((m) => m.cid != cid).toList();
}

class SquadraScreen extends ConsumerStatefulWidget {
  const SquadraScreen({super.key});

  @override
  ConsumerState<SquadraScreen> createState() => _SquadraScreenState();
}

class _SquadraScreenState extends ConsumerState<SquadraScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Squadra / Magazzino'),
        bottom: TabBar(
          controller: _tab,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.directions_car), text: 'Targhe'),
            Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Magazzino'),
            Tab(icon: Icon(Icons.groups_outlined), text: 'Membri'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _TargheTab(),
          _MagazzinoTab(),
          _MembriTab(),
        ],
      ),
    );
  }
}

// ─── Tab Targhe ──────────────────────────────────────────────────────────────

class _TargheTab extends ConsumerWidget {
  const _TargheTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(vehiclesProvider);
    return Stack(children: [
      ListView.separated(
        padding: kPagePadding,
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => WfmCard(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            const Icon(Icons.directions_car, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(list[i].targa,
                      style: AppTextStyles.headingSmall
                          .copyWith(letterSpacing: 1)),
                  Text(
                      '${list[i].tipo} · ${list[i].descrizione} · ${list[i].assegnatoA}',
                      style: AppTextStyles.bodySmall),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: AppColors.accentRed),
              onPressed: () => ref
                  .read(vehiclesProvider.notifier)
                  .remove(list[i].id),
            ),
          ]),
        ),
      ),
      Positioned(
        right: 16,
        bottom: 16,
        child: FloatingActionButton.extended(
          onPressed: () async {
            final res = await showModalBottomSheet<Vehicle>(
              context: context,
              isScrollControlled: true,
              builder: (_) => const _AddVehicleSheet(),
            );
            if (res != null) {
              ref.read(vehiclesProvider.notifier).add(res);
            }
          },
          icon: const Icon(Icons.add),
          label: const Text('Aggiungi'),
        ),
      ),
    ]);
  }
}

class _AddVehicleSheet extends StatefulWidget {
  const _AddVehicleSheet();
  @override
  State<_AddVehicleSheet> createState() => _AddVehicleSheetState();
}

class _AddVehicleSheetState extends State<_AddVehicleSheet> {
  final _targaCtrl = TextEditingController();
  final _tipoCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _cidCtrl = TextEditingController();

  @override
  void dispose() {
    _targaCtrl.dispose();
    _tipoCtrl.dispose();
    _descCtrl.dispose();
    _cidCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
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
          const Text('Aggiungi veicolo',
              style: AppTextStyles.headingMedium),
          const SizedBox(height: 12),
          TextField(
            controller: _targaCtrl,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Targa *'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _tipoCtrl,
            decoration: const InputDecoration(
                labelText: 'Tipo', hintText: 'Furgone / Utility…'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _descCtrl,
            decoration:
                const InputDecoration(labelText: 'Descrizione'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _cidCtrl,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Assegnato a (CID)'),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              if (_targaCtrl.text.isEmpty) {
                showSapToast(context, 'Inserire la targa', isError: true);
                return;
              }
              Navigator.pop(
                  context,
                  Vehicle(
                    id: 'V${DateTime.now().millisecondsSinceEpoch}',
                    targa: _targaCtrl.text.trim().toUpperCase(),
                    tipo: _tipoCtrl.text.trim(),
                    descrizione: _descCtrl.text.trim(),
                    assegnatoA: _cidCtrl.text.trim().toUpperCase(),
                  ));
            },
            icon: const Icon(Icons.save_outlined),
            label: const Text('Salva veicolo'),
          ),
        ],
      ),
    );
  }
}

// ─── Tab Magazzino ───────────────────────────────────────────────────────────

class _MagazzinoTab extends ConsumerWidget {
  const _MagazzinoTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(warehouseSlotsProvider);
    return ListView.separated(
      padding: kPagePadding,
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final s = list[i];
        final low = s.quantity <= 2;
        return WfmCard(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: (low ? AppColors.accentRed : AppColors.primary)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.inventory_2_outlined,
                  color: low ? AppColors.accentRed : AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.description, style: AppTextStyles.headingSmall),
                  Text(s.materialCode, style: AppTextStyles.bodySmall),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${s.quantity} ${s.unitOfMeasure}',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: low
                            ? AppColors.accentRed
                            : AppColors.primary)),
                if (low)
                  const Text('Scorta bassa',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accentRed)),
              ],
            ),
          ]),
        );
      },
    );
  }
}

// ─── Tab Membri ──────────────────────────────────────────────────────────────

class _MembriTab extends ConsumerWidget {
  const _MembriTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(teamMembersProvider);
    return ListView.separated(
      padding: kPagePadding,
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => WfmCard(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primarySurface,
            child: Text(
                '${list[i].nome.isNotEmpty ? list[i].nome[0] : '?'}${list[i].cognome.isNotEmpty ? list[i].cognome[0] : ''}',
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(list[i].fullName, style: AppTextStyles.headingSmall),
                Text('${list[i].cid} · ${list[i].ruolo}',
                    style: AppTextStyles.bodySmall),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
