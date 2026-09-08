// Elenco Avvisi di Servizio con filtri categoriali, ricerca e contatori.
//
// Chips di filtro: Tutti / Miei / Urgenti / In attesa / Con preventivo /
// Da firmare / Chiusi (più altri filtri aggiunti dalla AvvisoExtension).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';
import '../../providers/avviso_extension_provider.dart';
import '../../providers/avvisi_provider.dart';
import '../../providers/realtime_provider.dart';
import '../../widgets/sync_widgets.dart';

/// Filtro di stato dell'Avviso. Non è un valore SAP codificato a mano: è la
/// partizione aperto/chiuso derivata dal dato reale ([NotificationAvviso.isChiuso]).
enum AvvisiStatoFilter {
  tutti,
  aperti,
  chiusi;

  String get label => switch (this) {
        AvvisiStatoFilter.tutti => 'Tutti',
        AvvisiStatoFilter.aperti => 'Aperti',
        AvvisiStatoFilter.chiusi => 'Chiusi',
      };

  IconData get icon => switch (this) {
        AvvisiStatoFilter.tutti => Icons.all_inclusive_rounded,
        AvvisiStatoFilter.aperti => Icons.radio_button_unchecked_rounded,
        AvvisiStatoFilter.chiusi => Icons.check_circle_outline,
      };
}

/// Tipo d'Avviso selezionato (codice SAP grezzo `tipo`), oppure null = tutti.
/// I valori possibili NON sono una lista statica: vengono generati a runtime
/// dai tipi realmente presenti nei dati caricati dal Cruscotto.
final avvisiTipoFilterProvider = StateProvider<String?>((ref) => null);

/// Filtro stato (Aperto/Chiuso) — derivato dal dato, non da valori hardcoded.
final avvisiStatoFilterProvider =
    StateProvider<AvvisiStatoFilter>((ref) => AvvisiStatoFilter.tutti);

/// Un tipo d'Avviso disponibile fra i dati, col conteggio. Prodotto a runtime.
class _TipoOption {
  final String code; // codice SAP grezzo (a.tipo)
  final String label; // etichetta leggibile (a.sottotipo.label)
  final int count;
  final bool isPi; // almeno un avviso di questo tipo è Pronto Intervento
  const _TipoOption(this.code, this.label, this.count, this.isPi);
}

/// Costruisce l'elenco dei tipi presenti nei dati caricati. Nessuna lista
/// statica: le opzioni escono dai soli tipi realmente ricevuti dal backend,
/// ordinate coi Pronto Intervento in testa, poi per frequenza.
List<_TipoOption> _buildTipoOptions(List<NotificationAvviso> raw) {
  final byCode = <String, List<NotificationAvviso>>{};
  for (final a in raw) {
    final code = a.tipo.trim();
    if (code.isEmpty) continue;
    byCode.putIfAbsent(code, () => []).add(a);
  }
  final options = byCode.entries.map((e) {
    final items = e.value;
    // Etichetta allineata al Cruscotto: "CODICE · Descrizione".
    final label = items.first.tipoLabel;
    final isPi = items.any((a) => a.isProntoIntervento);
    return _TipoOption(e.key, label, items.length, isPi);
  }).toList()
    ..sort((a, b) {
      if (a.isPi != b.isPi) return a.isPi ? -1 : 1;
      return b.count.compareTo(a.count);
    });
  return options;
}

class AvvisiScreen extends ConsumerStatefulWidget {
  const AvvisiScreen({super.key});

  @override
  ConsumerState<AvvisiScreen> createState() => _AvvisiScreenState();
}

class _AvvisiScreenState extends ConsumerState<AvvisiScreen> {
  // Paginazione incrementale lato app (come per gli ODL): la lista si mostra a
  // blocchi e il contatore riparte quando cambiano ricerca o filtri.
  static const int _pageSize = 15;
  int _visible = _pageSize;

