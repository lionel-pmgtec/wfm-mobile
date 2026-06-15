// Gestione appuntamenti / Dati sopralluogo (Riepilogo + Nuovo + Esito).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';
import '../../providers/appointments_provider.dart';

class AppointmentsScreen extends ConsumerWidget {
  final String code;
  const AppointmentsScreen({super.key, required this.code});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointments = ref.watch(appointmentsProvider(code));
    return Scaffold(
      appBar: AppBar(title: Text('Appuntamenti · OdL $code')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context, ref),
        icon: const Icon(Icons.event_available),
        label: const Text('Nuovo'),
      ),
      body: appointments.isEmpty
          ? const EmptyState(
              title: 'Nessun appuntamento',
              subtitle: 'Fissa un nuovo appuntamento per questo OdL.',
              icon: Icons.event_busy_outlined)
          : ListView.separated(
              padding: kPagePadding,
              itemCount: appointments.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _AppointmentCard(
                a: appointments[i],
                onEsito: () => _setOutcome(context, ref, appointments[i]),
              ),
            ),
    );
  }

  Future<void> _setOutcome(
      BuildContext context, WidgetRef ref, Appointment a) async {
    final outcome = await showModalBottomSheet<AppointmentOutcome>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: AppointmentOutcome.values
              .map((o) => ListTile(
                    title: Text(o.label),
                    onTap: () => Navigator.pop(context, o),
                  ))
              .toList(),
        ),
      ),
    );
    if (outcome != null) {
      ref.read(appointmentsProvider(code).notifier).setOutcome(a.id, outcome);
    }
  }

  Future<void> _openEditor(BuildContext context, WidgetRef ref) async {
    final result = await showModalBottomSheet<Appointment>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AppointmentEditor(code: code),
    );
    if (result != null) {
      ref.read(appointmentsProvider(code).notifier).add(result);
    }
  }
}

class _AppointmentCard extends StatelessWidget {
  final Appointment a;
  final VoidCallback onEsito;
  const _AppointmentCard({required this.a, required this.onEsito});

  @override
  Widget build(BuildContext context) {
    final done = a.outcome == AppointmentOutcome.effettuato;
    return WfmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.event, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(Fmt.date(a.date),
                style: AppTextStyles.headingSmall),
            const SizedBox(width: 8),
            Text('${a.startTime}${a.endTime.isNotEmpty ? ' – ${a.endTime}' : ''}',
                style: AppTextStyles.bodyMedium),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: done
                      ? AppColors.statusDoneBg
                      : AppColors.statusReceivedBg,
                  borderRadius: BorderRadius.circular(20)),
              child: Text(a.outcome.label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: done
                          ? AppColors.statusDone
                          : AppColors.statusReceived)),
            ),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 4, children: [
            if (a.inPresenza) _flag('In presenza', Icons.person_pin_circle_outlined),
            if (a.personalizzato) _flag('Personalizzato', Icons.tune),
            if (a.consensoAnticipato)
              _flag('Consenso anticipato', Icons.verified_user_outlined),
          ]),
          if (a.note.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(a.note, style: AppTextStyles.bodySmall),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onEsito,
              icon: const Icon(Icons.flag_outlined, size: 16),
              label: const Text('Esito appuntamento'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _flag(String label, IconData icon) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(label, style: AppTextStyles.labelSmall),
        ]),
      );
}

class _AppointmentEditor extends StatefulWidget {
  final String code;
  const _AppointmentEditor({required this.code});

  @override
  State<_AppointmentEditor> createState() => _AppointmentEditorState();
}

class _AppointmentEditorState extends State<_AppointmentEditor> {
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _start = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 8, minute: 30);
  bool _personalizzato = false;
  bool _consenso = false;
  bool _inPresenza = true;
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nuovo appuntamento', style: AppTextStyles.headingMedium),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined),
              title: const Text('Data'),
              trailing: Text(Fmt.date(_date)),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime.now().subtract(const Duration(days: 1)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (d != null) setState(() => _date = d);
              },
            ),
            Row(children: [
              Expanded(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Ora'),
                  trailing: Text(_fmtTime(_start)),
                  onTap: () async {
                    final t = await showTimePicker(
                        context: context, initialTime: _start);
                    if (t != null) setState(() => _start = t);
                  },
                ),
              ),
              Expanded(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Ora limite'),
                  trailing: Text(_fmtTime(_end)),
                  onTap: () async {
                    final t = await showTimePicker(
                        context: context, initialTime: _end);
                    if (t != null) setState(() => _end = t);
                  },
                ),
              ),
            ]),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Appuntamento in presenza'),
              value: _inPresenza,
              onChanged: (v) => setState(() => _inPresenza = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Personalizzato'),
              value: _personalizzato,
              onChanged: (v) => setState(() => _personalizzato = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text("Consenso cliente all'esecuzione anticipata"),
              value: _consenso,
              onChanged: (v) => setState(() => _consenso = v),
            ),
            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(labelText: 'Note'),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(
                  context,
                  Appointment(
                    id: 'apt-${DateTime.now().millisecondsSinceEpoch}',
                    workOrderCode: widget.code,
                    date: _date,
                    startTime: _fmtTime(_start),
                    endTime: _fmtTime(_end),
                    personalizzato: _personalizzato,
                    consensoAnticipato: _consenso,
                    inPresenza: _inPresenza,
                    note: _noteCtrl.text,
                  ),
                ),
                child: const Text('Salva appuntamento'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
