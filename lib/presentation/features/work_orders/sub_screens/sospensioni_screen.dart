// Sospensioni dettagliate : lista + aggiungi sospensione.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../domain/entities/entities.dart';

/// Provider locale (in-memory) per la lista sospensioni di un OdL/Avviso.
/// In produzione: sostituito da un repository sincronizzato col Cruscotto.
final sospensioniProvider =
    StateNotifierProvider.family<_SospensioniNotifier, List<Suspension>, String>(
        (ref, code) => _SospensioniNotifier(code));

class _SospensioniNotifier extends StateNotifier<List<Suspension>> {
  final String parentCode;
  _SospensioniNotifier(this.parentCode) : super(const []);

  void add(Suspension s) => state = [...state, s];
  void close(String id, DateTime endDateTime) {
    state = [
      for (final s in state)
        if (s.id == id) s.copyWith(endDateTime: endDateTime) else s
    ];
  }

  void remove(String id) => state = state.where((s) => s.id != id).toList();
}

class SospensioniScreen extends ConsumerWidget {
  final String code;
  const SospensioniScreen({super.key, required this.code});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(sospensioniProvider(code));
    return Scaffold(
      appBar: AppBar(title: Text('Sospensioni · $code')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Aggiungi'),
      ),
      body: list.isEmpty
          ? const EmptyState(
              title: 'Nessuna sospensione',
              subtitle:
                  'Aggiungi una sospensione per registrare un\'interruzione di lavoro.',
              icon: Icons.pause_circle_outline,
            )
          : ListView.separated(
              padding: kPagePadding,
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _SuspensionTile(
                s: list[i],
                onClose: () => ref
                    .read(sospensioniProvider(code).notifier)
                    .close(list[i].id, DateTime.now()),
                onDelete: () async {
                  final ok = await showWfmConfirmDialog(
                    context: context,
                    title: 'Elimina sospensione',
                    message:
                        'Eliminare la sospensione "${list[i].type.label}"?',
                    confirmLabel: 'Elimina',
                    cancelLabel: 'Annulla',
                    tone: WfmDialogTone.danger,
                    icon: Icons.delete_outline,
                  );
                  if (ok == true) {
                    ref
                        .read(sospensioniProvider(code).notifier)
                        .remove(list[i].id);
                  }
                },
              ),
            ),
    );
  }

  Future<void> _openEditor(BuildContext context, WidgetRef ref) async {
    final result = await showModalBottomSheet<Suspension>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddSuspensionSheet(parentCode: code),
    );
    if (result != null) {
      ref.read(sospensioniProvider(code).notifier).add(result);
    }
  }
}

class _SuspensionTile extends StatelessWidget {
  final Suspension s;
  final VoidCallback onClose;
  final VoidCallback onDelete;

  const _SuspensionTile(
      {required this.s, required this.onClose, required this.onDelete});

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h == 0) return '$m min';
    return '${h}h ${m}min';
  }

  @override
  Widget build(BuildContext context) {
    final color =
        s.isActive ? AppColors.accentOrange : AppColors.accentGreen;
    return WfmCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(
                s.isActive
                    ? Icons.pause_circle_outline
                    : Icons.check_circle_outline,
                color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(s.type.label, style: AppTextStyles.headingSmall),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(s.isActive ? 'Attiva' : 'Chiusa',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: color)),
            ),
          ]),
          const SizedBox(height: 8),
          if (s.cause.isNotEmpty) ...[
            Text('Causa: ${s.cause}', style: AppTextStyles.bodyMedium),
            const SizedBox(height: 4),
          ],
          Row(children: [
            const Icon(Icons.play_arrow,
                size: 14, color: AppColors.textHint),
            const SizedBox(width: 4),
            Text(Fmt.dateTime(s.startDateTime),
                style: AppTextStyles.bodySmall),
            const SizedBox(width: 12),
            if (s.endDateTime != null) ...[
              const Icon(Icons.stop, size: 14, color: AppColors.textHint),
              const SizedBox(width: 4),
              Text(Fmt.dateTime(s.endDateTime!),
                  style: AppTextStyles.bodySmall),
            ],
            const Spacer(),
            Text(_formatDuration(s.duration),
                style: AppTextStyles.bodySmall
                    .copyWith(fontWeight: FontWeight.w600)),
          ]),
          if (s.note.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(s.note, style: AppTextStyles.bodyMedium, maxLines: 3),
          ],
          const SizedBox(height: 6),
          Row(children: [
            if (s.isActive)
              TextButton.icon(
                onPressed: onClose,
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('Chiudi'),
              ),
            const Spacer(),
            TextButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline,
                  color: AppColors.accentRed),
              label: const Text('Elimina',
                  style: TextStyle(color: AppColors.accentRed)),
            ),
          ]),
        ],
      ),
    );
  }
}

