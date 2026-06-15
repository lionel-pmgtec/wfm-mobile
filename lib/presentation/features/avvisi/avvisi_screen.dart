// Elenco Avvisi di Servizio con filtri categoriali, ricerca e contatori.
//
// Chips di filtro: Tutti / Miei / Urgenti / In attesa / Con preventivo /
// Da firmare / Chiusi (più altri filtri aggiunti dalla AvvisoExtension).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';
import '../../providers/auth_provider.dart';
import '../../providers/avviso_extension_provider.dart';
import '../../providers/avvisi_provider.dart';
import 'widgets/avviso_widgets.dart';

/// Categoria di filtro dashboard.
enum AvvisiViewFilter {
  tutti,
  miei,
  urgenti,
  inAttesa,
  conPreventivo,
  daFirmare,
  chiusi;

  String get label => switch (this) {
        AvvisiViewFilter.tutti => 'Tutti',
        AvvisiViewFilter.miei => 'Miei',
        AvvisiViewFilter.urgenti => 'Urgenti',
        AvvisiViewFilter.inAttesa => 'In attesa',
        AvvisiViewFilter.conPreventivo => 'Con preventivo',
        AvvisiViewFilter.daFirmare => 'Da firmare',
        AvvisiViewFilter.chiusi => 'Chiusi',
      };

  IconData get icon => switch (this) {
        AvvisiViewFilter.tutti => Icons.list_alt_rounded,
        AvvisiViewFilter.miei => Icons.person_outline,
        AvvisiViewFilter.urgenti => Icons.priority_high_rounded,
        AvvisiViewFilter.inAttesa => Icons.hourglass_bottom_rounded,
        AvvisiViewFilter.conPreventivo => Icons.description_outlined,
        AvvisiViewFilter.daFirmare => Icons.draw_outlined,
        AvvisiViewFilter.chiusi => Icons.check_circle_outline,
      };
}

final avvisiViewFilterProvider =
    StateProvider<AvvisiViewFilter>((ref) => AvvisiViewFilter.tutti);

final avvisiCategoryFilterProvider =
    StateProvider<AvvisoCategory?>((ref) => null);

