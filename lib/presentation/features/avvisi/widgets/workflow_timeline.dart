// Timeline visiva del workflow di un Avviso di Servizio.
//
// Mostra le tappe: Aperto → OdL → Preventivo → Firma → PDF → Pagamento → Chiuso
// Le tappe non applicabili (es. Preventivo per i Pronto Intervento) vengono
// nascoste automaticamente in base alla categoria dell'avviso.

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/entities.dart';

class WorkflowStage {
  final String label;
  final IconData icon;
  final bool done;
  final bool current;
  final VoidCallback? onTap;

  const WorkflowStage({
    required this.label,
    required this.icon,
    required this.done,
    this.current = false,
    this.onTap,
  });
}

class WorkflowTimeline extends StatelessWidget {
  final NotificationAvviso avviso;
  final AvvisoExtension extension;
  final void Function(int stageIndex)? onTapStage;

  const WorkflowTimeline({
    super.key,
    required this.avviso,
    required this.extension,
    this.onTapStage,
  });

  List<WorkflowStage> _buildStages() {
    final prev = extension.preventivo;
    final hasOdl = avviso.hasOrdineCollegato;
    final hasPrev = prev != null;
    final hasFirma = prev?.hasFirma == true;
    final hasPdf = prev?.hasPdf == true;
    final isPagato = prev?.stato == PreventivoStato.pagato ||
        prev?.stato == PreventivoStato.chiuso;
    final isChiuso = avviso.isChiuso || prev?.stato == PreventivoStato.chiuso;

    // Stage 0 — Aperto (sempre done)
    final stages = <WorkflowStage>[
      const WorkflowStage(label: 'Aperto', icon: Icons.flag_outlined, done: true),
      WorkflowStage(
        label: 'OdL',
        icon: Icons.assignment_outlined,
        done: hasOdl,
        current: !hasOdl && !avviso.isChiuso,
      ),
    ];

    // Stages aggiuntive solo se richiesta preventivo.
    if (avviso.richiedePreventivo) {
      stages.addAll([
        WorkflowStage(
          label: 'Preventivo',
          icon: Icons.description_outlined,
          done: hasPrev && prev.hasMateriali,
          current: hasOdl && !(hasPrev && prev.hasMateriali),
        ),
        WorkflowStage(
          label: 'Firma',
          icon: Icons.draw_outlined,
          done: hasFirma,
          current: hasPrev && prev.hasMateriali && !hasFirma,
        ),
        WorkflowStage(
          label: 'PDF',
          icon: Icons.picture_as_pdf_outlined,
          done: hasPdf,
          current: hasFirma && !hasPdf,
        ),
        WorkflowStage(
          label: 'Pagamento',
          icon: Icons.payments_outlined,
          done: isPagato,
          current: hasPdf && !isPagato,
        ),
      ]);
    }

    stages.add(WorkflowStage(
      label: 'Chiuso',
      icon: Icons.check_circle_outline,
      done: isChiuso,
      current: !isChiuso && (avviso.richiedePreventivo ? isPagato : hasOdl),
    ));

    return stages;
  }

  @override
  Widget build(BuildContext context) {
    final stages = _buildStages();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < stages.length; i++) ...[
              _StageNode(
                stage: stages[i],
                onTap: onTapStage != null ? () => onTapStage!(i) : null,
              ),
              if (i < stages.length - 1)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Container(
                    width: 28,
                    height: 2,
                    color: stages[i].done && stages[i + 1].done
                        ? AppColors.accentGreen
                        : stages[i].done
                            ? AppColors.primary
                            : AppColors.border,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StageNode extends StatelessWidget {
  final WorkflowStage stage;
  final VoidCallback? onTap;
  const _StageNode({required this.stage, this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = stage.done
        ? AppColors.accentGreen
        : stage.current
            ? AppColors.primary
            : AppColors.textHint;
    final bg = stage.done
        ? AppColors.statusDoneBg
        : stage.current
            ? AppColors.statusReceivedBg
            : AppColors.surfaceVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        constraints: const BoxConstraints(minWidth: 64),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: bg,
                shape: BoxShape.circle,
                border: Border.all(color: color, width: stage.current ? 2 : 1),
              ),
              child: Icon(
                stage.done ? Icons.check_rounded : stage.icon,
                size: 20,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              stage.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: stage.current ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
