// Gestione contatori: dati completi e lettura.
//
// Se l'OdL ha un contatore associato (order.meter, da DATI_APPARECCHIATURA
// SAP) ne mostra TUTTI i dati + la scheda Lettura. Per una SOST la scheda
// Lettura contiene anche la sostituzione, in ordine di lavoro: ultima lettura
// SAP -> lettura del contatore rimosso -> nuovo contatore -> posizione. Se non ne ha,
// permette di cercarne uno per matricola/barcode sull'anagrafica del backend
// (GET /anagrafica/equipment).

import 'dart:async';

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
  static const _lookupDebounce = Duration(milliseconds: 600);
  Timer? _lookupTimer;
  String? _lastLookupMatricola;
  late final TabController _tab;
  final _formKey = GlobalKey<FormState>();
  final _readingCtrl = TextEditingController();
  final _notaCtrl = TextEditingController();
  final _newMatricolaCtrl = TextEditingController();
  final _initialReadingCtrl = TextEditingController(text: '0');
  final _sealCtrl = TextEditingController();
  // Sostituzione (SOST): contatore rimosso + posizione nuovo contatore.
  final _depositReadingCtrl = TextEditingController();
  final _newProduttoreCtrl = TextEditingController();
  final _positionCtrl = TextEditingController();
  final _positionAddCtrl = TextEditingController();
  // Ubicazione del contatore ESISTENTE (quello da sostituire/già installato):
  // SAP non sempre la manda; l'operatore deve poterla correggere o inserirla a
  // mano. Condivisa fra la scheda Dati e la scheda Lettura (stesso contatore).
  final _oldUbicazioneCtrl = TextEditingController();
  DateTime _posaDate = DateTime.now();
  /// Dati del nuovo contatore restituiti da SAP (GET /anagrafica/equipment).
  Equipment? _newMeterInfo;
  bool _lookingUp = false;
  bool _readingPhoto = false;

  /// Per gli OdL di sostituzione (SOST) la scheda Lettura include la
  /// sostituzione; su attivazione/disattivazione/lettura il contatore non si
  /// sostituisce e resta la lettura semplice.
  bool get _showSostituzione => widget.order.hasSostituzione;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    // Ricarica un'eventuale lettura già salvata per questo OdL.
    final draft = ref.read(meterReadingDraftProvider(widget.order.externalCode));
    if (draft != null) {
      _readingCtrl.text = '${draft.reading}';
      _notaCtrl.text = draft.nota;
    }
    // Ricarica un'eventuale sostituzione già impostata per questo OdL.
    final sub =
        ref.read(meterSubstitutionDraftProvider(widget.order.externalCode));
    // Per la SOST la lettura del contatore rimosso e una sola: se c'e una
    // lettura salvata col vecchio flusso e nessuna della sostituzione, si riusa.
    if (_showSostituzione && sub?.depositReading == null && draft != null) {
      _depositReadingCtrl.text = '${draft.reading}';
    }
    if (sub != null) {
      if (sub.depositReading != null) {
        _depositReadingCtrl.text = '${sub.depositReading}';
      }
      _newMatricolaCtrl.text = sub.newMatricola;
      if (sub.initialReading != null) {
        _initialReadingCtrl.text = '${sub.initialReading}';
      }
      if (sub.posaDate != null) _posaDate = sub.posaDate!;
      _newProduttoreCtrl.text = sub.newProduttore;
      _sealCtrl.text = sub.sealNumber;
      _positionCtrl.text = sub.position;
      _positionAddCtrl.text = sub.positionAdd;
    }
    // Precompilazione dalla casetta: il nuovo contatore va, di norma, nella
    // STESSA ubicazione del contatore rimosso. È un dato reale del backend
    // (meter.ubicazione), non inventato; il tecnico può correggerlo. Il numero
    // di sigillo NON si precompila: il backend non lo espone e il sigillo del
    // nuovo contatore si applica sul posto.
    if (_positionCtrl.text.trim().isEmpty &&
        widget.meter.ubicazione.isNotEmpty) {
      _positionCtrl.text = widget.meter.ubicazione;
    }
    if (_positionAddCtrl.text.trim().isEmpty &&
        widget.meter.ubicazioneDesc.isNotEmpty) {
      _positionAddCtrl.text = widget.meter.ubicazioneDesc;
    }
    // Ubicazione del contatore esistente: la correzione salvata (se c'è)
    // vince su quella di SAP, altrimenti si parte dal dato SAP.
    _oldUbicazioneCtrl.text = (sub?.oldUbicazione ?? '').isNotEmpty
        ? sub!.oldUbicazione
        : (widget.meter.ubicazione.isNotEmpty
            ? widget.meter.ubicazione
            : widget.meter.location);
    if (_newMatricolaCtrl.text.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _lookupNewMeter();
      });
    }
  }

  @override
  void dispose() {
    _lookupTimer?.cancel();
    _tab.dispose();
    _readingCtrl.dispose();
    _notaCtrl.dispose();
    _newMatricolaCtrl.dispose();
    _initialReadingCtrl.dispose();
    _sealCtrl.dispose();
    _depositReadingCtrl.dispose();
    _newProduttoreCtrl.dispose();
    _positionCtrl.dispose();
    _positionAddCtrl.dispose();
    _oldUbicazioneCtrl.dispose();
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
          tabs: const [
            Tab(text: 'Dati'),
            Tab(text: 'Lettura'),
          ],
        ),
        Expanded(
          child: Form(
            key: _formKey,
            child: TabBarView(
              controller: _tab,
              children: [
                _dataTab(m),
                _showSostituzione ? _sostituzioneTab(m) : _readingTab(m),
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
      // Numero ubicazione: SAP non sempre lo manda. Campo editabile (non sola
      // lettura) così l'operatore può correggerlo o inserirlo per il
      // contatore esistente; precompilato col dato SAP quando c'è.
      TextFormField(
        controller: _oldUbicazioneCtrl,
        decoration: const InputDecoration(
          labelText: 'Ubicazione',
          helperText: 'Codice ubicazione del contatore esistente',
        ),
        onChanged: (_) => setState(() {}),
      ),
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
            label: 'Ultima lettura',
            value: m.lastReading?.toString() ?? '—'),
        FieldRow(
            label: 'Data lettura',
            value: m.lastReadingDate != null
                ? Fmt.date(m.lastReadingDate)
                : '—'),
      ]),
      // Lettura PRECEDENTE dallo storico del contatore (SAP PREC_VALORE/
      // PREC_DATA…): un dato diverso dall'ultima lettura sull'ordine qui sopra.
      if (m.previousReading != null || (m.previousReadingDate != null)) ...[
        const SectionHeader(title: 'LETTURA PRECEDENTE (STORICO)'),
        FormGrid(children: [
          FieldRow(
              label: 'Lettura precedente',
              value: m.previousReading?.toString() ?? '—'),
          FieldRow(
              label: 'Data lettura precedente',
              value: m.previousReadingDate != null
                  ? Fmt.date(m.previousReadingDate)
                  : '—'),
          if ((m.previousReadingTime ?? '').isNotEmpty)
            FieldRow(label: 'Ora', value: m.previousReadingTime!),
          if ((m.previousReadingStatus ?? '').isNotEmpty)
            FieldRow(label: 'Stato', value: m.previousReadingStatus!),
        ]),
      ],
      // Scenario 2: da un OdL NON di sostituzione (es. lettura), il tecnico
      // constata un contatore da sostituire e crea un nuovo OdL SOST collegato
      // a questo contatore e all'OdL d'origine (tracciabilità).
      if (!widget.order.hasSostituzione) ...[
        const SizedBox(height: 24),
        SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            onPressed: () => context.push(AppRoutes.createOrderSostPath(
                widget.order.externalCode, m.matricola)),
            icon: const Icon(Icons.add_box_outlined, size: 18),
            label: const Text('Crea OdL Sostituzione'),
          ),
        ),
      ],
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
        decoration: InputDecoration(
            labelText: 'Nota',
            alignLabelWithHint: true,
            suffixIcon: VoiceSuffixIcons(controller: _notaCtrl)),
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

  /// Scheda Lettura di una SOST: tutto il lavoro sul contatore, in ordine.
  ///   1. contatore da sostituire (dati SAP)
  ///   2. ultima lettura registrata su SAP (dato SAP, sola lettura)
  ///   3. lettura del contatore rimosso (la rileva l'operatore)
  ///   4. lettura del nuovo contatore (posa: parte da 0)
  ///   5. posizione del nuovo contatore
  Widget _sostituzioneTab(Meter m) {
    // Ultima lettura SAP: lo storico del contatore (PREC_*) e, in mancanza,
    // quella registrata sull'ordine (LETTURA). Entrambe arrivano dal backend.
    final sapValue = m.previousReading ?? m.lastReading;
    final sapDate =
        m.previousReading != null ? m.previousReadingDate : m.lastReadingDate;
    final removed = num.tryParse(_depositReadingCtrl.text.replaceAll(',', '.'));
    final diff = (removed != null && sapValue != null) ? removed - sapValue : null;
    final now = DateTime.now();
    final ora = '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';

    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: [
      // 1) Contatore da sostituire: dati SAP.
      const SectionHeader(title: '1 · CONTATORE DA SOSTITUIRE'),
      FormGrid(children: [
        FieldRow(label: 'Matricola', value: Fmt.orDash(m.matricola)),
        FieldRow(label: 'Produttore', value: Fmt.orDash(m.brand)),
        // Ubicazione editabile: stesso campo/controller della scheda Dati (SAP
        // non sempre la manda, l'operatore la corregge/inserisce qui).
        TextFormField(
          controller: _oldUbicazioneCtrl,
          decoration: const InputDecoration(labelText: 'Ubicazione'),
        ),
        FieldRow(
            label: 'Aggiunta ubicazione', value: Fmt.orDash(m.ubicazioneDesc)),
        if ((m.sealNumber ?? '').isNotEmpty)
          FieldRow(label: 'Numero sigillo', value: m.sealNumber!),
      ]),

      // 2) Ultima lettura registrata su SAP: sola lettura.
      const SectionHeader(title: '2 · ULTIMA LETTURA REGISTRATA SU SAP'),
      if (sapValue == null)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: Text('Nessuna lettura disponibile su SAP per questo contatore.',
              style: AppTextStyles.bodySmall),
        )
      else ...[
        FormGrid(children: [
          FieldRow(label: 'Lettura', value: sapValue.toString()),
          FieldRow(
              label: 'Data',
              value: sapDate != null ? Fmt.date(sapDate) : '—'),
          if (m.previousReading != null) ...[
            FieldRow(
                label: 'Ora', value: Fmt.orDash(m.previousReadingTime ?? '')),
            FieldRow(
                label: 'Stato',
                value: Fmt.orDash(m.previousReadingStatus ?? '')),
          ],
        ]),
        // Se l'ordine porta anche una propria lettura, distinta dallo storico.
        if (m.previousReading != null && m.lastReading != null) ...[
          const SizedBox(height: 8),
          FormGrid(children: [
            FieldRow(
                label: "Lettura sull'ordine", value: m.lastReading.toString()),
            FieldRow(
                label: "Data lettura sull'ordine",
                value: m.lastReadingDate != null
                    ? Fmt.date(m.lastReadingDate)
                    : '—'),
          ]),
        ],
      ],

      // 3) Lettura del contatore rimosso: la rileva l'operatore. Va in
      //    `meterReadings` dell'esito, con la matricola del contatore rimosso.
      const SectionHeader(title: '3 · LETTURA DEL CONTATORE RIMOSSO'),
      TextFormField(
        controller: _depositReadingCtrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          labelText: 'Lettura finale',
          helperText: 'Indice del vecchio contatore al momento della rimozione',
        ),
        // Facoltativa (contatore fermo/illeggibile), ma se c'e deve essere
        // numerica e non inferiore all'ultima lettura SAP.
        validator: (v) => (v == null || v.trim().isEmpty)
            ? null
            : Validators.meterReading(v, previous: sapValue),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 8),
      FormGrid(children: [
        FieldRow(label: 'Data', value: Fmt.date(now)),
        FieldRow(label: 'Ora', value: ora),
        FieldRow(
            label: "Differenza rispetto all'ultima lettura SAP",
            value: diff?.toString() ?? '—'),
      ]),
      const SizedBox(height: 8),
      TextFormField(
        controller: _notaCtrl,
        maxLines: 2,
        decoration: InputDecoration(
            labelText: 'Nota sulla lettura',
            alignLabelWithHint: true,
            suffixIcon: VoiceSuffixIcons(controller: _notaCtrl)),
      ),

      // 4) Nuovo contatore: lettura di posa (parte da 0) e dati.
      const SectionHeader(title: '4 · LETTURA DEL NUOVO CONTATORE'),
      TextFormField(
        controller: _newMatricolaCtrl,
        decoration: InputDecoration(
          labelText: 'Numero di serie *',
          suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(
              icon: const Icon(Icons.qr_code_scanner),
              tooltip: 'Scansiona matricola',
              onPressed: () async {
                final code = await context.push<String>(AppRoutes.scanner);
                if (code != null && code.isNotEmpty) {
                  setState(() => _newMatricolaCtrl.text = code);
                  _lookupNewMeter();
                }
              },
            ),
          ]),
        ),
        onFieldSubmitted: (_) => _lookupNewMeter(),
        onChanged: (_) => _scheduleNewMeterLookup(),
      ),
      if (_lookingUp)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: LinearProgressIndicator(),
        ),
      if (_newMeterInfo != null) _newMeterRecap(_newMeterInfo!),
      const SizedBox(height: 12),
      TextFormField(
        controller: _newProduttoreCtrl,
        decoration: const InputDecoration(labelText: 'Produttore'),
      ),
      const SizedBox(height: 12),
      FormGrid(children: [
        TextFormField(
          controller: _initialReadingCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Lettura di posa',
            helperText: 'Un contatore nuovo parte da 0',
          ),
        ),
        // Data di posa: tap -> date picker.
        InkWell(
          onTap: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: _posaDate,
              firstDate: DateTime(2015),
              lastDate: DateTime(2035),
            );
            if (d != null) setState(() => _posaDate = d);
          },
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Data di posa',
              suffixIcon: Icon(Icons.event_outlined, size: 18),
            ),
            child: Text(Fmt.date(_posaDate), style: AppTextStyles.fieldValue),
          ),
        ),
      ]),
      const SizedBox(height: 12),
      // Champ Numero sigillo masqué : cette information n'est plus nécessaire.
      // TextFormField(
      //   controller: _sealCtrl,
      //   decoration: const InputDecoration(labelText: 'Numero sigillo'),
      // ),

      // 5) Posizione del nuovo contatore (nodo `contatore` di POST /esiti).
      //    Precompilata con quella del rimosso (dato SAP), correggibile.
      const SectionHeader(title: '5 · POSIZIONE DEL NUOVO CONTATORE'),
      TextFormField(
        controller: _positionCtrl,
        decoration: const InputDecoration(labelText: 'Ubicazione'),
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _positionAddCtrl,
        decoration: const InputDecoration(labelText: 'Aggiunta ubicazione'),
      ),

      const SizedBox(height: 12),
      // Pulsante principale, sempre in fondo e a piena larghezza.
      SizedBox(
        height: 52,
        child: ElevatedButton.icon(
          onPressed: _saveReplacement,
          icon: const Icon(Icons.swap_horiz_rounded),
          label: const Text('Registra sostituzione'),
        ),
      ),
    ]);
  }

  /// Riepilogo del nuovo contatore restituito da SAP.
  Widget _newMeterRecap(Equipment e) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.statusReceivedBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.verified_outlined,
              size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Text('Dati SAP nuovo contatore',
              style: AppTextStyles.bodyMedium
                  .copyWith(fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 8),
        FormGrid(children: [
          FieldRow(label: 'Produttore', value: Fmt.orDash(e.produttore)),
          FieldRow(label: 'Modello', value: Fmt.orDash(e.modello)),
          FieldRow(label: 'Stato', value: Fmt.orDash(e.stato)),
          FieldRow(label: 'Località', value: Fmt.orDash(e.localita)),
        ]),
      ]),
    );
  }

  /// Interroga SAP col numero di serie del nuovo contatore . 
  /// Oggi può tornare null (anagrafica vuota): in
  /// quel caso l'operatore compila a mano, nessun dato inventato.
  void _scheduleNewMeterLookup() {
    _lookupTimer?.cancel();
    final matricola = _newMatricolaCtrl.text.trim();
    if (matricola.isEmpty) {
      _lastLookupMatricola = null;
      setState(() {
        _newMeterInfo = null;
        _lookingUp = false;
      });
      return;
    }
    if (_lastLookupMatricola != matricola) {
      setState(() => _newMeterInfo = null);
    }
    _lookupTimer = Timer(_lookupDebounce, () {
      if (mounted) _lookupNewMeter();
    });
  }

  Future<void> _lookupNewMeter() async {
    final matricola = _newMatricolaCtrl.text.trim();
    if (matricola.isEmpty || matricola == _lastLookupMatricola) return;
    _lookupTimer?.cancel();
    _lastLookupMatricola = matricola;
    setState(() => _lookingUp = true);
    final res = await ref
        .read(anagraficaRepositoryProvider)
        .getEquipment(matricola: matricola);
    if (!mounted) return;
    if (_newMatricolaCtrl.text.trim() != matricola) {
      setState(() => _lookingUp = false);
      return;
    }
    setState(() => _lookingUp = false);
    res.when(
      success: (eq) {
        setState(() {
          _newMeterInfo = eq;
          // Prefill del produttore dai dati SAP (se l'operatore non l'ha già
          // scritto). Modificabile: resta la sua ultima parola.
          if (eq != null &&
              eq.produttore.isNotEmpty &&
              _newProduttoreCtrl.text.trim().isEmpty) {
            _newProduttoreCtrl.text = eq.produttore;
          }
        });
        showSapToast(
            context,
            eq == null
                ? 'Nessun dato SAP per $matricola — compila a mano'
                : 'Dati nuovo contatore trovati su SAP');
      },
      failure: (f) => showSapToast(context, f.message, isError: true),
    );
    if (res.isFailure) _lastLookupMatricola = null;
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
    if (!_formKey.currentState!.validate()) return;
    if (_newMatricolaCtrl.text.trim().isEmpty) {
      showSapToast(context, 'Inserire la matricola del nuovo contatore',
          isError: true);
      return;
    }
    // Salvataggio REALE in locale: la sostituzione viaggia con l'esito alla
    // chiusura (le due letture in `letture`, la posizione in `contatore`).
    ref
        .read(meterSubstitutionDraftProvider(widget.order.externalCode).notifier)
        .save(MeterSubstitutionDraft(
          depositReading:
              num.tryParse(_depositReadingCtrl.text.replaceAll(',', '.')),
          newMatricola: _newMatricolaCtrl.text.trim(),
          initialReading:
              num.tryParse(_initialReadingCtrl.text.replaceAll(',', '.')),
          posaDate: _posaDate,
          newProduttore: _newProduttoreCtrl.text.trim(),
          sealNumber: _sealCtrl.text.trim(),
          position: _positionCtrl.text.trim(),
          positionAdd: _positionAddCtrl.text.trim(),
          oldUbicazione: _oldUbicazioneCtrl.text.trim(),
          dateTime: DateTime.now(),
        ));
    // La lettura del rimosso e anche la lettura dell'OdL: l'esito la propone
    // gia compilata (una sola lettura, nessun doppione).
    final removed =
        num.tryParse(_depositReadingCtrl.text.replaceAll(',', '.'));
    if (removed != null) {
      ref
          .read(meterReadingDraftProvider(widget.order.externalCode).notifier)
          .save(MeterReadingDraft(
            reading: removed,
            nota: _notaCtrl.text.trim(),
            dateTime: DateTime.now(),
          ));
    }
    showSapToast(context,
        'Sostituzione salvata — verrà inviata alla chiusura');
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

  Future<void> _scanMatricola() async {
    final code = await context.push<String>(AppRoutes.scanner);
    if (code != null && code.isNotEmpty) {
      setState(() => _matricolaCtrl.text = code);
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
          decoration: InputDecoration(
            labelText: 'Matricola',
            prefixIcon: const Icon(Icons.numbers_outlined),
            // La matricola è il numero di serie stampato sul contatore: si
            // legge col QR/barcode (o col NFC, dalla stessa schermata).
            suffixIcon: IconButton(
              icon: const Icon(Icons.qr_code_scanner),
              tooltip: 'Scansiona matricola',
              onPressed: _scanMatricola,
            ),
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
