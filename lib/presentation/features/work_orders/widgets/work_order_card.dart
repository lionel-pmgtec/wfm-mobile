// WIDGET — Card di un Ordine di Lavoro (riutilizzabile).
//
// Estratto dall'elenco OdL per condividere lo stesso stile fra la scheda
// "Ordini", le liste filtrate per stato aperte dalla Home e la lista dei
// Pronto Intervento.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../domain/entities/entities.dart';
import '../../../providers/creation_provider.dart';
import 'odl_actions_menu.dart';

/// Card di un OdL. [onTap] apre il dettaglio; [showActions] mostra il menu
/// azioni (edit/elimina) — disattivabile nelle liste di sola consultazione.
class WorkOrderCard extends ConsumerWidget {
  final WorkOrder order;
  final VoidCallback onTap;
  final bool showActions;

  const WorkOrderCard({
    super.key,
    required this.order,
    required this.onTap,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Da sincronizzare = ancora nell'elenco locale. Il prefisso "TMP-" resta
    // anche dopo l'invio, finché SAP non assegna il numero definitivo.
    final daSincronizzare =
        ref.watch(isPendingCreationProvider(order.externalCode)).valueOrNull ??
            false;
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
                if (showActions)
                  OdlActionsMenu(
                    code: order.externalCode,
                    order: order,
                    iconColor: AppColors.textSecondary,
                    scope: OdlMenuScope.list,
                  ),
              ],
            ),
            Text(order.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyLarge
                    .copyWith(fontWeight: FontWeight.w600)),
            if (daSincronizzare)
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
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
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
