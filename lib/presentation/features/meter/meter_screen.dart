// Gestione contatori (M6): lettura, installazione, rimozione, sostituzione.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';
import '../../providers/work_orders_provider.dart';

class MeterScreen extends ConsumerWidget {
  final String code;
  const MeterScreen({super.key, required this.code});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(workOrderDetailProvider(code));
    return Scaffold(
      appBar: AppBar(title: const Text('Gestione contatore')),
      body: async.when(
        loading: () => const WfmLoading(),
        error: (e, _) => WfmErrorState(message: e.toString()),
        data: (order) => order.meter == null
            ? const EmptyState(
                title: 'Nessun contatore',
                subtitle: 'Questo OdL non ha un contatore associato.',
                icon: Icons.speed_outlined)
            : _MeterBody(order: order, meter: order.meter!),
      ),
    );
  }
}

class _MeterBody extends StatefulWidget {
  final WorkOrder order;
  final Meter meter;
  const _MeterBody({required this.order, required this.meter});

  @override
  State<_MeterBody> createState() => _MeterBodyState();
}

class _MeterBodyState extends State<_MeterBody>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _formKey = GlobalKey<FormState>();
  final _readingCtrl = TextEditingController();
  final _newMatricolaCtrl = TextEditingController();
  final _initialReadingCtrl = TextEditingController(text: '0');
  final _sealCtrl = TextEditingController();
  bool _readingPhoto = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _readingCtrl.dispose();
    _newMatricolaCtrl.dispose();
    _initialReadingCtrl.dispose();
    _sealCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.meter;
    return Column(
      children: [
        Container(
          color: AppColors.primarySurface,
          padding: kPagePadding,
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Matricola ${m.matricola}',
                  style: AppTextStyles.headingSmall),
              const SizedBox(height: 4),
              Text('${m.displayName} · Calibro ${Fmt.orDash(m.caliber)}',
                  style: AppTextStyles.bodyMedium),
              Text('Ubicazione: ${Fmt.orDash(m.location)}',
                  style: AppTextStyles.bodySmall),
            ],
          ),
        ),
        TabBar(controller: _tab, tabs: const [
          Tab(text: 'Lettura'),
          Tab(text: 'Sostituzione'),
        ]),
        Expanded(
          child: Form(
            key: _formKey,
            child: TabBarView(
              controller: _tab,
              children: [_readingTab(m), _replacementTab(m)],
            ),
          ),
        ),
      ],
    );
  }

  Widget _readingTab(Meter m) {
    return ListView(padding: kPagePadding, children: [
      FieldRow(
          label: 'Lettura precedente',
          value: m.lastReading?.toString() ?? '0'),
      const SizedBox(height: 12),
      TextFormField(
        controller: _readingCtrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'Lettura attuale'),
        validator: (v) =>
            Validators.meterReading(v, previous: m.lastReading),
      ),
      const SizedBox(height: 12),
      FieldRow(label: 'Data estratto conto', value: Fmt.date(DateTime.now())),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        onPressed: () => setState(() => _readingPhoto = true),
        icon: Icon(_readingPhoto ? Icons.check_circle : Icons.photo_camera_outlined,
            color: _readingPhoto ? AppColors.accentGreen : null),
        label: Text(_readingPhoto
            ? 'Foto contatore acquisita'
            : 'Foto contatore (obbligatoria)'),
      ),
      const SizedBox(height: 24),
      ElevatedButton.icon(
        onPressed: () => _saveReading(m),
        icon: const Icon(Icons.save_outlined),
        label: const Text('Registra lettura'),
      ),
    ]);
  }

  Widget _replacementTab(Meter m) {
    return ListView(padding: kPagePadding, children: [
      const SectionHeader(title: 'CONTATORE RIMOSSO'),
      FieldRow(label: 'Matricola', value: m.matricola),
      const SizedBox(height: 12),
      TextFormField(
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'Lettura al deposito'),
      ),
      const SectionHeader(title: 'NUOVO CONTATORE'),
      TextFormField(
        controller: _newMatricolaCtrl,
        decoration: InputDecoration(
          labelText: 'Matricola nuovo contatore',
          suffixIcon: IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () => setState(
                () => _newMatricolaCtrl.text = 'MOCK-${DateTime.now().second}'),
          ),
        ),
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _initialReadingCtrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'Lettura iniziale'),
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _sealCtrl,
        decoration: const InputDecoration(labelText: 'Numero sigillo'),
      ),
      const SizedBox(height: 24),
      ElevatedButton.icon(
        onPressed: _saveReplacement,
        icon: const Icon(Icons.swap_horiz_rounded),
        label: const Text('Registra sostituzione'),
      ),
    ]);
  }

  void _saveReading(Meter m) {
    if (!_formKey.currentState!.validate()) return;
    if (!_readingPhoto) {
      showSapToast(context, 'Foto contatore obbligatoria', isError: true);
      return;
    }
    showSapToast(context, 'Lettura ${_readingCtrl.text} registrata');
  }

  void _saveReplacement() {
    if (_newMatricolaCtrl.text.isEmpty) {
      showSapToast(context, 'Inserire la matricola del nuovo contatore',
          isError: true);
      return;
    }
    showSapToast(context, 'Sostituzione registrata (flusso P69)');
  }
}