class _AddSuspensionSheet extends StatefulWidget {
  final String parentCode;
  const _AddSuspensionSheet({required this.parentCode});

  @override
  State<_AddSuspensionSheet> createState() => _AddSuspensionSheetState();
}

class _AddSuspensionSheetState extends State<_AddSuspensionSheet> {
  SuspensionType _type = SuspensionType.lavoro;
  final _causaCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  DateTime _start = DateTime.now();
  DateTime? _end;

  @override
  void dispose() {
    _causaCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final d = await showDatePicker(
        context: context,
        initialDate: _start,
        firstDate: DateTime(2020),
        lastDate: DateTime(2035));
    if (d == null) return;
    if (!mounted) return;
    final t = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(_start));
    setState(() => _start = DateTime(
        d.year, d.month, d.day, t?.hour ?? 0, t?.minute ?? 0));
  }

  Future<void> _pickEnd() async {
    final d = await showDatePicker(
        context: context,
        initialDate: _end ?? DateTime.now(),
        firstDate: _start,
        lastDate: DateTime(2035));
    if (d == null) return;
    if (!mounted) return;
    final t = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_end ?? DateTime.now()));
    setState(() => _end = DateTime(
        d.year, d.month, d.day, t?.hour ?? 0, t?.minute ?? 0));
  }

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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Aggiungi sospensione',
                style: AppTextStyles.headingMedium),
            const SizedBox(height: 12),
            DropdownButtonFormField<SuspensionType>(
              initialValue: _type,
              isExpanded: true,
              decoration:
                  const InputDecoration(labelText: 'Tipo sospensione *'),
              items: SuspensionType.values
                  .map((t) =>
                      DropdownMenuItem(value: t, child: Text(t.label)))
                  .toList(),
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _causaCtrl,
              decoration:
                  const InputDecoration(labelText: 'Causa (testo libero)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _noteCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                  labelText: 'Note', alignLabelWithHint: true),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: _pickStart,
              child: InputDecorator(
                decoration: const InputDecoration(
                    labelText: 'Inizio sospensione *',
                    prefixIcon: Icon(Icons.play_arrow_rounded)),
                child: Text(Fmt.dateTime(_start),
                    style: AppTextStyles.fieldValue),
              ),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: _pickEnd,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Fine sospensione (facoltativa)',
                  prefixIcon: const Icon(Icons.stop_rounded),
                  suffixIcon: _end == null
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => setState(() => _end = null),
                        ),
                ),
                child: Text(_end == null ? 'Ancora attiva' : Fmt.dateTime(_end!),
                    style: AppTextStyles.fieldValue),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(
                  context,
                  Suspension(
                    id: 'SOSP-${DateTime.now().millisecondsSinceEpoch}',
                    parentCode: widget.parentCode,
                    type: _type,
                    cause: _causaCtrl.text.trim(),
                    note: _noteCtrl.text.trim(),
                    startDateTime: _start,
                    endDateTime: _end,
                  ),
                );
              },
              icon: const Icon(Icons.save_outlined),
              label: const Text('Salva sospensione'),
            ),
          ],
        ),
      ),
    );
  }
}
