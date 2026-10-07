// Centro di sincronizzazione: elenco di tutto ciò che è stato creato sul campo
// e attende di partire, diviso in Ordini e Avvisi.
//
// Ogni elemento viene inviato al Cruscotto, che poi lo propaga a SAP.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';
import '../../providers/creation_provider.dart';
import '../../providers/sync_provider.dart';

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
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _invia({
    required String id,
    WorkOrder? order,
    NotificationAvviso? avviso,
  }) async {
    setState(() => _inCorso = id);
    final ctrl = ref.read(creationControllerProvider);
    final res = order != null
        ? await ctrl.sendWorkOrder(order)
        : await ctrl.sendAvviso(avviso!);
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
    if (res.failed == 0 && res.nonPassati > 0) {
      // Inviati, ma almeno un OdL non è arrivato al collega scelto.
      showSapToast(context, res.primoNonPassato!, isError: true);
    } else if (res.failed == 0) {
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
    final coda = ref.watch(syncQueueProvider);
    final nOrdini = ordini.valueOrNull?.length ?? 0;
    final nAvvisi = avvisi.valueOrNull?.length ?? 0;
    final nCoda = coda.valueOrNull?.length ?? 0;

    return Scaffold(
      backgroundColor: AppColors.backgroundPage,
      appBar: AppBar(
        title: const Text('Da sincronizzare'),
        actions: [
          if (nOrdini + nAvvisi > 0)
            IconButton(
              tooltip: 'Sincronizza tutto',
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
          isScrollable: true,
          tabs: [
            Tab(text: 'Ordini ($nOrdini)'),
            Tab(text: 'Avvisi ($nAvvisi)'),
            Tab(text: 'In coda ($nCoda)'),
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
              onCruscotto: () => _invia(id: o.externalCode, order: o),
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
              onCruscotto: () => _invia(id: a.numeroAvviso, avviso: a),
            ),
          ),
          // Operazioni offline in coda: esiti e cambi di stato (OdL chiusi
          // senza rete) che partiranno automaticamente al ritorno della rete.
          _lista<SyncOperation>(
            async: coda,
            vuoto:
                'Nessuna operazione in coda (esiti, chiusure, cambi di stato).',
            builder: (op) => _CodaRow(op: op),
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

/// Riga di un elemento da sincronizzare con il Cruscotto.
class _SyncRow extends StatelessWidget {
  final String titolo;
  final String codice;
  final String sottotitolo;
  final IconData icona;
  final bool busy;
  final bool bloccato;
  final VoidCallback onCruscotto;

  const _SyncRow({
    required this.titolo,
    required this.codice,
    required this.sottotitolo,
    required this.icona,
    required this.busy,
    required this.bloccato,
    required this.onCruscotto,
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
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: bloccato ? null : onCruscotto,
              icon: const Icon(Icons.sync_rounded, size: 16),
              label: const Text('Sincronizza'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                textStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Row(children: [
            Icon(Icons.info_outline_rounded, size: 12, color: AppColors.textHint),
            SizedBox(width: 5),
            Expanded(
              child: Text(
                'Invio tramite il Cruscotto.',
                style: TextStyle(fontSize: 10.5, color: AppColors.textHint),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

/// Riga di un'operazione offline in coda (esito, chiusura, cambio di stato).
/// Sola lettura: parte da sola al ritorno della rete.
class _CodaRow extends StatelessWidget {
  final SyncOperation op;
  const _CodaRow({required this.op});

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (op.status) {
      SyncStatus.pending => (
          Icons.schedule_rounded,
          AppColors.accentOrange,
          'In attesa di connessione'
        ),
      SyncStatus.inProgress => (
          Icons.sync_rounded,
          AppColors.primary,
          'Invio in corso…'
        ),
      SyncStatus.success => (
          Icons.check_circle_rounded,
          AppColors.accentGreen,
          'Sincronizzato'
        ),
      SyncStatus.failed => (
          Icons.error_outline_rounded,
          AppColors.accentRed,
          op.lastError ?? 'Azione richiesta'
        ),
    };
    return WfmCard(
      child: Row(children: [
        Icon(icon, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(op.typeLabel, style: AppTextStyles.headingSmall),
              const SizedBox(height: 2),
              Text('Rif. ${op.entityId} · ${Fmt.dateTime(op.createdAt)}',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              Text(label,
                  style: AppTextStyles.labelSmall
                      .copyWith(color: color, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ]),
    );
  }
}
