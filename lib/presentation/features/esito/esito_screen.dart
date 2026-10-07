// Schermata Esito intervento : tecnico + economico + validazione finale.


import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../work_orders/widgets/odl_actions_menu.dart';
import '../../../domain/entities/entities.dart';
import '../../../core/utils/validators.dart';
import '../../providers/anagrafica_provider.dart';
import '../../providers/appointments_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/esito_provider.dart';
import '../../providers/odl_extension_provider.dart';
import '../../providers/work_orders_provider.dart';

class EsitoScreen extends ConsumerStatefulWidget {
  final String code;

  final bool embedded;

  const EsitoScreen({super.key, required this.code, this.embedded = false});

  @override
  ConsumerState<EsitoScreen> createState() => _EsitoScreenState();
}

class _EsitoScreenState extends ConsumerState<EsitoScreen> {
  final _formKey = GlobalKey<FormState>();
  EsitoResult? _result;
  String? _causeCode;
  String? _solutionCode;
  final _notesCtrl = TextEditingController();
  /// Oggetti del lavoro (mezzi/apparecchiature impegnati): partono con l'esito
  /// nel nodo `objects`. Per un automezzo l'equipment è la targa.
  final List<EsitoObject> _objects = [];
  final _finalReadingCtrl = TextEditingController();
  /// Lettura precedente: modificabile.
  /// 
  final _prevReadingCtrl = TextEditingController();
  /// Matricola contatore: editabile per l'attivazione/posa (nouvo contatore),
  /// precompilata e sola lettura quando il backend la fornisce (DISA).
  final _matricolaCtrl = TextEditingController();
  /// Spostamento contatore: nuova ubicazione (facoltativo). Inviato nel nodo
  /// `contatore` di POST /esiti solo se compilato.
  final _newUbicazioneCtrl = TextEditingController();
  final _newUbicazioneAggCtrl = TextEditingController();
  bool _meterInit = false;


  /// Inizio/Fine modificabili dall'operatore (override dei valori di default).
  DateTime? _startOverride;
  DateTime? _endOverride;
  bool _submitting = false;

  /// Inizio intervento: l'ora in cui l'operatore ha premuto "Avvia" (registrata
  /// in locale), altrimenti adesso. NON si ricava dalla data/ora
  /// dell'appuntamento: quello è il rendez-vous preso col cliente, non
  /// l'esecuzione. Né dalle date dell'OdL (inizio cardine, data esecuzione):
  /// sono date di pianificazione. La fine è il momento della chiusura.
  DateTime _startOf(WorkOrder? o) =>
      _startOverride ??
      ref.read(odlExtensionProvider(widget.code)).avviatoIl ??
      DateTime.now();

  DateTime _endOf() => _endOverride ?? DateTime.now();

  /// Nuovo contatore = POSA contatore, o attivazione senza contatore in
  /// anagrafica: la matricola e la lettura le inserisce l'operatore e non c'è
  /// una lettura precedente. Un'Apertura (ADS) su contatore esistente NON è un
  /// contatore nuovo: la matricola è già nota e la lettura precedente esiste.
  bool _isNewMeter(WorkOrder? o) => o?.isNuovoContatore ?? false;

