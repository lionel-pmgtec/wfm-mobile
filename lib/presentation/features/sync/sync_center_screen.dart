// Centro di sincronizzazione: elenco di tutto ciò che è stato creato sul campo
// e attende di partire, diviso in Ordini e Avvisi.
//
// Per ogni elemento l'operatore sceglie la destinazione:
//  - Cruscotto: percorso normale (il cruscotto poi propaga a SAP);
//  - SAP: invio diretto, per gli avvisi che non devono passare dal cruscotto.
//    Il canale non è ancora configurato lato backend e viene dichiarato tale.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';
import '../../providers/creation_provider.dart';

class SyncCenterScreen extends ConsumerStatefulWidget {
  const SyncCenterScreen({super.key});

  @override
  ConsumerState<SyncCenterScreen> createState() => _SyncCenterScreenState();
}

class _SyncCenterScreenState extends ConsumerState<SyncCenterScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  /// Codice dell'elemento in fase di invio (blocca solo la sua riga).
  String? _inCorso;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _invia({
    required String id,
    required SyncDestination destination,
    WorkOrder? order,
    NotificationAvviso? avviso,
  }) async {
    setState(() => _inCorso = id);
    final ctrl = ref.read(creationControllerProvider);
    final res = order != null
        ? await ctrl.sendWorkOrder(order, destination: destination)
        : await ctrl.sendAvviso(avviso!, destination: destination);
    if (!mounted) return;
    setState(() => _inCorso = null);
    showSapToast(context, res.message, isError: !res.ok);
  }

  /// Invia in blocco tutti gli elementi al cruscotto (destinazione predefinita).
  Future<void> _inviaTutto() async {
    setState(() => _inCorso = '*');
    final res = await ref.read(creationControllerProvider).syncAll();
    if (!mounted) return;
    setState(() => _inCorso = null);
    if (res.failed == 0) {
      showSapToast(context, 'Inviati ${res.ok} elementi al cruscotto');
    } else if (res.ok == 0) {
      showSapToast(
        context,
        'Il cruscotto non accetta ancora la creazione dal campo. '
        'Gli elementi restano salvati sul tablet.',
        isError: true,
      );
    } else {
      showSapToast(context, '${res.ok} inviati · ${res.failed} in attesa',
          isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ordini = ref.watch(createdWorkOrdersProvider);
    final avvisi = ref.watch(createdAvvisiProvider);
    final nOrdini = ordini.valueOrNull?.length ?? 0;
    final nAvvisi = avvisi.valueOrNull?.length ?? 0;

    return Scaffold(
      backgroundColor: AppColors.backgroundPage,
      appBar: AppBar(
        title: const Text('Da sincronizzare'),
        actions: [
          if (nOrdini + nAvvisi > 0)
            IconButton(
              tooltip: 'Invia tutto al cruscotto',
              icon: const Icon(Icons.cloud_upload_outlined),
              onPressed: _inCorso == null ? _inviaTutto : null,
            ),
          IconButton(
            tooltip: 'Coda operazioni offline',
            icon: const Icon(Icons.history_rounded),
            onPressed: () => context.push(AppRoutes.syncQueue),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          dividerColor: Colors.white24,
          tabs: [
            Tab(text: 'Ordini ($nOrdini)'),
            Tab(text: 'Avvisi ($nAvvisi)'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _lista(
            async: ordini,
            vuoto: 'Nessun ordine creato sul tablet in attesa di invio.',
            builder: (o) => _SyncRow(
              titolo: o.displayName,
              codice: o.externalCode,
              sottotitolo: [
                o.woType,
                if (o.address.city.isNotEmpty) o.address.city,
                Fmt.date(o.createdAt ?? DateTime.now()),
              ].where((s) => s.isNotEmpty).join(' · '),
              icona: Icons.assignment_outlined,
              busy: _inCorso == o.externalCode,
              bloccato: _inCorso != null,
              onCruscotto: () => _invia(
                  id: o.externalCode,
                  destination: SyncDestination.cruscotto,
                  order: o),
              onSap: () => _invia(
                  id: o.externalCode,
                  destination: SyncDestination.sap,
                  order: o),
            ),
          ),
          _lista(
            async: avvisi,
            vuoto: 'Nessun avviso creato sul tablet in attesa di invio.',
            builder: (a) => _SyncRow(
              titolo: a.descrizione.isEmpty ? 'Avviso' : a.descrizione,
              codice: a.numeroAvviso,
              sottotitolo: [
                a.tipo,
                if (a.address.city.isNotEmpty) a.address.city,
                if (a.dataApertura != null) Fmt.date(a.dataApertura!),
              ].where((s) => s.isNotEmpty).join(' · '),
              icona: Icons.notifications_none_rounded,
              busy: _inCorso == a.numeroAvviso,
              bloccato: _inCorso != null,
              onCruscotto: () => _invia(
                  id: a.numeroAvviso,
                  destination: SyncDestination.cruscotto,
                  avviso: a),
              onSap: () => _invia(
                  id: a.numeroAvviso,
                  destination: SyncDestination.sap,
                  avviso: a),
            ),
          ),
        ],
      ),
    );
  }

  /// Elenco generico con stato di caricamento, errore e vuoto.
  Widget _lista<T>({
    required AsyncValue<List<T>> async,
    required String vuoto,
    required Widget Function(T item) builder,
  }) {
    return async.when(
      loading: () => const WfmLoading(),
      error: (e, _) => WfmErrorState(message: e.toString()),
      data: (items) => items.isEmpty
          ? EmptyState(
              title: 'Tutto sincronizzato',
              subtitle: vuoto,
              icon: Icons.cloud_done_outlined)
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              itemCount: items.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: builder(items[i]),
              ),
            ),
    );
  }
}

/// Riga di un elemento da inviare, con le due destinazioni possibili.
class _SyncRow extends StatelessWidget {
  final String titolo;
  final String codice;
  final String sottotitolo;
  final IconData icona;
  final bool busy;
  final bool bloccato;
  final VoidCallback onCruscotto;
  final VoidCallback onSap;

  const _SyncRow({
    required this.titolo,
    required this.codice,
    required this.sottotitolo,
    required this.icona,
    required this.busy,
    required this.bloccato,
    required this.onCruscotto,
    required this.onSap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accentOrange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icona, size: 18, color: AppColors.accentOrange),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titolo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(sottotitolo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              if (busy)
                const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
          const SizedBox(height: 6),
          Text(codice,
              style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textHint)),
          const Divider(height: 18, color: AppColors.borderLight),
          Row(
            children: [
              const Text('Invia a:',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: bloccato ? null : onCruscotto,
                  icon: const Icon(Icons.dashboard_customize_outlined, size: 16),
                  label: const Text('Cruscotto'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: bloccato ? null : onSap,
                  icon: const Icon(Icons.dns_outlined, size: 16),
                  label: const Text('SAP'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.border),
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Row(children: [
            Icon(Icons.info_outline_rounded, size: 12, color: AppColors.textHint),
            SizedBox(width: 5),
            Expanded(
              child: Text(
                'L\'invio diretto a SAP non è ancora configurato sul backend.',
                style: TextStyle(fontSize: 10.5, color: AppColors.textHint),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
