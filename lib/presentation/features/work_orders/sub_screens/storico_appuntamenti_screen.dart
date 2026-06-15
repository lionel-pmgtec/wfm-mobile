// Storico Appuntamenti (sotto-schermata "Storico Appuntamenti"):
// timeline read-only di tutti gli appuntamenti passati e futuri dell'OdL.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../domain/entities/entities.dart';
import '../../../providers/appointments_provider.dart';

class StoricoAppuntamentiScreen extends ConsumerWidget {
  final String code;
  const StoricoAppuntamentiScreen({super.key, required this.code});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(appointmentsProvider(code));
    // Ordina per data decrescente (storico).
    final sorted = [...list]..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      appBar: AppBar(title: Text('Storico appuntamenti · $code')),
      body: sorted.isEmpty
          ? const EmptyState(
              title: 'Nessun appuntamento storico',
              subtitle: 'Quando fisserai degli appuntamenti li vedrai qui.',
              icon: Icons.history_outlined,
            )
          : ListView.separated(
              padding: kPagePadding,
              itemCount: sorted.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _TimelineItem(
                a: sorted[i],
                isFirst: i == 0,
                isLast: i == sorted.length - 1,
              ),
            ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final Appointment a;
  final bool isFirst;
  final bool isLast;

  const _TimelineItem(
      {required this.a, required this.isFirst, required this.isLast});

  Color get _outcomeColor => switch (a.outcome) {
        AppointmentOutcome.effettuato => AppColors.accentGreen,
        AppointmentOutcome.clienteAssente => AppColors.accentOrange,
        AppointmentOutcome.rifiutato => AppColors.accentRed,
        AppointmentOutcome.rinviato => AppColors.statusSuspended,
        AppointmentOutcome.daEffettuare => AppColors.primary,
      };

  IconData get _outcomeIcon => switch (a.outcome) {
        AppointmentOutcome.effettuato => Icons.check_circle,
        AppointmentOutcome.clienteAssente => Icons.person_off_outlined,
        AppointmentOutcome.rifiutato => Icons.cancel,
        AppointmentOutcome.rinviato => Icons.event_repeat_outlined,
        AppointmentOutcome.daEffettuare => Icons.schedule,
      };

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Colonna timeline (cerchio + linea).
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Container(
                  width: 4,
                  height: 8,
                  color: isFirst ? Colors.transparent : AppColors.border,
                ),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _outcomeColor.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(color: _outcomeColor, width: 2),
                  ),
                  child: Icon(_outcomeIcon, size: 16, color: _outcomeColor),
                ),
                Expanded(
                  child: Container(
                    width: 4,
                    color: isLast ? Colors.transparent : AppColors.border,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: WfmCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(Fmt.date(a.date),
                        style: AppTextStyles.headingSmall),
                    const SizedBox(width: 8),
                    if (a.startTime.isNotEmpty)
                      Text(a.startTime, style: AppTextStyles.bodyMedium),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _outcomeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(a.outcome.label,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _outcomeColor)),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    if (a.personalizzato)
                      _flagChip('Personalizzato', Icons.star_outline),
                    if (a.consensoAnticipato) ...[
                      const SizedBox(width: 6),
                      _flagChip('Consenso anticipato',
                          Icons.bolt_outlined),
                    ],
                    if (!a.inPresenza) ...[
                      const SizedBox(width: 6),
                      _flagChip('A distanza', Icons.phone_in_talk_outlined),
                    ],
                  ]),
                  if (a.note.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(a.note,
                        style: AppTextStyles.bodyMedium, maxLines: 3),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _flagChip(String label, IconData icon) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.primarySurface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary)),
        ]),
      );
}