  /// Precompila una sola volta i campi contatore. La lettura salvata in
  /// "Gestione contatore" (onglet Lettura) precompila il campo lettura, così
  /// non va reinserita alla chiusura.
  void _initMeterFields(WorkOrder? o) {
    if (_meterInit) return;
    _meterInit = true;
    final draft = ref.read(meterReadingDraftProvider(widget.code));
    if (draft != null) {
      _finalReadingCtrl.text = '${draft.reading}';
      if (draft.nota.isNotEmpty && _notesCtrl.text.isEmpty) {
        _notesCtrl.text = draft.nota;
      }
    }
    if (_isNewMeter(o)) return; // posa: niente precompilazione anagrafica
    _matricolaCtrl.text = o?.meter?.matricola ?? '';
    final prev = o?.meter?.previousReading ?? o?.meter?.lastReading;
    if (prev != null) _prevReadingCtrl.text = prev.toString();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _finalReadingCtrl.dispose();
    _prevReadingCtrl.dispose();
    _matricolaCtrl.dispose();
    _newUbicazioneCtrl.dispose();
    _newUbicazioneAggCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime({
    required DateTime initial,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2015),
      lastDate: DateTime(2035),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (!mounted) return;
    onPicked(DateTime(d.year, d.month, d.day, t?.hour ?? initial.hour,
        t?.minute ?? initial.minute));
  }

  /// Campo data/ora modificabile (tap → date + time picker).
  Widget _timeField(
          String label, DateTime value, ValueChanged<DateTime> onPicked) =>
      InkWell(
        onTap: () => _pickDateTime(initial: value, onPicked: onPicked),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: const Icon(Icons.edit_calendar_outlined, size: 18),
          ),
          child: Text(Fmt.dateTime(value), style: AppTextStyles.fieldValue),
        ),
      );

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_result == null) {
      showSapToast(context, 'Selezionare un esito', isError: true);
      return;
    }
    // Conferma obbligatoria: l'invio dell'esito CHIUDE l'OdL (COMPLETATO).
    final hasAppuntamento =
        ref.read(esitoAppuntamentoProvider(widget.code)) != null;
    final conferma = await showWfmConfirmDialog(
      context: context,
      title: 'Convalida esito',
      message: hasAppuntamento
          ? 'L\'OdL verrà chiuso e inviato (stato COMPLETATO), insieme all\'esito appuntamento. L\'operazione non è annullabile. Confermi?'
          : 'L\'OdL verrà chiuso e inviato (stato COMPLETATO). L\'operazione non è annullabile. Confermi?',
      confirmLabel: 'Convalida e invia',
      cancelLabel: 'Annulla',
      icon: Icons.send_rounded,
    );
    if (conferma != true || !mounted) return;
    setState(() => _submitting = true);
    final cid = ref.read(authControllerProvider.notifier).user?.cid ?? 'TEC001';
    final order = ref.read(workOrderDetailProvider(widget.code)).valueOrNull;

    // Lettura contatore per QUALSIASI OdL con contatore (ATTI/SOST/lettura/
    // DISA) e per la posa (contatore nuovo, meter == null): la lettura
    // precedente è dal campo modificabile, la matricola dal campo (posa) o dal
    // meter/equipment (contatore esistente).
    final readings = <MeterReading>[];
    if ((order?.hasMeterReading ?? false) &&
        _finalReadingCtrl.text.trim().isNotEmpty) {
      // Posa/attivazione: matricola inserita dall'operatore; altrimenti quella
      // del contatore esistente (o l'equipment).
      final matricola = _isNewMeter(order)
          ? _matricolaCtrl.text.trim()
          : (order?.meter?.matricola ?? order?.equipment ?? '');
      readings.add(MeterReading(
        matricola: matricola,
        previousReading:
            num.tryParse(_prevReadingCtrl.text.replaceAll(',', '.')),
        readingValue:
            num.tryParse(_finalReadingCtrl.text.replaceAll(',', '.')) ?? 0,
        readingDateTime: _endOf(),
      ));
    }

    // SOSTITUZIONE (SOST): la scheda "Sostituzione" del contatore produce una
    // bozza con contatore rimosso + nuovo + posizione. Alla chiusura si
    // trasmette: lettura al deposito del rimosso, lettura iniziale del nuovo
    // (entrambe in `letture`), e la posizione nel nodo `contatore`.
    final sub = ref.read(meterSubstitutionDraftProvider(widget.code));
    String? subNewLocation;
    String? subNewLocationAdd;
    // Dati del NUOVO contatore (nodo `newMeter` del backend).
    String? subNewSerial;
    String? subNewManufacturer;
    num? subNewInstallReading;
    DateTime? subNewInstallDate;
    if (sub != null) {
      // `meterReadings` = SOLO la lettura FINALE del vecchio contatore rimosso.
      if (_finalReadingCtrl.text.trim().isEmpty &&
          sub.depositReading != null &&
          (order?.meter?.matricola ?? '').trim().isNotEmpty) {
        readings.add(MeterReading(
          matricola: order!.meter!.matricola,
          readingValue: sub.depositReading!,
          readingDateTime: _endOf(),
        ));
      }
      // Il NUOVO contatore va nel nodo `newMeter` (non in meterReadings): così
      // arriva anche il produttore, che le letture non trasportano.
      if (sub.newMatricola.trim().isNotEmpty) {
        subNewSerial = sub.newMatricola.trim();
        subNewManufacturer =
            sub.newProduttore.trim().isEmpty ? null : sub.newProduttore.trim();
        subNewInstallReading = sub.initialReading ?? 0;
        subNewInstallDate = sub.posaDate;
      }
      if (sub.position.trim().isNotEmpty) subNewLocation = sub.position.trim();
      if (sub.positionAdd.trim().isNotEmpty) {
        subNewLocationAdd = sub.positionAdd.trim();
      }
    }

    // Materiali impegnati sul campo (locali): partono col submit dell'esito.
    final materiali = ref.read(odlExtensionProvider(widget.code)).materiali;

    // Ore lavorate per operazione digitate nella scheda Operazioni. Si
    // trasmettono solo le voci di LAVORO: l'automezzo è già la somma delle voci
    // di lavoro, quindi inviarlo raddoppierebbe il totale che il backend salva
    // in `oreLavorate`. Forma per riga: { operation, description, hours }.
    final ore = ref
        .read(odlExtensionProvider(widget.code))
        .ore
        .where((o) => !o.isAutomezzo && o.hours > 0)
        .map((o) => HoursWorked(
              operation: o.operationNumber,
              description: o.description,
              hours: o.hours,
            ))
        .toList();

    // Esito appuntamento salvato in locale: viaggia col submit finale (il
    // backend lo accetta nel nodo `appointment` di POST /esiti).
    final ap = ref.read(esitoAppuntamentoProvider(widget.code));
    final appointment = ap == null
        ? null
        : EsitoAppuntamento(
            esito: ap.esito,
            causa: ap.causaCode,
            motivo: ap.motivo.isEmpty ? null : ap.motivo,
            clientePresente: ap.presenzaCliente,
            sopralluogoData: ap.dataSopralluogo,
            sopralluogoOra: ap.oraSopralluogo,
            ritiro: ap.ritiro.isEmpty ? null : ap.ritiro,
            causaRitardo:
                ap.causaRitardo.isEmpty ? null : ap.causaRitardo,
            motivoRitardo:
                ap.motivoRitardo.isEmpty ? null : ap.motivoRitardo,
          );

    final esito = Esito(
      workOrderCode: widget.code,
      technicianCid: cid,
      startDateTime: _startOf(order),
      endDateTime: _endOf(),
      result: _result,
      causeCode: _causeCode,
      solutionCode: _solutionCode,
      notes: _notesCtrl.text,
      meterReadings: readings,
      materials: materiali,
      appointment: appointment,
      hoursWorked: ore,
      objects: List.of(_objects),
      // Posizione contatore: dal campo "Spostamento contatore" dell'esito
      // oppure, per una SOST, dalla scheda Sostituzione.
      newMeterLocation: _newUbicazioneCtrl.text.trim().isNotEmpty
          ? _newUbicazioneCtrl.text.trim()
          : subNewLocation,
      newMeterLocationAdditional: _newUbicazioneAggCtrl.text.trim().isNotEmpty
          ? _newUbicazioneAggCtrl.text.trim()
          : subNewLocationAdd,
      // Nuovo contatore posato (SOST) → nodo `newMeter`.
      newMeterSerial: subNewSerial,
      newMeterManufacturer: subNewManufacturer,
      newMeterInstallReading: subNewInstallReading,
      newMeterInstallDate: subNewInstallDate,
    );
    final res = await ref.read(esitoControllerProvider).submit(esito);
    if (!mounted) return;
    setState(() => _submitting = false);
    res.when(
      success: (status) {
        showSapToast(context,
            status == 'PENDING' ? 'Esito in coda (offline)' : 'Esito inviato');
        context.go('/work-orders');
      },
      failure: (f) => showSapToast(context, f.message, isError: true),
    );
  }

  /// Aggiunge un oggetto del lavoro (targa/equipment + descrizione).
  Future<void> _addObject() async {
    final oggetto = await showDialog<EsitoObject>(
      context: context,
      builder: (_) => const OggettoLavoroDialog(),
    );
    if (oggetto == null || !mounted) return;
    setState(() => _objects.add(oggetto));
  }

  @override
  Widget build(BuildContext context) {
    final causes = ref.watch(causeCodesProvider);
    final solutions = ref.watch(solutionCodesProvider);
    final order = ref.watch(workOrderDetailProvider(widget.code)).valueOrNull;
    final isDisa = order?.hasDisattivazione ?? false;
    final isPosa = order?.isPosaContatore ?? false;
    // Sezione relevé: per QUALSIASI OdL con contatore (ATTI/SOST/lettura/DISA)
    // e per le attivazioni anche quando il contatore è nuovo (meter == null).
    final hasMeterReading = order?.hasMeterReading ?? false;
    final meterTitle = order == null
        ? 'CONTATORE'
        : order.hasDisattivazione
            ? 'DISATTIVAZIONE FORNITURA'
            : isPosa
                ? 'POSA CONTATORE'
                : order.hasAttivazione
                    ? 'ATTIVAZIONE FORNITURA'
                    : order.hasSostituzione
                        ? 'SOSTITUZIONE CONTATORE'
                        : 'LETTURA CONTATORE';
    final readingLabel = order?.hasDisattivazione == true
        ? 'Lettura finale contatore'
        : isPosa
            ? 'Lettura di posa'
            : order?.hasAttivazione == true
                ? 'Lettura di attivazione'
                : 'Lettura contatore';
    final newMeter = _isNewMeter(order);
    _initMeterFields(order);

    final form = Form(
      key: _formKey,
      child: ListView(
        padding: kPagePadding,
        children: [
            const SectionHeader(title: 'TEMPI INTERVENTO'),
            FormGrid(children: [
              _timeField('Inizio', _startOf(order),
                  (dt) => setState(() => _startOverride = dt)),
              _timeField('Fine', _endOf(),
                  (dt) => setState(() => _endOverride = dt)),
            ]),
            const SectionHeader(title: 'ESITO'),
            Row(
              children: EsitoResult.values.map((r) {
                final selected = _result == r;
                final color = switch (r) {
                  EsitoResult.success => AppColors.accentGreen,
                  EsitoResult.rinviato => AppColors.accentOrange,
                  EsitoResult.impossibile => AppColors.accentRed,
                };
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(r.label),
                      selected: selected,
                      selectedColor: color.withValues(alpha: 0.18),
                      labelStyle: TextStyle(
                          color: selected ? color : AppColors.textSecondary,
                          fontWeight: FontWeight.w600),
                      onSelected: (_) => setState(() => _result = r),
                    ),
                  ),
                );
              }).toList(),
            ),
            if (hasMeterReading) ...[
              SectionHeader(title: meterTitle),
              // Posa/attivazione (compteur neuf) → matricola EDITABILE + scan.
              // Altrimenti (contatore esistente, es. DISA) → sola lettura.
              if (newMeter)
                TextFormField(
                  controller: _matricolaCtrl,
                  decoration: InputDecoration(
                    labelText: 'Matricola nuovo contatore *',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.qr_code_scanner),
                      tooltip: 'Scansiona matricola',
                      onPressed: () async {
                        final code =
                            await context.push<String>(AppRoutes.scanner);
                        if (code != null && code.isNotEmpty) {
                          setState(() => _matricolaCtrl.text = code);
                        }
                      },
                    ),
                  ),
                  validator: (v) => _result == EsitoResult.success &&
                          (v ?? '').trim().isEmpty
                      ? 'Inserire la matricola del contatore'
                      : null,
                )
              else
                FieldRow(
                    label: 'Matricola contatore',
                    value: order!.meter!.matricola),
              const SizedBox(height: 12),
              // Lettura precedente SOLO per contatore esistente (non per posa):
              // per un'attivazione non c'è un contatore precedente.
              if (!newMeter) ...[
                TextFormField(
                  controller: _prevReadingCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Lettura precedente',
                    helperText: 'Precompilata da SAP se disponibile',
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _finalReadingCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                    labelText:
                        '$readingLabel${_result == EsitoResult.success ? ' *' : ''}'),
                // Obbligatoria solo se l'esito è "Riuscito": un Rinviato/
                // Impossibile può non avere lettura.
                validator: (v) => _result == EsitoResult.success
                    ? Validators.meterReading(v,
                        previous: order?.meter?.previousReading)
                    : null,
              ),
              if (isDisa) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: AppColors.statusReceivedBg,
                      borderRadius: BorderRadius.circular(8)),
                  child: const Row(children: [
                    Icon(Icons.info_outline,
                        size: 18, color: AppColors.primary),
                    SizedBox(width: 8),
                    Expanded(
                        child: Text(
                            'Seleziona «Riuscito» per confermare la disattivazione, «Impossibile» in caso negativo.',
                            style: AppTextStyles.bodySmall)),
                  ]),
                ),
              ],
            ],
            const SectionHeader(title: 'CAUSA E SOLUZIONE'),
            causes.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Errore: $e', style: AppTextStyles.bodySmall),
              data: (list) => DropdownButtonFormField<String>(
                initialValue: _causeCode,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Motivo intervento'),
                items: list
                    .map((c) => DropdownMenuItem(
                        value: c.code, child: Text(c.label, overflow: TextOverflow.ellipsis)))
                    .toList(),
                // Facoltativo: il backend non lo richiede e non per tutti i tipi
                // di OdL ha senso (es. ZA02).
                onChanged: (v) => setState(() => _causeCode = v),
              ),
            ),
            const SizedBox(height: 12),
            solutions.when(
              loading: () => const SizedBox.shrink(),
              error: (e, _) => const SizedBox.shrink(),
              data: (list) => DropdownButtonFormField<String>(
                initialValue: _solutionCode,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Soluzione fornita'),
                items: list
                    .map((c) => DropdownMenuItem(
                        value: c.code, child: Text(c.label, overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (v) => setState(() => _solutionCode = v),
              ),
            ),
            // ── MATERIALI (impegnati sul campo, inviati con l'esito) ────────
            // -- Ancora da implementrare lato backend
            const SectionHeader(title: 'MATERIALI'),
            if (ref.watch(odlExtensionProvider(widget.code)).materiali.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text('Nessun materiale impegnato',
                    style: AppTextStyles.bodySmall),
              )
            else
              for (final m
                  in ref.watch(odlExtensionProvider(widget.code)).materiali)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    const Icon(Icons.inventory_2_outlined,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        [m.materialCode, m.description]
                            .where((s) => s.isNotEmpty)
                            .join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyMedium,
                      ),
                    ),
                    Text('x${m.usedQuantity}', style: AppTextStyles.bodySmall),
                  ]),
                ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () =>
                    context.push(AppRoutes.addComponentePath(widget.code)),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Aggiungi materiale'),
              ),
            ),
            // ── OGGETTI (mezzi / apparecchiature impegnati, nodo `objects`) ──
            const SectionHeader(title: 'OGGETTI (MEZZI / APPARECCHIATURE)'),
            if (_objects.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text('Nessun oggetto registrato',
                    style: AppTextStyles.bodySmall),
              )
            else
              for (var i = 0; i < _objects.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    const Icon(Icons.local_shipping_outlined,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        [_objects[i].equipment, _objects[i].description]
                            .where((t) => t.isNotEmpty)
                            .join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyMedium,
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Rimuovi',
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() => _objects.removeAt(i)),
                    ),
                  ]),
                ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _addObject,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Aggiungi oggetto'),
              ),
            ),
            // ── ESITO APPUNTAMENTO (compilato altrove, inviato con l'esito) ─
            const SectionHeader(title: 'ESITO APPUNTAMENTO'),
            Builder(builder: (_) {
              final hasAp =
                  ref.watch(esitoAppuntamentoProvider(widget.code)) != null;
              return Row(children: [
                Icon(
                    hasAp
                        ? Icons.check_circle_outline
                        : Icons.event_note_outlined,
                    size: 18,
                    color: hasAp
                        ? AppColors.accentGreen
                        : AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasAp
                        ? 'Compilato — verrà inviato con l\'esito'
                        : 'Non compilato',
                    style: AppTextStyles.bodyMedium,
                  ),
                ),
                TextButton(
                  onPressed: () => context
                      .push(AppRoutes.esitoAppuntamentoPath(widget.code)),
                  child: Text(hasAp ? 'Modifica' : 'Compila'),
                ),
              ]);
            }),
            // ── SPOSTAMENTO CONTATORE (facoltativo, solo OdL con contatore) ─
            // Il backend accetta la nuova ubicazione nel nodo `contatore` di
            // POST /esiti. Da compilare SOLO se il contatore è stato spostato;
            // vuoto = non spostato (nessun dato inviato).
            if (hasMeterReading) ...[
              const SectionHeader(title: 'SPOSTAMENTO CONTATORE'),
              if (order?.meter != null &&
                  (order!.meter!.ubicazione.isNotEmpty ||
                      order.meter!.ubicazioneDesc.isNotEmpty))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Ubicazione attuale: '
                    '${[order.meter!.ubicazione, order.meter!.ubicazioneDesc].where((s) => s.isNotEmpty).join(' · ')}',
                    style: AppTextStyles.bodySmall,
                  ),
                ),
              TextFormField(
                controller: _newUbicazioneCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nuova ubicazione',
                  helperText: 'Compila solo se il contatore è stato spostato',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _newUbicazioneAggCtrl,
                decoration: const InputDecoration(
                    labelText: 'Aggiunta ubicazione'),
              ),
            ],
            const SectionHeader(title: 'COMMENTI'),
            VoiceTextField(
              controller: _notesCtrl,
              label: 'Commenti liberi',
              maxLines: 4,
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded),
                label: Text(_submitting ? 'Invio…' : 'Convalida e invia esito'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      );

    if (widget.embedded) return form;
    return Scaffold(
      appBar: AppBar(
        title: Text(isDisa
            ? 'Esito Disattivazione ${widget.code}'
            : 'Esito OdL ${widget.code}'),
        actions: [
          OdlActionsMenu(code: widget.code, scope: OdlMenuScope.esito),
        ],
      ),
      body: form,
    );
  }
}

