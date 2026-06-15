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
        leading: const BackButton(),
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
    final (icon, color) = switch (op.status) {
      SyncStatus.pending => (Icons.schedule, AppColors.accentOrange),
      SyncStatus.inProgress => (Icons.sync, AppColors.primary),
      SyncStatus.success => (Icons.check_circle, AppColors.accentGreen),
      SyncStatus.failed => (Icons.error_outline, AppColors.accentRed),
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
              Text('Rif. ${op.entityId} · ${Fmt.dateTime(op.createdAt)}',
                  style: AppTextStyles.bodySmall),
              if (op.lastError != null)
                Text(op.lastError!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.accentRed)),
              if (op.retryCount > 0)
                Text('Tentativi: ${op.retryCount}',
                    style: AppTextStyles.labelSmall),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Annulla',
          icon: const Icon(Icons.close, color: AppColors.textHint),
          onPressed: onCancel,
        ),
      ]),
    );
  }
}
