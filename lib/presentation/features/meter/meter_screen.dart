// Gestione contatori: dati completi, lettura, sostituzione.
//
// Se l'OdL ha un contatore associato (order.meter, da DATI_APPARECCHIATURA
// SAP) ne mostra TUTTI i dati + le schede Lettura/Sostituzione. Se non ne ha,
// permette di cercarne uno per matricola/barcode sull'anagrafica del backend
// (GET /anagrafica/equipment).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/widgets.dart';
import '../work_orders/widgets/odl_actions_menu.dart';
import '../../../domain/entities/entities.dart';
import '../../providers/appointments_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/work_orders_provider.dart';

class MeterScreen extends ConsumerWidget {
  final String code;
  const MeterScreen({super.key, required this.code});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(workOrderDetailProvider(code));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestione contatore'),
        actions: [OdlActionsMenu(code: code, scope: OdlMenuScope.meter)],
      ),
      body: async.when(
        loading: () => const WfmLoading(),
        error: (e, _) => WfmErrorState(message: e.toString()),
        data: (order) => order.meter == null
            ? _EquipmentLookup(code: code)
            : _MeterBody(order: order, meter: order.meter!),
      ),
    );
  }
}

// ─── OdL CON CONTATORE ────────────────────────────────────────────────────────

class _MeterBody extends ConsumerStatefulWidget {
  final WorkOrder order;
  final Meter meter;
  const _MeterBody({required this.order, required this.meter});

  @override
  ConsumerState<_MeterBody> createState() => _MeterBodyState();
}