  @override
  Widget build(BuildContext context) {
    // Al cambio di ricerca/filtro la lista riparte dalla prima pagina.
    void resetPage() {
      if (_visible != _pageSize) setState(() => _visible = _pageSize);
    }
    ref.listen(avvisiTipoFilterProvider, (_, __) => resetPage());
    ref.listen(avvisiStatoFilterProvider, (_, __) => resetPage());
    ref.listen(avvisiQueryProvider, (_, __) => resetPage());

    final async = ref.watch(avvisiProvider);
    final tipo = ref.watch(avvisiTipoFilterProvider);
    final stato = ref.watch(avvisiStatoFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Avvisi di Servizio'),
        actions: [
          IconButton(
            tooltip: 'Aggiorna',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () async {
              try {
                await ref.read(refreshFromSapProvider)();
              } catch (_) {
                if (context.mounted) {
                  showSapToast(context, 'Aggiornamento non riuscito',
                      isError: true);
                }
              }
            },
          ),
          IconButton(
            tooltip: 'Filtra per stato',
            icon: Badge(
              isLabelVisible: stato != AvvisiStatoFilter.tutti,
              child: const Icon(Icons.tune_rounded),
            ),
            onPressed: () => _openFilters(context, ref),
          ),
          const SyncIconButton(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.createAvviso),
        icon: const Icon(Icons.add),
        label: const Text('Nuovo Avviso'),
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
          // Chip per Tipo d'Avviso — generate dai tipi realmente presenti nei
          // dati del Cruscotto (nessuna lista statica). "Tutti" + un chip per
          // ogni tipo, coi Pronto Intervento in testa.
          async.maybeWhen(
            data: (raw) {
              final tipi = _buildTipoOptions(raw);
              if (tipi.isEmpty) return const SizedBox(height: 4);
              return SizedBox(
                height: 50,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  scrollDirection: Axis.horizontal,
                  children: [
                    _tipoChip(
                      ref,
                      label: 'Tutti',
                      icon: Icons.list_alt_rounded,
                      selected: tipo == null,
                      isPi: false,
                      onTap: () => ref
                          .read(avvisiTipoFilterProvider.notifier)
                          .state = null,
                    ),
                    for (final t in tipi)
                      _tipoChip(
                        ref,
                        label: '${t.label} (${t.count})',
                        icon: t.isPi
                            ? Icons.flash_on_rounded
                            : Icons.sell_outlined,
                        selected: tipo == t.code,
                        isPi: t.isPi,
                        onTap: () => ref
                            .read(avvisiTipoFilterProvider.notifier)
                            .state = t.code,
                      ),
                  ],
                ),
              );
            },
            orElse: () => const SizedBox(height: 4),
          ),
          // Chip dei filtri attivi (removibili): tipo e stato.
          if (tipo != null || stato != AvvisiStatoFilter.tutti)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 2, 12, 4),
              child: Wrap(spacing: 8, children: [
                if (tipo != null)
                  Chip(
                    avatar: const Icon(Icons.sell_outlined, size: 14),
                    label: Text(avvisoTipoLabel(tipo)),
                    onDeleted: () => ref
                        .read(avvisiTipoFilterProvider.notifier)
                        .state = null,
                  ),
                if (stato != AvvisiStatoFilter.tutti)
                  Chip(
                    avatar: Icon(stato.icon, size: 14),
                    label: Text('Stato: ${stato.label}'),
                    onDeleted: () => ref
                        .read(avvisiStatoFilterProvider.notifier)
                        .state = AvvisiStatoFilter.tutti,
                  ),
              ]),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.read(refreshFromSapProvider)(),
              child: async.when(
                loading: () => const WfmLoading(),
                error: (e, _) => WfmErrorState(
                    message: e.toString(),
                    onRetry: () => ref.invalidate(avvisiProvider)),
                data: (raw) {
                  final filtered = _applyFilters(raw, tipo, stato);
                  if (filtered.isEmpty) {
                    return const EmptyState(
                        title: 'Nessun avviso',
                        subtitle:
                            'Nessun avviso corrisponde ai filtri attuali.',
                        icon: Icons.search_off);
                  }
                  final visible = _visible >= filtered.length
                      ? filtered.length
                      : _visible;
                  final hasMore = filtered.length > visible;
                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: visible + (hasMore ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i >= visible) {
                        return _LoadMoreTile(
                          shown: visible,
                          total: filtered.length,
                          onTap: () =>
                              setState(() => _visible += _pageSize),
                        );
                      }
                      final a = filtered[i];
                      return Dismissible(
                        key: ValueKey('avviso_${a.numeroAvviso}'),
                        direction: DismissDirection.endToStart,
                        background: const WfmSwipeDeleteBackground(),
                        confirmDismiss: (_) => _confirmAndDeleteAvviso(
                            context, ref, a.numeroAvviso),
                        child: _AvvisoItem(
                          avviso: a,
                          onTap: () => context.push(AppRoutes
                              .avvisoDetailPath(a.numeroAvviso)),
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

  /// Chip di un filtro Tipo. I Pronto Intervento sono resi in rosso per
  /// coerenza con l'evidenziazione nella lista.
  Widget _tipoChip(
    WidgetRef ref, {
    required String label,
    required IconData icon,
    required bool selected,
    required bool isPi,
    required VoidCallback onTap,
  }) {
    final accent = isPi ? const Color(0xFFD32F2F) : AppColors.primary;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        avatar: Icon(icon,
            size: 16, color: selected ? Colors.white : accent),
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        selectedColor: accent,
        backgroundColor: AppColors.surface,
        side: BorderSide(
            color: isPi ? accent.withValues(alpha: 0.5) : AppColors.border),
        labelStyle: TextStyle(
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : accent),
      ),
    );
  }

  /// Sheet di filtro per Stato (Aperto/Chiuso), derivato dai dati reali.
  Future<void> _openFilters(BuildContext context, WidgetRef ref) async {
    AvvisiStatoFilter selected = ref.read(avvisiStatoFilterProvider);
    final res = await showModalBottomSheet<AvvisiStatoFilter>(
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
              const Text('Filtra per stato',
                  style: AppTextStyles.headingMedium),
              const SizedBox(height: 12),
              for (final s in AvvisiStatoFilter.values)
                RadioListTile<AvvisiStatoFilter>(
                  value: s,
                  groupValue: selected,
                  onChanged: (v) => setSt(() => selected = v!),
                  title: Text(s.label),
                  secondary: Icon(s.icon, color: AppColors.primary),
                ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
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
      ref.read(avvisiStatoFilterProvider.notifier).state = res;
    }
  }

  /// Applica i filtri Tipo + Stato e porta i Pronto Intervento in cima.
  List<NotificationAvviso> _applyFilters(
    List<NotificationAvviso> raw,
    String? tipo,
    AvvisiStatoFilter stato,
  ) {
    final filtered = raw.where((a) {
      if (tipo != null && a.tipo.trim() != tipo) return false;
      switch (stato) {
        case AvvisiStatoFilter.tutti:
          return true;
        case AvvisiStatoFilter.aperti:
          return !a.isChiuso;
        case AvvisiStatoFilter.chiusi:
          return a.isChiuso;
      }
    }).toList();

    // I Pronto Intervento sempre prima degli altri (ordinamento stabile:
    // preserva l'ordine relativo all'interno di ciascun gruppo).
    final pi = <NotificationAvviso>[];
    final altri = <NotificationAvviso>[];
    for (final a in filtered) {
      (a.isProntoIntervento ? pi : altri).add(a);
    }
    return [...pi, ...altri];
  }
}

/// Conferma + eliminazione di un avviso. Ritorna true se eliminato.
Future<bool> _confirmAndDeleteAvviso(
    BuildContext context, WidgetRef ref, String numero) async {
  final ok = await showWfmConfirmDialog(
    context: context,
    title: 'Eliminare l\'avviso?',
    message: 'L\'avviso $numero sarà eliminato definitivamente.',
    confirmLabel: 'Elimina',
    tone: WfmDialogTone.danger,
  );
  if (ok != true) return false;
  final res = await ref.read(deleteAvvisoProvider)(numero);
  if (!context.mounted) return true;
  return res.when(
    success: (_) {
      showSapToast(context, 'Avviso $numero eliminato');
      return true;
    },
    failure: (f) {
      showSapToast(context, 'Errore: ${f.message}', isError: true);
      return false;
    },
  );
}

/// Pulsante "Carica altri" per la paginazione incrementale della lista avvisi.
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
          Text('Mostrati $shown di $total', style: AppTextStyles.bodySmall),
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

class _AvvisoItem extends ConsumerWidget {
  final NotificationAvviso avviso;
  final VoidCallback onTap;
  const _AvvisoItem({required this.avviso, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ext = ref.watch(avvisoExtensionProvider(avviso.numeroAvviso));
    final hasPreventivo = ext.preventivo?.hasMateriali == true;
    final hasFirma = ext.preventivo?.hasFirma == true;
    final isPi = avviso.isProntoIntervento;
    const piRed = Color(0xFFD32F2F);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Material(
        color: isPi ? const Color(0xFFFFF5F5) : AppColors.surface,
        borderRadius: BorderRadius.circular(kRadiusMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(kRadiusMd),
          child: Container(
            padding: const EdgeInsets.all(kSpacingLg),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(kRadiusMd),
              border: Border.all(
                color: isPi ? piRed.withValues(alpha: 0.55) : AppColors.border,
                width: isPi ? 1.3 : 1,
              ),
            ),
            child: Row(
              children: [
                // Banda rossa verticale: marca subito i Pronto Intervento.
                if (isPi) ...[
                  Container(
                    width: 4,
                    height: 52,
                    decoration: BoxDecoration(
                      color: piRed,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color: isPi
                          ? piRed.withValues(alpha: 0.14)
                          : avviso.interruzioneFornitura
                              ? AppColors.statusInProgressBg
                              : AppColors.statusNewBg,
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(
                      avviso.sottotipo.icon,
                      color: isPi
                          ? piRed
                          : avviso.interruzioneFornitura
                              ? AppColors.accentOrange
                              : AppColors.statusNew),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isPi) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: piRed,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.flash_on_rounded,
                                    size: 11, color: Colors.white),
                                SizedBox(width: 3),
                                Text('PRONTO INTERVENTO',
                                    style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.4,
                                        color: Colors.white)),
                              ]),
                        ),
                        const SizedBox(height: 6),
                      ],
                      Row(children: [
                        Text(avviso.numeroAvviso,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary)),
                        const SizedBox(width: 8),
                        // Badge tipo leggibile "CODICE · Descrizione" (Cruscotto).
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (isPi ? piRed : AppColors.primary)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color: (isPi ? piRed : AppColors.primary)
                                      .withValues(alpha: 0.25)),
                            ),
                            child: Text(
                              avviso.tipoLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: isPi ? piRed : AppColors.primary),
                            ),
                          ),
                        ),
                        if (avviso.isUrgente) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.priority_high_rounded,
                              size: 14, color: piRed),
                        ],
                      ]),
                  const SizedBox(height: 4),
                  Text(avviso.descrizione,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyLarge
                          .copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  // 📍 indirizzo · data. L'indirizzo non è ancora esposto da SAP
                  // (ILOA/ADRC): fino ad allora resta la sola icona come segnaposto.
                  Row(children: [
                    const Icon(Icons.place_outlined,
                        size: 13, color: AppColors.textHint),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        (avviso.address.short.isNotEmpty &&
                                avviso.address.short != '—')
                            ? '${avviso.address.short} · ${Fmt.date(avviso.dataSegnalazione)}'
                            : '· ${Fmt.date(avviso.dataSegnalazione)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySmall),
                    ),
                  ]),
                  // Sede tecnica SAP: distingue avvisi con descrizione identica
                  // (es. i batch di manutenzione programmata sullo stesso oggetto).
                  if ((avviso.sedeTecnica ?? '').isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(children: [
                      const Icon(Icons.engineering_outlined,
                          size: 12, color: AppColors.textHint),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(avviso.sedeTecnica!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodySmall.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary)),
                      ),
                    ]),
                  ],
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
                        const _MiniBadge(
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
