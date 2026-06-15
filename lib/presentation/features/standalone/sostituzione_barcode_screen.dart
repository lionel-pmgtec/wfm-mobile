// Sostituzione Barcode : cambia il barcode di un equipment.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';

class SostituzioneBarcodeScreen extends ConsumerStatefulWidget {
  const SostituzioneBarcodeScreen({super.key});

  @override
  ConsumerState<SostituzioneBarcodeScreen> createState() =>
      _SostituzioneBarcodeScreenState();
}

class _SostituzioneBarcodeScreenState
    extends ConsumerState<SostituzioneBarcodeScreen> {
  final _matricolaCtrl = TextEditingController();
  final _produttoreCtrl = TextEditingController();
  final _comuneCtrl = TextEditingController();
  final _nuovoBarcodeCtrl = TextEditingController();
  DateTime _dataSost = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _matricolaCtrl.dispose();
    _produttoreCtrl.dispose();
    _comuneCtrl.dispose();
    _nuovoBarcodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _scanNew() async {
    final code = await context.push<String>(AppRoutes.scanner);
    if (code != null && code.isNotEmpty) {
      setState(() => _nuovoBarcodeCtrl.text = code);
    }
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
        context: context,
        initialDate: _dataSost,
        firstDate: DateTime(2020),
        lastDate: DateTime(2035));
    if (d != null) setState(() => _dataSost = d);
  }

  Future<void> _submit() async {
    if (_matricolaCtrl.text.isEmpty || _nuovoBarcodeCtrl.text.isEmpty) {
      showSapToast(context,
          'Inserire matricola e nuovo barcode', isError: true);
      return;
    }
    final ok = await showWfmConfirmDialog(
      context: context,
      title: 'Conferma sostituzione',
      message:
          'Il barcode dell\'equipment ${_matricolaCtrl.text} verrà sostituito con ${_nuovoBarcodeCtrl.text}.',
      confirmLabel: 'Sostituisci',
      cancelLabel: 'Annulla',
      tone: WfmDialogTone.warning,
      icon: Icons.qr_code_2_rounded,
    );
    if (ok != true || !mounted) return;
    setState(() => _saving = true);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() => _saving = false);
    showSapToast(context, 'Barcode sostituito per ${_matricolaCtrl.text}');
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sostituzione barcode')),
      body: ListView(
        padding: kPagePadding,
        children: [
          const SectionHeader(title: 'EQUIPMENT'),
          TextField(
            controller: _matricolaCtrl,
            decoration: const InputDecoration(
              labelText: 'Matricola *',
              prefixIcon: Icon(Icons.numbers_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _produttoreCtrl,
            decoration: const InputDecoration(labelText: 'Produttore'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _comuneCtrl,
            decoration: const InputDecoration(labelText: 'Comune'),
          ),
          const SectionHeader(title: 'NUOVO BARCODE'),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _nuovoBarcodeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nuovo barcode *',
                  prefixIcon: Icon(Icons.qr_code_outlined),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              onPressed: _scanNew,
              icon: const Icon(Icons.qr_code_scanner),
              tooltip: 'Scansiona nuovo barcode',
            ),
          ]),
          const SizedBox(height: 12),
          InkWell(
            onTap: _pickDate,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Data sostituzione',
                prefixIcon: Icon(Icons.event_outlined),
              ),
              child: Text(Fmt.date(_dataSost),
                  style: AppTextStyles.fieldValue),
            ),
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
                : const Icon(Icons.swap_horiz_rounded),
            label: Text(_saving ? 'Sostituzione…' : 'Conferma sostituzione'),
          ),
        ],
      ),
    );
  }
}