class AvvisiScreen extends ConsumerWidget {
  const AvvisiScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(avvisiProvider);
    final view = ref.watch(avvisiViewFilterProvider);
    final categoria = ref.watch(avvisiCategoryFilterProvider);
    final user = ref.watch(authControllerProvider.notifier).user;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Avvisi di Servizio'),
        actions: [
          IconButton(
            tooltip: 'Filtri avanzati',
            icon: Badge(
              isLabelVisible: categoria != null,
              child: const Icon(Icons.tune_rounded),
            ),
            onPressed: () => _openFilters(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Cerca per numero, descrizione, cliente, città…',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (v) =>
                  ref.read(avvisiQueryProvider.notifier).state = v,
            ),
          ),
          // Chips di stato.
          SizedBox(
            height: 50,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              children: [
                for (final f in AvvisiViewFilter.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      avatar: Icon(f.icon,
                          size: 16,
                          color: view == f
                              ? Colors.white
                              : AppColors.primary),
                      label: Text(f.label),
                      selected: view == f,
                      onSelected: (_) => ref
                          .read(avvisiViewFilterProvider.notifier)
                          .state = f,
                      showCheckmark: false,
                      selectedColor: AppColors.primary,
                      backgroundColor: AppColors.surface,
                      labelStyle: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: view == f
                              ? Colors.white
                              : AppColors.primary),
                    ),
                  ),
              ],
            ),
          ),
          // Filtro categoria attivo (chip removibile).
          if (categoria != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 2, 12, 4),
              child: Wrap(spacing: 8, children: [
                Chip(
                  avatar: Icon(categoria.icon, size: 14),
                  label: Text('Categoria: ${categoria.label}'),
                  onDeleted: () => ref
                      .read(avvisiCategoryFilterProvider.notifier)
                      .state = null,
                ),
              ]),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(avvisiProvider),
              child: async.when(
                loading: () => const WfmLoading(),
                error: (e, _) => WfmErrorState(
                    message: e.toString(),
                    onRetry: () => ref.invalidate(avvisiProvider)),
                data: (raw) {
                  final filtered = _applyFilters(
                      raw, view, categoria, user?.cid, ref);
                  return filtered.isEmpty
                      ? const EmptyState(
                          title: 'Nessun avviso',
                          subtitle:
                              'Nessun avviso corrisponde ai filtri attuali.',
                          icon: Icons.search_off)
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 24),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) => _AvvisoItem(
                            avviso: filtered[i],
                            onTap: () => context.push(AppRoutes
                                .avvisoDetailPath(filtered[i].numeroAvviso)),
                          ),
                        );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openFilters(BuildContext context, WidgetRef ref) async {
    AvvisoCategory? selected =
        ref.read(avvisiCategoryFilterProvider);
    final res = await showModalBottomSheet<AvvisoCategory?>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(builder: (ctx, setSt) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.backgroundPage,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Filtra per categoria',
                  style: AppTextStyles.headingMedium),
              const SizedBox(height: 12),
              for (final c in [null, ...AvvisoCategory.values])
                RadioListTile<AvvisoCategory?>(
                  value: c,
                  groupValue: selected,
                  onChanged: (v) => setSt(() => selected = v),
                  title: Text(c?.label ?? 'Tutte'),
                  secondary: Icon(c?.icon ?? Icons.all_inclusive,
                      color: AppColors.primary),
                ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, null),
                    child: const Text('Annulla'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, selected),
                    child: const Text('Applica'),
                  ),
                ),
              ]),
            ],
          ),
        );
      }),
    );
    if (res != null) {
      ref.read(avvisiCategoryFilterProvider.notifier).state =
          res == AvvisoCategory.prontoIntervento ||
                  res == AvvisoCategory.richiestaPreventivo
              ? res
              : null;
    }
  }

  List<NotificationAvviso> _applyFilters(
    List<NotificationAvviso> raw,
    AvvisiViewFilter view,
    AvvisoCategory? categoria,
    String? myCid,
    WidgetRef ref,
  ) {
    return raw.where((a) {
      if (categoria != null && a.categoria != categoria) return false;
      switch (view) {
        case AvvisiViewFilter.tutti:
          return true;
        case AvvisiViewFilter.miei:
          return myCid != null && a.cidAssegnato == myCid;
        case AvvisiViewFilter.urgenti:
          return a.isUrgente;
        case AvvisiViewFilter.inAttesa:
          return !a.hasOrdineCollegato && !a.isChiuso;
        case AvvisiViewFilter.conPreventivo:
          final ext = ref.read(avvisoExtensionProvider(a.numeroAvviso));
          return ext.preventivo?.hasMateriali == true;
        case AvvisiViewFilter.daFirmare:
          final ext = ref.read(avvisoExtensionProvider(a.numeroAvviso));
          return ext.preventivo?.hasMateriali == true &&
              ext.preventivo?.hasFirma != true;
        case AvvisiViewFilter.chiusi:
          return a.isChiuso ||
              ref.read(avvisoExtensionProvider(a.numeroAvviso))
                      .preventivo
                      ?.stato ==
                  PreventivoStato.chiuso;
      }
    }).toList();
  }
}

class _AvvisoItem extends ConsumerWidget {
  final NotificationAvviso avviso;
  final VoidCallback onTap;
  const _AvvisoItem({required this.avviso, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ext = ref.watch(avvisoExtensionProvider(avviso.numeroAvviso));
    final hasPreventivo = ext.preventivo?.hasMateriali == true;
    final hasFirma = ext.preventivo?.hasFirma == true;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: WfmCard(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: avviso.isUrgente
                      ? AppColors.accentRed.withValues(alpha: 0.14)
                      : avviso.interruzioneFornitura
                          ? AppColors.statusInProgressBg
                          : AppColors.statusNewBg,
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(
                  avviso.sottotipo.icon,
                  color: avviso.isUrgente
                      ? AppColors.accentRed
                      : avviso.interruzioneFornitura
                          ? AppColors.accentOrange
                          : AppColors.statusNew),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(avviso.numeroAvviso,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary)),
                    const SizedBox(width: 8),
                    WfmCategoryChip(
                        sottotipo: avviso.sottotipo, dense: true),
                    if (avviso.isUrgente) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.priority_high_rounded,
                          size: 14, color: AppColors.accentRed),
                    ],
                  ]),
                  const SizedBox(height: 4),
                  Text(avviso.descrizione,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyLarge
                          .copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                      '${avviso.address.short} · ${Fmt.date(avviso.dataSegnalazione)}',
                      style: AppTextStyles.bodySmall),
                  if (hasPreventivo || hasFirma) ...[
                    const SizedBox(height: 6),
                    Row(children: [
                      if (hasPreventivo)
                        _MiniBadge(
                            icon: Icons.description_outlined,
                            label:
                                '€ ${ext.preventivo!.totaleConIva.toStringAsFixed(2)}',
                            color: AppColors.primary),
                      if (hasFirma) ...[
                        const SizedBox(width: 6),
                        _MiniBadge(
                            icon: Icons.draw_outlined,
                            label: 'Firmato',
                            color: AppColors.accentGreen),
                      ],
                    ]),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MiniBadge(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}
