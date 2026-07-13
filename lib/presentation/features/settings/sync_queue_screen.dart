// Coda di sincronizzazione : visualizza, ritenta, annulla.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';
import '../../providers/sync_provider.dart';

class SyncQueueScreen extends ConsumerWidget {
  const SyncQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(syncQueueProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sincronizzazione'),
        actions: [
          IconButton(
            tooltip: 'Riprova tutto',
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await ref.read(syncActionsProvider).retryAll();
              if (context.mounted) showSapToast(context, 'Nuovo tentativo avviato');
            },
          ),
        ],
      ),
      body: async.when(
        loading: () => const WfmLoading(),
        error: (e, _) => WfmErrorState(message: e.toString()),
        data: (queue) => queue.isEmpty
            ? const EmptyState(
                title: 'Coda vuota',
                subtitle: 'Tutti i dati sono sincronizzati con SAP.',
                icon: Icons.cloud_done_outlined)
            : ListView.separated(
                padding: kPagePadding,
                itemCount: queue.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _SyncItem(
                  op: queue[i],
                  onCancel: () =>
                      ref.read(syncActionsProvider).cancel(queue[i].id),
                ),
              ),
      ),
    );
  }
}

class _SyncItem extends StatelessWidget {
  final SyncOperation op;
  final VoidCallback onCancel;
  const _SyncItem({required this.op, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final (icon, color, statusLabel) = switch (op.status) {
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
          'Azione richiesta'
        ),
    };

    // Riga di dettaglio: rassicurante se in attesa, il motivo (già "umano") se
    // fallito. Mai il testo grezzo dell'eccezione.
    final detail = switch (op.status) {
      SyncStatus.pending => 'Verrà reinviato automaticamente al ritorno della rete',
      SyncStatus.failed => op.lastError ?? 'Riprova o contatta il supporto',
      _ => null,
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
              Text(statusLabel,
                  style: AppTextStyles.labelSmall.copyWith(
                      color: color, fontWeight: FontWeight.w600)),
              if (detail != null)
                Text(detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary)),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Rimuovi dalla coda',
          icon: const Icon(Icons.close, color: AppColors.textHint),
          onPressed: onCancel,
        ),
      ]),
    );
  }
}
