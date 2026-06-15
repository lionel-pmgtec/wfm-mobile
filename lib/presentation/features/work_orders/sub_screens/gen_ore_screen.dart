// Genera Ore in batch : aggiunge ore lavorate su una specifica
// operazione di un OdL. Le ore vengono accodate per essere inviate al Cruscotto
// tramite il flusso P69/TimeConfirmationSet.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../domain/entities/entities.dart';
import '../../../providers/work_orders_provider.dart';

class GenOreScreen extends ConsumerStatefulWidget {
  final String code;
  const GenOreScreen({super.key, required this.code});

  @override
  ConsumerState<GenOreScreen> createState() => _GenOreScreenState();
}

class _GenOreScreenState extends ConsumerState<GenOreScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _operationNumber;
  DateTime _date = DateTime.now();
  int _hours = 1;
  int _minutes = 0;
  final _noteCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(workOrderDetailProvider(widget.code));
    return Scaffold(
      appBar: AppBar(title: const Text('Genera ore')),
      body: async.when(
        loading: () => const WfmLoading(),
        error: (e, _) => WfmErrorState(message: e.toString()),
        data: (order) => _buildForm(context, order),
      ),
    );
  }

  Widget _buildForm(BuildContext context, WorkOrder order) {
    final ops = order.operations;
    if (ops.isEmpty) {
      return const EmptyState(
        title: 'Nessuna operazione',
        subtitle:
            'Aggiungi prima un\'operazione all\'OdL per registrarci delle ore.',
        icon: Icons.work_outline,
      );
    }
    _operationNumber ??= ops.first.number;
    return Form(
      key: _formKey,
      child: ListView(
        padding: kPagePadding,
        children: [
          const SectionHeader(title: 'ORDINE DI LAVORO'),
          FieldRow(label: 'Numero ordine', value: order.externalCode),
          const SizedBox(height: 12),
          FieldRow(label: 'Descrizione', value: order.woTypeDescription, fullWidth: true),
          const SectionHeader(title: 'OPERAZIONE'),
          DropdownButtonFormField<String>(
            initialValue: _operationNumber,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Numero operazione *'),
            items: ops
                .map((o) => DropdownMenuItem(
                      value: o.number,
                      child: Text('${o.number} — ${o.description}',
                          overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _operationNumber = v),
            validator: (v) =>
                v == null || v.isEmpty ? 'Selezionare un\'operazione' : null,
          ),
          const SectionHeader(title: 'TEMPO LAVORATO'),
          InkWell(
            onTap: _pickDate,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Data',
                prefixIcon: Icon(Icons.event_outlined),
                suffixIcon: Icon(Icons.chevron_right),
              ),
              child: Text(Fmt.date(_date), style: AppTextStyles.fieldValue),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _stepperField(
                    label: 'Ore',
                    value: _hours,
                    onMinus: () => setState(
                        () => _hours = (_hours - 1).clamp(0, 24)),
                    onPlus: () =>
                        setState(() => _hours = (_hours + 1).clamp(0, 24))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _stepperField(
                    label: 'Minuti',
                    value: _minutes,
                    step: 15,
                    onMinus: () => setState(
                        () => _minutes = (_minutes - 15).clamp(0, 45)),
                    onPlus: () => setState(
                        () => _minutes = (_minutes + 15).clamp(0, 45))),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _noteCtrl,
            decoration: const InputDecoration(
                labelText: 'Note (facoltative)', alignLabelWithHint: true),
            maxLines: 3,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _saving ? null : _submit,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Invio…' : 'Conferma ore'),
          ),
        ],
      ),
    );
  }

  Widget _stepperField(
      {required String label,
      required int value,
      required VoidCallback onMinus,
      required VoidCallback onPlus,
      int step = 1}) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: Row(
        children: [
          IconButton(
            onPressed: onMinus,
            icon: const Icon(Icons.remove_circle_outline,
                color: AppColors.primary),
          ),
          Expanded(
            child: Center(
              child: Text('$value',
                  style: AppTextStyles.headingMedium
                      .copyWith(fontWeight: FontWeight.w700)),
            ),
          ),
          IconButton(
            onPressed: onPlus,
            icon: const Icon(Icons.add_circle_outline,
                color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
        context: context,
        initialDate: _date,
        firstDate: DateTime(2020),
        lastDate: DateTime(2035));
    if (d != null) setState(() => _date = d);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_hours == 0 && _minutes == 0) {
      showSapToast(context, 'Inserire un tempo > 0', isError: true);
      return;
    }
    setState(() => _saving = true);
    // Accoda l'operazione (mock); in produzione passerebbe via SyncRepository.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    setState(() => _saving = false);
    showSapToast(context,
        'Ore registrate: $_hours h $_minutes min su op. $_operationNumber');
    context.pop();
  }
}