// ─── Oggetto del lavoro ──────────────────────────────────────────────────────

/// Dialogo per aggiungere un oggetto del lavoro (mezzo o apparecchiatura).
/// Restituisce l'[EsitoObject], oppure null se annullato. La targa è
/// obbligatoria e si può leggere col barcode; la descrizione si può dettare.
class OggettoLavoroDialog extends StatefulWidget {
  const OggettoLavoroDialog({super.key});

  @override
  State<OggettoLavoroDialog> createState() => _OggettoLavoroDialogState();
}

class _OggettoLavoroDialogState extends State<OggettoLavoroDialog> {
  final _formKey = GlobalKey<FormState>();
  final _eqCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  @override
  void dispose() {
    _eqCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _scansiona() async {
    final code = await context.push<String>(AppRoutes.scanner);
    if (code != null && code.trim().isNotEmpty && mounted) {
      setState(() => _eqCtrl.text = code.trim().toUpperCase());
    }
  }

  void _conferma() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
        context,
        EsitoObject(
            equipment: _eqCtrl.text.trim().toUpperCase(),
            description: _descCtrl.text.trim()));
  }

  InputDecoration _decoration(String label,
          {String? hint, Widget? suffixIcon}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: suffixIcon,
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
      );

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                        color: AppColors.primarySurface,
                        shape: BoxShape.circle),
                    child: const Icon(Icons.local_shipping_outlined,
                        size: 22, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Oggetto del lavoro',
                        style: AppTextStyles.headingMedium),
                  ),
                ]),
                const SizedBox(height: 6),
                const Text(
                  'Il mezzo o l\'apparecchiatura impegnata in questo intervento.',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _eqCtrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.next,
                  decoration: _decoration(
                    'Targa / Equipment *',
                    hint: 'Es. CR812EP',
                    suffixIcon: IconButton(
                      tooltip: 'Scansiona codice',
                      icon: const Icon(Icons.qr_code_scanner,
                          color: AppColors.primary),
                      onPressed: _scansiona,
                    ),
                  ),
                  validator: (v) => (v ?? '').trim().isEmpty
                      ? 'Indica la targa o l\'equipment'
                      : null,
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(4, 6, 4, 0),
                  child: Text('Per un automezzo, la targa.',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textHint)),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descCtrl,
                  minLines: 2,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _decoration(
                    'Descrizione',
                    hint: 'Es. 159 - Fiat Doblò',
                    suffixIcon: VoiceSuffixIcons(controller: _descCtrl),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(4, 6, 4, 0),
                  child: Text(
                      'Per un automezzo, comincia col numero del mezzo.',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textHint)),
                ),
                const SizedBox(height: 22),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Annulla'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _conferma,
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: const Text('Aggiungi'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
