// Template Work Order : modelli riutilizzabili.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';

final templatesProvider =
    StateNotifierProvider<_TemplatesNotifier, List<WorkOrderTemplate>>(
        (ref) => _TemplatesNotifier());

class _TemplatesNotifier extends StateNotifier<List<WorkOrderTemplate>> {
  _TemplatesNotifier()
      : super(const [
          WorkOrderTemplate(
            id: 'TPL-001',
            name: 'Apertura disco standard',
            woType: 'ATTI',
            description: 'Apertura contatore con sigillo nuovo',
            defaultActivity: 'ADS',
          ),
          WorkOrderTemplate(
            id: 'TPL-002',
            name: 'Sostituzione contatore Ø15',
            woType: 'SOST',
            description: 'Sostituzione contatore standard calibro 15',
            defaultActivity: 'SOS',
          ),
          WorkOrderTemplate(
            id: 'TPL-003',
            name: 'Riparazione perdita condotta',
            woType: 'ZA02',
            description: 'Riparazione perdita visibile su condotta principale',
            defaultActivity: 'RIP',
          ),
          WorkOrderTemplate(
            id: 'TPL-004',
            name: 'Chiusura sigillo (disattivazione)',
            woType: 'DISA',
            description: 'Disattivazione fornitura + sigillo + lettura finale',
            defaultActivity: 'CHS',
          ),
        ]);

  void add(WorkOrderTemplate t) => state = [...state, t];
  void remove(String id) => state = state.where((t) => t.id != id).toList();
}

class TemplatesScreen extends ConsumerWidget {
  const TemplatesScreen({super.key});

  Color _colorForType(String type) {
    if (type.startsWith('ATTI')) return AppColors.statusReceived;
    if (type.startsWith('SOST')) return AppColors.statusSuspended;
    if (type.startsWith('ZA')) return AppColors.accentOrange;
    if (type.startsWith('DISA')) return AppColors.accentRed;
    if (type.startsWith('PA')) return AppColors.accentGreen;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(templatesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Template Work Order')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final res = await showModalBottomSheet<WorkOrderTemplate>(
            context: context,
            isScrollControlled: true,
            builder: (_) => const _AddTemplateSheet(),
          );
          if (res != null) ref.read(templatesProvider.notifier).add(res);
        },
        icon: const Icon(Icons.add),
        label: const Text('Nuovo template'),
      ),
      body: list.isEmpty
          ? const EmptyState(
              title: 'Nessun template',
              subtitle: 'Crea modelli di OdL da riutilizzare in cantiere.',
              icon: Icons.copy_all_outlined,
            )
          : ListView.separated(
              padding: kPagePadding,
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final t = list[i];
                final c = _colorForType(t.woType);
                return WfmCard(
                  padding: const EdgeInsets.all(14),
                  onTap: () {
                    showSapToast(context,
                        'Template "${t.name}" selezionato — apri Crea OdL');
                    context.push(AppRoutes.createOrder);
                  },
                  child: Row(children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: c.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.copy_all_outlined, color: c),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(
                              child: Text(t.name,
                                  style: AppTextStyles.headingSmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: c.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(t.woType,
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: c)),
                            ),
                          ]),
                          const SizedBox(height: 4),
                          Text(t.description,
                              style: AppTextStyles.bodyMedium,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                          if (t.defaultActivity.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text('Attività predefinita: ${t.defaultActivity}',
                                style: AppTextStyles.bodySmall),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: AppColors.accentRed),
                      onPressed: () async {
                        final ok = await showWfmConfirmDialog(
                          context: context,
                          title: 'Elimina template',
                          message: 'Eliminare il template "${t.name}"?',
                          confirmLabel: 'Elimina',
                          cancelLabel: 'Annulla',
                          tone: WfmDialogTone.danger,
                          icon: Icons.delete_outline,
                        );
                        if (ok == true) {
                          ref.read(templatesProvider.notifier).remove(t.id);
                        }
                      },
                    ),
                  ]),
                );
              },
            ),
    );
  }
}

class _AddTemplateSheet extends StatefulWidget {
  const _AddTemplateSheet();
  @override
  State<_AddTemplateSheet> createState() => _AddTemplateSheetState();
}

class _AddTemplateSheetState extends State<_AddTemplateSheet> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _activityCtrl = TextEditingController();
  String _woType = 'ATTI';

  static const _types = ['ATTI', 'SOST', 'ZA02', 'DISA', 'PA'];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _activityCtrl.dispose();
    super.dispose();
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Nuovo template',
              style: AppTextStyles.headingMedium),
          const SizedBox(height: 12),
          TextField(
            controller: _nameCtrl,
            decoration:
                const InputDecoration(labelText: 'Nome template *'),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _woType,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Tipo OdL'),
            items: _types
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
            onChanged: (v) => setState(() => _woType = v ?? _woType),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _descCtrl,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Descrizione *'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _activityCtrl,
            decoration: const InputDecoration(
              labelText: 'Attività predefinita',
              hintText: 'es. ADS, CHS, RIP',
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              if (_nameCtrl.text.trim().isEmpty ||
                  _descCtrl.text.trim().isEmpty) {
                showSapToast(context,
                    'Compila nome e descrizione', isError: true);
                return;
              }
              Navigator.pop(
                  context,
                  WorkOrderTemplate(
                    id: 'TPL-${DateTime.now().millisecondsSinceEpoch}',
                    name: _nameCtrl.text.trim(),
                    woType: _woType,
                    description: _descCtrl.text.trim(),
                    defaultActivity: _activityCtrl.text.trim(),
                  ));
            },
            icon: const Icon(Icons.save_outlined),
            label: const Text('Crea template'),
          ),
        ],
      ),
    );
  }
}
