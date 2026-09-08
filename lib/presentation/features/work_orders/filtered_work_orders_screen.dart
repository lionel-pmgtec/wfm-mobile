// PAGINA — Elenco OdL filtrato per una singola categoria.
//
// Aperta dalle card cliccabili del "Riepilogo di oggi" (una per stato) e dalla
// banner "Pronto Intervento" della Home. Mostra i soli OdL della categoria
// scelta; i dati provengono dalle API esistenti (nessun dato simulato).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';
import '../../providers/realtime_provider.dart';
import '../../providers/work_orders_provider.dart';
import 'widgets/work_order_card.dart';

class FilteredWorkOrdersScreen extends ConsumerWidget {
  /// Stato da filtrare. `null` quando la lista è quella dei Pronto Intervento.
  final WorkOrderStatus? status;

  /// Vero per la lista dei soli Pronto Intervento.
  final bool prontoIntervento;

  const FilteredWorkOrdersScreen.status(this.status, {super.key})
      : prontoIntervento = false;

  const FilteredWorkOrdersScreen.prontoIntervento({super.key})
      : status = null,
        prontoIntervento = true;

  bool get _isPi => prontoIntervento;

  String get _title =>
      _isPi ? 'Pronto Intervento' : (status?.label ?? 'Ordini di Lavoro');

  Color get _accent => _isPi ? AppColors.accentRed : AppColors.primary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<WorkOrder>> ordersAsync = _isPi
        ? ref.watch(prontoInterventoWorkOrdersProvider)
        : ref.watch(workOrdersByStatusProvider(status!));

    Future<void> refresh() async {
      try {
        await ref.read(refreshFromSapProvider)();
      } catch (_) {
        // La lista mostra comunque la cache; l'errore di rete è già gestito.
      }
      _invalidate(ref);
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _isPi ? AppColors.accentRed : null,
        foregroundColor: _isPi ? Colors.white : null,
        title: Text(_title),
        actions: [
          IconButton(
            tooltip: 'Aggiorna',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: ordersAsync.when(
          loading: () => ListView.builder(
            itemCount: 6,
            itemBuilder: (_, __) => const WorkOrderShimmerItem(),
          ),
          error: (e, _) => ListView(children: [
            const SizedBox(height: 80),
            WfmErrorState(
                message: e.toString(), onRetry: () => _invalidate(ref)),
          ]),
          data: (orders) {
            if (orders.isEmpty) {
              return ListView(children: [
                const SizedBox(height: 80),
                EmptyState(
                  title: _isPi
                      ? 'Nessun Pronto Intervento'
                      : 'Nessun OdL «$_title»',
                  subtitle: _isPi
                      ? 'Non ci sono interventi urgenti al momento.'
                      : 'Non ci sono ordini in questo stato. Aggiorna per sincronizzare con SAP.',
                  icon: _isPi
                      ? Icons.flash_on_rounded
                      : Icons.assignment_outlined,
                ),
              ]);
            }
            return ListView.builder(
              padding: const EdgeInsets.only(top: 6, bottom: 24),
              itemCount: orders.length + 1,
              itemBuilder: (_, i) {
                if (i == 0) return _CountHeader(count: orders.length, accent: _accent, isPi: _isPi);
                final o = orders[i - 1];
                return WorkOrderCard(
                  order: o,
                  onTap: () =>
                      context.push(AppRoutes.workOrderDetailPath(o.externalCode)),
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _invalidate(WidgetRef ref) {
    if (_isPi) {
      ref.invalidate(prontoInterventoWorkOrdersProvider);
    } else {
      ref.invalidate(workOrdersByStatusProvider(status!));
    }
  }
}

/// Intestazione con il conteggio degli ordini mostrati.
class _CountHeader extends StatelessWidget {
  final int count;
  final Color accent;
  final bool isPi;
  const _CountHeader(
      {required this.count, required this.accent, required this.isPi});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Icon(isPi ? Icons.flash_on_rounded : Icons.assignment_outlined,
              size: 18, color: accent),
          const SizedBox(width: 8),
          Text(
            count == 1 ? '1 ordine' : '$count ordini',
            style: AppTextStyles.labelLarge.copyWith(color: accent),
          ),
        ],
      ),
    );
  }
}