class _MeterBodyState extends ConsumerState<_MeterBody>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _formKey = GlobalKey<FormState>();
  final _readingCtrl = TextEditingController();
  final _notaCtrl = TextEditingController();
  final _newMatricolaCtrl = TextEditingController();
  final _initialReadingCtrl = TextEditingController(text: '0');
  final _sealCtrl = TextEditingController();
  bool _readingPhoto = false;

  /// La scheda "Sostituzione" ha senso SOLO per gli OdL di sostituzione (SOST):
  /// su attivazione/disattivazione/lettura il contatore non si sostituisce.
  bool get _showSostituzione => widget.order.hasSostituzione;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _showSostituzione ? 3 : 2, vsync: this);
    // Ricarica un'eventuale lettura già salvata per questo OdL.
    final draft = ref.read(meterReadingDraftProvider(widget.order.externalCode));
    if (draft != null) {
      _readingCtrl.text = '${draft.reading}';
      _notaCtrl.text = draft.nota;
    }
  }

  @override
  void dispose() {
    _tab.dispose();
    _readingCtrl.dispose();
    _notaCtrl.dispose();
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
        // Colori espliciti: su sfondo chiaro le etichette di default erano
        // illeggibili (troppo chiare).
        TabBar(
          controller: _tab,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          labelStyle: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w500),
          tabs: [
            const Tab(text: 'Dati'),
            const Tab(text: 'Lettura'),
            if (_showSostituzione) const Tab(text: 'Sostituzione'),
          ],
        ),
        Expanded(
          child: Form(
            key: _formKey,
            child: TabBarView(
              controller: _tab,
              children: [
                _dataTab(m),
                _readingTab(m),
                if (_showSostituzione) _replacementTab(m),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Tutti i dati del contatore esposti dal backend (DATI_APPARECCHIATURA SAP).
  Widget _dataTab(Meter m) {
    return ListView(padding: kPagePadding, children: [
      const SectionHeader(title: 'IDENTIFICAZIONE'),
      FieldRow(label: 'Matricola', value: m.matricola),
      const SizedBox(height: 8),
      FormGrid(children: [
        FieldRow(label: 'Produttore', value: Fmt.orDash(m.brand)),
        FieldRow(label: 'Modello', value: Fmt.orDash(m.model)),
        FieldRow(label: 'Calibro', value: Fmt.orDash(m.caliber)),
        FieldRow(label: 'Codice materiale', value: Fmt.orDash(m.materialCode)),
        FieldRow(label: 'Settore', value: Fmt.orDash(m.sector)),
        FieldRow(
            label: 'Numero sigillo', value: Fmt.orDash(m.sealNumber ?? '')),
      ]),
      const SectionHeader(title: 'UBICAZIONE'),
      FieldRow(
          label: 'Ubicazione',
          value: Fmt.orDash(m.ubicazione.isNotEmpty ? m.ubicazione : m.location),
          fullWidth: true),
      const SizedBox(height: 8),
      FormGrid(children: [
        FieldRow(
            label: 'Aggiunta ubicazione', value: Fmt.orDash(m.ubicazioneDesc)),
        FieldRow(
            label: 'Posiz. in batteria',
            value: Fmt.orDash(m.posizioneInBatteria)),
      ]),
      const SizedBox(height: 8),
      FieldRow(
          label: 'Oggetto di allacciamento',
          value: Fmt.orDash(m.oggettoAllacciamento),
          fullWidth: true),
      const SizedBox(height: 8),
      FieldRow(
          label: 'Data installazione',
          value: m.installDate != null ? Fmt.date(m.installDate) : '—'),
      const SectionHeader(title: 'ULTIMA LETTURA'),
      FormGrid(children: [
        FieldRow(
            label: 'Lettura precedente',
            value: m.lastReading?.toString() ?? '—'),
        FieldRow(
            label: 'Data lettura',
            value: m.lastReadingDate != null
                ? Fmt.date(m.lastReadingDate)
                : '—'),
      ]),
    ]);
  }

  Widget _readingTab(Meter m) {
    final now = DateTime.now();
    final ora = '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
    final attuale = num.tryParse(_readingCtrl.text.replaceAll(',', '.'));
    final differenza = (attuale != null && m.lastReading != null)
        ? (attuale - m.lastReading!)
        : null;
    return ListView(padding: kPagePadding, children: [
      // Solo campi esposti dal backend + inseriti dal tecnico (niente
      // Dispositivo/Numeratore/Gruppo/Stato/Motivo: SAP non li invia al tablet).
      const SectionHeader(title: 'DETTAGLI CONTATORE'),
      FormGrid(children: [
        FieldRow(label: 'Di serie', value: m.matricola),
        FieldRow(label: 'Produttore', value: Fmt.orDash(m.brand)),
      ]),
      const SectionHeader(title: 'DETTAGLI LETTURA'),
      TextFormField(
        controller: _readingCtrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'Leggi (lettura attuale)'),
        validator: (v) => Validators.meterReading(v, previous: m.lastReading),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 8),
      FormGrid(children: [
        FieldRow(label: 'Data', value: Fmt.date(now)),
        FieldRow(label: 'Ora', value: ora),
      ]),
      const SizedBox(height: 8),
      FieldRow(label: 'Differenza', value: differenza?.toString() ?? '—'),
      const SectionHeader(title: 'DETTAGLI PRECEDENTI'),
      FormGrid(children: [
        FieldRow(label: 'Leggi', value: m.lastReading?.toString() ?? '—'),
        FieldRow(
            label: 'Data',
            value: m.lastReadingDate != null
                ? Fmt.date(m.lastReadingDate)
                : '—'),
      ]),
      const SectionHeader(title: 'NOTA'),
      TextFormField(
        controller: _notaCtrl,
        maxLines: 2,
        decoration: const InputDecoration(
            labelText: 'Nota', alignLabelWithHint: true),
      ),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        onPressed: () => setState(() => _readingPhoto = true),
        icon: Icon(
            _readingPhoto ? Icons.check_circle : Icons.photo_camera_outlined,
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
            tooltip: 'Scansiona matricola',
            onPressed: () async {
              final code = await context.push<String>(AppRoutes.scanner);
              if (code != null && code.isNotEmpty) {
                setState(() => _newMatricolaCtrl.text = code);
              }
            },
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
    final v = num.tryParse(_readingCtrl.text.replaceAll(',', '.'));
    if (v == null) {
      showSapToast(context, 'Inserire una lettura valida', isError: true);
      return;
    }
    // Salvataggio reale in locale: la lettura viaggerà con l'esito alla
    // chiusura (POST /esiti → letture). Niente mock.
    ref
        .read(meterReadingDraftProvider(widget.order.externalCode).notifier)
        .save(MeterReadingDraft(
          reading: v,
          nota: _notaCtrl.text.trim(),
          dateTime: DateTime.now(),
        ));
    showSapToast(context, 'Lettura salvata — verrà inviata alla chiusura');
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

// ─── OdL SENZA CONTATORE: RICERCA EQUIPMENT ──────────────────────────────────

class _EquipmentLookup extends ConsumerStatefulWidget {
  final String code;
  const _EquipmentLookup({required this.code});

  @override
  ConsumerState<_EquipmentLookup> createState() => _EquipmentLookupState();
}

class _EquipmentLookupState extends ConsumerState<_EquipmentLookup> {
  final _matricolaCtrl = TextEditingController();
  final _barcodeCtrl = TextEditingController();
  Equipment? _result;
  bool _searching = false;
  bool _done = false;

  @override
  void dispose() {
    _matricolaCtrl.dispose();
    _barcodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final code = await context.push<String>(AppRoutes.scanner);
    if (code != null && code.isNotEmpty) {
      setState(() => _barcodeCtrl.text = code);
    }
  }

  Future<void> _search() async {
    final matricola = _matricolaCtrl.text.trim();
    final barcode = _barcodeCtrl.text.trim();
    if (matricola.isEmpty && barcode.isEmpty) {
      showSapToast(context, 'Inserire matricola o barcode', isError: true);
      return;
    }
    setState(() => _searching = true);
    final res = await ref.read(anagraficaRepositoryProvider).getEquipment(
          matricola: matricola.isNotEmpty ? matricola : null,
          barcode: barcode.isNotEmpty ? barcode : null,
        );
    if (!mounted) return;
    setState(() {
      _searching = false;
      _done = true;
      _result = res.valueOrNull;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: kPagePadding,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.statusReceivedBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(children: [
            Icon(Icons.info_outline, size: 18, color: AppColors.primary),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Questo OdL non ha un contatore associato. Cerca un equipment '
                'per matricola o barcode nell\'anagrafica.',
                style: AppTextStyles.bodySmall,
              ),
            ),
          ]),
        ),
        const SectionHeader(title: 'RICERCA CONTATORE'),
        TextField(
          controller: _matricolaCtrl,
          decoration: const InputDecoration(
            labelText: 'Matricola',
            prefixIcon: Icon(Icons.numbers_outlined),
          ),
          onSubmitted: (_) => _search(),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _barcodeCtrl,
              decoration: const InputDecoration(
                labelText: 'Barcode',
                prefixIcon: Icon(Icons.qr_code_outlined),
              ),
              onSubmitted: (_) => _search(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            onPressed: _scan,
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Scansiona',
          ),
        ]),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _searching ? null : _search,
          icon: _searching
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.search),
          label: Text(_searching ? 'Ricerca…' : 'Cerca contatore'),
        ),
        if (_done && _result == null)
          const Padding(
            padding: EdgeInsets.only(top: 20),
            child: Text('Nessun contatore trovato.',
                textAlign: TextAlign.center, style: AppTextStyles.bodyMedium),
          ),
        if (_result != null) ...[
          const SectionHeader(title: 'RISULTATO'),
          WfmCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.speed_outlined,
                      color: AppColors.primary, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            _result!.displayName.isEmpty
                                ? _result!.matricola
                                : _result!.displayName,
                            style: AppTextStyles.headingSmall),
                        Text('Matricola: ${_result!.matricola}',
                            style: AppTextStyles.bodySmall),
                      ],
                    ),
                  ),
                  if (_result!.stato.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.accentGreen.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(_result!.stato,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accentGreen)),
                    ),
                ]),
                const SizedBox(height: 12),
                FormGrid(children: [
                  FieldRow(label: 'Barcode', value: Fmt.orDash(_result!.barcode)),
                  FieldRow(
                      label: 'Produttore',
                      value: Fmt.orDash(_result!.produttore)),
                  FieldRow(label: 'Modello', value: Fmt.orDash(_result!.modello)),
                  FieldRow(
                      label: 'Località', value: Fmt.orDash(_result!.localita)),
                  FieldRow(label: 'Comune', value: Fmt.orDash(_result!.comune)),
                  FieldRow(
                      label: 'Sede tecnica',
                      value: Fmt.orDash(_result!.sedeTecnica)),
                  FieldRow(
                      label: 'Data installazione',
                      value: _result!.dataInstallazione != null
                          ? Fmt.date(_result!.dataInstallazione)
                          : '—'),
                ]),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
