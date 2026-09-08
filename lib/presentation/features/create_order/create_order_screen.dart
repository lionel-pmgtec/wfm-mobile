// Creazione ODL dal campo - form multi-section

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';
import '../../providers/anagrafica_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/creation_provider.dart';
import '../../widgets/sync_widgets.dart';

// ─── Presentazione tipo OdL ──────────────────────────────────────────────────
// I VALORI (code/label) e i CAMPI dinamici arrivano dal cruscotto.
// Qui resta solo l'aspetto grafico (icona/colore), derivato dalla categoria:
// SAP non trasmette elementi grafici Flutter. Codici sconosciuti → aspetto neutro.

({IconData icon, Color color}) _woTypeVisual(WorkOrderTypeOption t) {
  switch ((t.category ?? t.code).toUpperCase()) {
    case 'ATTI':
      return (icon: Icons.lock_open_rounded, color: const Color(0xFF1565C0));
    case 'SOST':
      return (icon: Icons.swap_horiz_rounded, color: const Color(0xFF6A1B9A));
    case 'ZA02':
      return (icon: Icons.build_rounded, color: const Color(0xFFE65100));
    case 'DISA':
      return (icon: Icons.block_rounded, color: const Color(0xFFC62828));
    case 'PA':
      return (icon: Icons.description_outlined, color: const Color(0xFF2E7D32));
    default:
      return (icon: Icons.category_rounded, color: AppColors.primary);
  }
}

// ─── Screen principale ───────────────────────────────────────────────────────

class CreateOrderScreen extends ConsumerStatefulWidget {
  const CreateOrderScreen({super.key});

  @override
  ConsumerState<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends ConsumerState<CreateOrderScreen> {
  final _formKey = GlobalKey<FormState>();

  String? _woType;
  String? _priorita; // etichetta priorità scelta (catalogo backend /priorities)
  final _descCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _streetCtrl = TextEditingController();
  final _numberCtrl = TextEditingController();
  final _additionalCtrl = TextEditingController();
  final _sedeCtrl = TextEditingController();
  final _nomeCtrl = TextEditingController();
  final _cognomeCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _codBpCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  DateTime? _appointmentDate;
  String _startTime = '08:00';
  bool _saving = false;

  // Campi dinamici per tipo OdL: id → controller di testo / valore dropdown.
  final Map<String, TextEditingController> _dynCtrls = {};
  final Map<String, String> _dynSel = {};

  TextEditingController _dynCtrl(String id) =>
      _dynCtrls.putIfAbsent(id, () => TextEditingController());

  @override
  void dispose() {
    for (final c in [
      _descCtrl, _cityCtrl, _streetCtrl, _numberCtrl,
      _additionalCtrl, _sedeCtrl, _nomeCtrl, _cognomeCtrl,
      _telefonoCtrl, _codBpCtrl, _noteCtrl,
    ]) {
      c.dispose();
    }
    for (final c in _dynCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_woType == null) {
      showSapToast(context, 'Seleziona un tipo OdL', isError: true);
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final utente = ref.read(authControllerProvider.notifier).user;
    final cid = utente?.cid ?? '';
    // "Creato da": il nome del tecnico che ha compilato il modulo, non un
    // identificativo tecnico dell'app.
    final creatore = utente == null
        ? 'wfm.mobile'
        : '${utente.fullName} ($cid)';
    // Template operazioni standard (il tecnico le compila/edita poi).
    final now = DateTime.now();
    final defaultOps = <Operation>[
      Operation(
        id: 'OP-${now.millisecondsSinceEpoch}-1',
        number: '0010',
        codice: 'SOPR-001',
        testoBreve: 'Sopralluogo iniziale',
        cid: cid,
        description: 'Valutazione tecnica del punto di intervento.',
        dataInizioPrevista: _appointmentDate ?? now,
        plannedHours: 0.5,
      ),
      Operation(
        id: 'OP-${now.millisecondsSinceEpoch}-2',
        number: '0020',
        codice: 'EXEC-001',
        testoBreve: 'Esecuzione intervento',
        cid: cid,
        description: 'Esecuzione delle lavorazioni previste.',
        dataInizioPrevista: _appointmentDate ?? now,
        plannedHours: 2,
      ),
      Operation(
        id: 'OP-${now.millisecondsSinceEpoch}-3',
        number: '0030',
        codice: 'VRF-001',
        testoBreve: 'Verifica e chiusura',
        cid: cid,
        description: 'Verifica e chiusura intervento.',
        dataInizioPrevista: _appointmentDate ?? now,
        plannedHours: 0.5,
      ),
    ];
    // Campi dinamici (per tipo OdL, dal cruscotto) → Meter + note strutturate.
    final dynFields = _woType == null
        ? const <DynFieldSpec>[]
        : (ref.read(workOrderFieldsProvider(_woType!)).valueOrNull ??
            const <DynFieldSpec>[]);
    String dynVal(String id, {bool option = false}) => option
        ? (_dynSel[id] ?? '')
        : (_dynCtrls[id]?.text.trim() ?? '');
    final dynLines = <String>[];
    for (final f in dynFields) {
      final v = dynVal(f.key, option: f.type == DynFieldType.select);
      if (v.isNotEmpty) dynLines.add('${f.label}: $v');
    }
    Meter? meter;
    if (_woType == 'ATTI' || _woType == 'SOST' || _woType == 'DISA') {
      final matricola = dynVal('matricola');
      if (matricola.isNotEmpty) {
        final sigillo = dynVal('sigillo');
        meter = Meter(
          matricola: matricola,
          caliber: dynVal('calibro'),
          brand: dynVal('marca'),
          sealNumber: sigillo.isEmpty ? null : sigillo,
          lastReading: num.tryParse(dynVal('lettura').replaceAll(',', '.')),
        );
      }
    }
    final baseNotes = _noteCtrl.text.trim();
    final notes = [
      if (dynLines.isNotEmpty) 'Dati specifici:\n${dynLines.join('\n')}',
      if (baseNotes.isNotEmpty) baseNotes,
    ].join('\n\n');

    final code = ref.read(creationControllerProvider).newWorkOrderId();
    final order = WorkOrder(
      externalCode: code,
      woType: _woType!,
      woTypeDescription: _descCtrl.text.trim(),
      tam: _woType!,
      status: WorkOrderStatus.ricevuto,
      priorita: _priorita ?? '',
      creatoDa: creatore,
      appointmentDate: _appointmentDate ?? DateTime.now(),
      appointmentStartTime: _startTime,
      address: Address(
        city: _cityCtrl.text.trim(),
        street: _streetCtrl.text.trim(),
        streetNumber: _numberCtrl.text.trim(),
        additionalInfo: _additionalCtrl.text.trim(),
      ),
      customer: Customer(
        nome: _nomeCtrl.text.trim(),
        cognome: _cognomeCtrl.text.trim(),
        telefono: _telefonoCtrl.text.trim(),
        codBp: _codBpCtrl.text.trim(),
      ),
      referente: '${_nomeCtrl.text.trim()} ${_cognomeCtrl.text.trim()}'.trim(),
      telefonoCliente: _telefonoCtrl.text.trim(),
      operations: defaultOps,
      sedeTecnica: _sedeCtrl.text.trim(),
      meter: meter,
      notes: notes,
      accountingSector: 'POT - Servizio acqua potabile',
      cidAssegnato: cid,
      createdAt: now,
      localStatus: LocalSyncStatus.pendingUpload,
    );
    // Local-first: l'OdL resta sul tablet finché l'operatore non sincronizza.
    await ref.read(creationControllerProvider).addWorkOrder(order);
    if (!mounted) return;
    setState(() => _saving = false);

    // Conferma della creazione con l'invio proposto subito: l'operatore non
    // deve cercare altrove il pulsante di sincronizzazione.
    await showCreatedSyncDialog(
      context,
      ref,
      title: 'Ordine creato',
      message: 'L\'ordine di lavoro è salvato sul tablet. '
          'Vuoi inviarlo subito al cruscotto?',
    );
    if (!mounted) return;
    // Sostituisce il wizard col dettaglio dell'OdL creato mantenendo lo
    // stack sottostante: il tasto Indietro torna correttamente alla Home.
    context.pushReplacement(AppRoutes.workOrderDetailPath(code));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPage,
      appBar: AppBar(
        title: const Text('Nuovo Ordine di Lavoro'),
        actions: [
          // Un solo pulsante di conferma: quello in fondo alla pagina
          // ("Crea Ordine di Lavoro"). Qui in appbar solo lo stato di
          // salvataggio e la sincronizzazione, sempre a portata di mano.
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
            )
          else
            const SyncIconButton(color: Colors.white),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── 1. Tipo OdL ──────────────────────────────────────────────────
            _SectionCard(
              title: 'Tipo OdL',
              icon: Icons.category_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ref.watch(workOrderTypesProvider).when(
                        loading: () => const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        error: (_, __) => _cruscottoInfo(
                            'Impossibile caricare i tipi OdL dal cruscotto.'),
                        data: (types) {
                          if (types.isEmpty) {
                            return _cruscottoInfo(
                                'Nessun tipo OdL ricevuto dal cruscotto.\n'
                                'Il catalogo è servito da SAP tramite il cruscotto.');
                          }
                          return GridView.count(
                            crossAxisCount: 3,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: 1.05,
                            children: types.map((t) {
                              final vis = _woTypeVisual(t);
                              final sel = _woType == t.code;
                              return GestureDetector(
                                onTap: () => setState(() {
                                  _woType = t.code;
                                  if (_descCtrl.text.isEmpty) {
                                    _descCtrl.text = t.label;
                                  }
                                }),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  decoration: BoxDecoration(
                                    color: sel
                                        ? vis.color.withValues(alpha: 0.1)
                                        : AppColors.backgroundPage,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: sel ? vis.color : AppColors.border,
                                      width: sel ? 2 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(vis.icon,
                                          color: sel
                                              ? vis.color
                                              : AppColors.textHint,
                                          size: 24),
                                      const SizedBox(height: 4),
                                      Text(t.code,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: sel
                                                ? vis.color
                                                : AppColors.textSecondary,
                                          )),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 4),
                                        child: Text(t.label,
                                            style: const TextStyle(
                                                fontSize: 9,
                                                color: AppColors.textHint),
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                  if (_woType == null)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('Seleziona un tipo per continuare',
                          style: TextStyle(fontSize: 12, color: AppColors.textHint)),
                    ),
                  const SizedBox(height: 14),
                  _field(
                    controller: _descCtrl,
                    label: 'Descrizione intervento *',
                    hint: 'Es. Sostituzione contatore DN15',
                    validator: Validators.required,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 14),
                  // Priorità dal catalogo reale del backend (/anagrafica/priorities,
                  // schema WO) — non più codificata in modo fisso.
                  ref.watch(orderPrioritiesProvider).when(
                        loading: () => const LinearProgressIndicator(),
                        error: (e, _) => Text('Priorità non disponibili: $e',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textHint)),
                        data: (list) => DropdownButtonFormField<String>(
                          initialValue: _priorita,
                          isExpanded: true,
                          decoration:
                              const InputDecoration(labelText: 'Priorità'),
                          items: list
                              .map((c) => DropdownMenuItem(
                                  value: c.label,
                                  child: Text(c.label,
                                      overflow: TextOverflow.ellipsis)))
                              .toList(),
                          onChanged: (v) => setState(() => _priorita = v),
                        ),
                      ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── 1b. Dati specifici (dinamici per tipo OdL, dal cruscotto) ────
            if (_woType != null)
              ref.watch(workOrderFieldsProvider(_woType!)).maybeWhen(
                    data: (fields) => fields.isEmpty
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _SectionCard(
                              title: 'Dati specifici',
                              icon: Icons.tune_rounded,
                              child: Column(
                                children: [
                                  for (final f in fields)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 10),
                                      child: _dynFieldWidget(f),
                                    ),
                                ],
                              ),
                            ),
                          ),
                    orElse: () => const SizedBox.shrink(),
                  ),

            // ── 2. Appuntamento ──────────────────────────────────────────────
            _SectionCard(
              title: 'Data & Ora appuntamento',
              icon: Icons.event_outlined,
              child: Row(children: [
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _appointmentDate ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (d != null) setState(() => _appointmentDate = d);
                    },
                    child: _pickerBox(
                      icon: Icons.calendar_today_outlined,
                      text: _appointmentDate == null
                          ? 'Seleziona data'
                          : '${_appointmentDate!.day.toString().padLeft(2, '0')}/'
                              '${_appointmentDate!.month.toString().padLeft(2, '0')}/'
                              '${_appointmentDate!.year}',
                      empty: _appointmentDate == null,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      final parts = _startTime.split(':');
                      final t = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(
                            hour: int.parse(parts[0]),
                            minute: int.parse(parts[1])),
                      );
                      if (t != null) {
                        setState(() => _startTime =
                            '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
                      }
                    },
                    child: _pickerBox(
                      icon: Icons.access_time_rounded,
                      text: _startTime,
                      empty: false,
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 12),

            // ── 3. Indirizzo ─────────────────────────────────────────────────
            _SectionCard(
              title: 'Indirizzo intervento',
              icon: Icons.place_outlined,
              child: Column(children: [
                _field(
                    controller: _cityCtrl,
                    label: 'Città *',
                    hint: 'Es. ANCONA',
                    validator: Validators.required),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    flex: 3,
                    child: _field(
                        controller: _streetCtrl,
                        label: 'Via *',
                        hint: 'Es. VIA ROMA',
                        validator: Validators.required),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _field(
                        controller: _numberCtrl,
                        label: 'N°',
                        hint: '1'),
                  ),
                ]),
                const SizedBox(height: 10),
                _field(
                    controller: _additionalCtrl,
                    label: 'Info aggiuntive',
                    hint: 'Scala, piano, interno…'),
                const SizedBox(height: 10),
                _field(
                    controller: _sedeCtrl,
                    label: 'Sede tecnica / Equipment',
                    hint: 'Es. 74747'),
              ]),
            ),
            const SizedBox(height: 12),

            // ── 4. Cliente ───────────────────────────────────────────────────
            _SectionCard(
              title: 'Dati cliente (opzionale)',
              icon: Icons.person_outline_rounded,
              child: Column(children: [
                Row(children: [
                  Expanded(
                      child: _field(
                          controller: _nomeCtrl,
                          label: 'Nome',
                          hint: 'Mario')),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _field(
                          controller: _cognomeCtrl,
                          label: 'Cognome',
                          hint: 'Rossi')),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                      child: _field(
                          controller: _telefonoCtrl,
                          label: 'Telefono',
                          hint: '3401234567',
                          keyboardType: TextInputType.phone)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _field(
                          controller: _codBpCtrl,
                          label: 'Cod. BP SAP',
                          hint: '90012345')),
                ]),
              ]),
            ),
            const SizedBox(height: 12),

            // ── 5. Note ──────────────────────────────────────────────────────
            _SectionCard(
              title: 'Note aggiuntive',
              icon: Icons.notes_rounded,
              child: _field(
                controller: _noteCtrl,
                label: 'Note',
                hint: 'Informazioni aggiuntive per il tecnico…',
                maxLines: 3,
              ),
            ),
            const SizedBox(height: 15),

            // ── Bouton Crea ──────────────────────────────────────────────────
            ElevatedButton.icon(
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.add_circle_outline_rounded, size: 20),
              label: Text(_saving ? 'Creazione in corso…' : 'Crea Ordine di Lavoro'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                textStyle:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _dynFieldWidget(DynFieldSpec f) {
    if (f.type == DynFieldType.select) {
      return DropdownButtonFormField<String>(
        initialValue: _dynSel[f.key],
        isExpanded: true,
        decoration: InputDecoration(
          labelText: f.label,
          filled: true,
          fillColor: AppColors.backgroundPage,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        items: f.options
            .map((o) => DropdownMenuItem(value: o, child: Text(o)))
            .toList(),
        onChanged: (v) => setState(() => _dynSel[f.key] = v ?? ''),
      );
    }
    return _field(
      controller: _dynCtrl(f.key),
      label: f.label,
      maxLines: f.type == DynFieldType.multiline ? 3 : 1,
      keyboardType: f.type == DynFieldType.number
          ? const TextInputType.numberWithOptions(decimal: true)
          : null,
    );
  }

  /// Riquadro informativo mostrato quando un catalogo del cruscotto è
  /// vuoto o non raggiungibile (nessun dato hardcoded di ripiego).
  Widget _cruscottoInfo(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.backgroundPage,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.cloud_off_rounded,
              size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: AppColors.backgroundPage,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Widget _pickerBox(
      {required IconData icon, required String text, required bool empty}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.backgroundPage,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        Icon(icon, size: 16, color: AppColors.textHint),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: empty ? AppColors.textHint : AppColors.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ]),
    );
  }
}

// ─── Card de section ─────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard(
      {required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    letterSpacing: 0.3,
                  )),
            ]),
          ),
          const Divider(height: 1, color: AppColors.borderLight),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }
}
