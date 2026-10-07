// Creazione ODL dal campo - form multi-section

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/note_ordine.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';
import '../../providers/anagrafica_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/avviso_extension_provider.dart';
import '../../providers/avvisi_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/creation_provider.dart';
import '../../widgets/assegnatario_field.dart';
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
  /// Precompilazioni (scenario 2: "crea OdL SOST da un altro OdL").
  /// Vuoti = creazione libera (comportamento invariato).
  final String? initialWoType;
  final String? meterMatricola;
  final String? originOrdine;

  /// Numero dell'avviso da cui nasce l'OdL ("Genera OdL" → SOST): indirizzo,
  /// cliente e sede si precompilano dall'avviso.
  final String? originAvviso;

  /// Posizione del punto di rete (mappa ArcGIS) da cui nasce l'OdL: va
  /// sull'indirizzo, così la mappa lo posiziona esattamente lì.
  final double? latitudine;
  final double? longitudine;

  /// Ciclo di lavoro da proporre fra le righe di /wo-templates (es. CONRID1
  /// per un OdL ZA02 nato da un riduttore di pressione).
  final String? initialGruppoCicli;

  /// Indirizzo del punto scelto sulla mappa (geocodifica inversa Esri).
  final IndirizzoMappa? indirizzo;

  const CreateOrderScreen({
    super.key,
    this.initialWoType,
    this.meterMatricola,
    this.originOrdine,
    this.originAvviso,
    this.latitudine,
    this.longitudine,
    this.initialGruppoCicli,
    this.indirizzo,
  });

  @override
  ConsumerState<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends ConsumerState<CreateOrderScreen> {
  final _formKey = GlobalKey<FormState>();

  String? _woType;
  // Tipo attività PM scelto dalla tabella di correlazione (/wo-templates):
  // decide le operazioni vere del ciclo SAP (SOS vs S01…). Vuoto = riga
  // predefinita del tipo (il backend usa comunque quella di default).
  WorkOrderActivityTemplate? _template;

  @override
  void initState() {
    super.initState();
    // Coordinate della posizione selezionata sulla mappa.
    _latitudeCtrl.text = _coordinateText(widget.latitudine);
    _longitudeCtrl.text = _coordinateText(widget.longitudine);
    // Prefill quando si crea un OdL a partire da un altro (tracciabilità).
    if ((widget.initialWoType ?? '').isNotEmpty) {
      _woType = widget.initialWoType!.trim().toUpperCase();
    }
    final origine = (widget.originOrdine ?? '').trim();
    final matricola = (widget.meterMatricola ?? '').trim();
    // Tracciabilità in campi STRUTTURATI (come l'app precedente):
    // "Ordine Precedente" pronto per il backend, il contatore nelle note
    // (nessun campo matricola nel modulo di creazione).
    if (origine.isNotEmpty) _ordinePrecedenteCtrl.text = origine;
    final ind = widget.indirizzo;
    if (ind != null) {
      _streetCtrl.text = ind.via;
      _numberCtrl.text = ind.civico;
      _cityCtrl.text = ind.comune;
      _capCtrl.text = ind.cap;
    }
    final avviso = (widget.originAvviso ?? '').trim();
    if (avviso.isNotEmpty) {
      _notificaPrecedenteCtrl.text = avviso;
      _prefillDaAvviso(avviso);
    }
    if (matricola.isNotEmpty) {
      _noteCtrl.text = 'Contatore $matricola';
      // La "casetta": il backend restituisce contatore/indirizzo/cliente/sede
      // dell'apparecchiatura → precompiliamo la SOST invece di far ridigitare.
      _prefillDaCasetta(matricola);
    }
  }

  bool _prefilling = false;

  /// Precompila dai dati dell'avviso d'origine (indirizzo, cliente, sede,
  /// descrizione e, se l'avviso la porta, la matricola). Non sovrascrive ciò che
  /// l'operatore ha già scritto; se l'avviso non si legge si compila a mano.
  Future<void> _prefillDaAvviso(String numero) async {
    setState(() => _prefilling = true);
    try {
      final a = await ref.read(avvisoDetailProvider(numero).future);
      if (!mounted) return;
      void fill(TextEditingController c, String? v) {
        if (c.text.trim().isEmpty && (v ?? '').trim().isNotEmpty) {
          c.text = v!.trim();
        }
      }

      fill(_descCtrl, a.descrizione);
      final ad = a.address;
      fill(_cityCtrl, ad.city.isNotEmpty ? ad.city : ad.localita);
      fill(_streetCtrl, ad.street);
      fill(_numberCtrl, ad.streetNumber);
      fill(_additionalCtrl, ad.additionalInfo);
      fill(_provinciaCtrl, ad.provincia);
      fill(_capCtrl, ad.cap);
      final cu = a.customer;
      fill(_nomeCtrl, cu.nome);
      fill(_cognomeCtrl, cu.cognome);
      fill(_telefonoCtrl, cu.telefono ?? a.cellulare);
      fill(_codBpCtrl, cu.codBp);
      fill(_sedeCtrl, a.sedeTecnica);
      fill(_dynCtrl('matricola'), a.matricola);
    } catch (_) {
      // Avviso non leggibile: il tecnico compila a mano, nessun errore.
    } finally {
      if (mounted) setState(() => _prefilling = false);
    }
  }

  /// Cerca l'equipment (GET /anagrafica/equipment?matricola=) e precompila
  /// indirizzo, cliente, sede e i campi contatore. `null` = matricola ignota:
  /// il tecnico compila a mano, nessun errore.
  Future<void> _prefillDaCasetta(String matricola) async {
    setState(() => _prefilling = true);
    final res = await ref
        .read(anagraficaRepositoryProvider)
        .getEquipment(matricola: matricola);
    final e = res.valueOrNull;
    if (!mounted) {
      _prefilling = false;
      return;
    }
    if (e == null) {
      setState(() => _prefilling = false);
      return;
    }
    void fill(TextEditingController c, String v) {
      if (c.text.trim().isEmpty && v.trim().isNotEmpty) c.text = v.trim();
    }

    final a = e.address;
    if (a != null) {
      fill(_cityCtrl, a.city.isNotEmpty ? a.city : (a.localita));
      fill(_streetCtrl, a.street);
      fill(_numberCtrl, a.streetNumber);
      fill(_additionalCtrl, a.additionalInfo);
      fill(_provinciaCtrl, a.provincia);
      fill(_capCtrl, a.cap);
    } else {
      fill(_cityCtrl, e.comune.isNotEmpty ? e.comune : e.localita);
    }
    final cust = e.customer;
    if (cust != null) {
      fill(_nomeCtrl, cust.nome ?? '');
      fill(_cognomeCtrl, cust.cognome ?? '');
      fill(_telefonoCtrl, cust.telefono ?? '');
      fill(_codBpCtrl, cust.codBp ?? '');
    }
    fill(_sedeCtrl, e.sedeTecnica);
    // Contatore da sostituire: matricola (obbligatoria SOST) + dati noti.
    fill(_dynCtrl('matricola'),
        e.matricola.isNotEmpty ? e.matricola : matricola);
    fill(_dynCtrl('marca'), e.meter?.brand ?? e.produttore);
    fill(_dynCtrl('calibro'), e.meter?.caliber ?? '');
    final lettura = e.meter?.lastReading;
    if (lettura != null) fill(_dynCtrl('lettura'), lettura.toString());
    setState(() => _prefilling = false);
  }

  String? _priorita; // CODICE priorità scelto (catalogo backend /priorities)
  String? _assegnaA; // collega a cui passare l'OdL; null = resta a chi crea
  final _descCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _streetCtrl = TextEditingController();
  final _numberCtrl = TextEditingController();
  final _additionalCtrl = TextEditingController();
  final _provinciaCtrl = TextEditingController();
  final _capCtrl = TextEditingController();
  final _latitudeCtrl = TextEditingController();
  final _longitudeCtrl = TextEditingController();
  final _sedeCtrl = TextEditingController();
  final _nomeCtrl = TextEditingController();
  final _cognomeCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _codBpCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  // Tracciabilità (app precedente): Ordine/Notifica Precedente.
  final _ordinePrecedenteCtrl = TextEditingController();
  final _notificaPrecedenteCtrl = TextEditingController();

  DateTime? _appointmentDate;
  // Ora dell'appuntamento: vuota finché il tecnico non la sceglie.
  String _startTime = '';
  bool _saving = false;

  // Campi dinamici per tipo OdL: id → controller di testo / valore dropdown.
  final Map<String, TextEditingController> _dynCtrls = {};
  final Map<String, String> _dynSel = {};

  TextEditingController _dynCtrl(String id) =>
      _dynCtrls.putIfAbsent(id, () => TextEditingController());

  @override
  void dispose() {
    for (final c in [
      _descCtrl,
      _cityCtrl,
      _streetCtrl,
      _numberCtrl,
      _additionalCtrl,
      _provinciaCtrl,
      _capCtrl,
      _latitudeCtrl,
      _longitudeCtrl,
      _sedeCtrl,
      _nomeCtrl,
      _cognomeCtrl,
      _telefonoCtrl,
      _codBpCtrl,
      _noteCtrl,
      _ordinePrecedenteCtrl,
      _notificaPrecedenteCtrl,
    ]) {
      c.dispose();
    }
    for (final c in _dynCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Vero solo se l'OdL nasce da un'origine (altro OdL o avviso): allora i
  /// riferimenti sono precompilati e vanno mostrati. Creazione libera → niente.
  bool get _hasTracciabilita =>
      _ordinePrecedenteCtrl.text.trim().isNotEmpty ||
      _notificaPrecedenteCtrl.text.trim().isNotEmpty;

  /// La riga da usare quando il tecnico non sceglie: quella marcata come
  /// predefinita, altrimenti la prima. `null` se la tabella è vuota.
  WorkOrderActivityTemplate? _defaultTemplate(
      List<WorkOrderActivityTemplate> rows) {
    if (rows.isEmpty) return null;
    return _rigaDelCiclo(rows) ??
        rows.firstWhere((t) => t.predefinita, orElse: () => rows.first);
  }

  /// La riga col ciclo richiesto dall'origine (es. CONRID1), se il backend
  /// la offre per il tipo scelto.
  WorkOrderActivityTemplate? _rigaDelCiclo(
      List<WorkOrderActivityTemplate> rows) {
    final ciclo = (widget.initialGruppoCicli ?? '').trim().toUpperCase();
    if (ciclo.isEmpty) return null;
    for (final r in rows) {
      if (r.gruppoCicli.toUpperCase() == ciclo) return r;
    }
    return null;
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
    final creatore =
        utente == null ? 'wfm.mobile' : '${utente.fullName} ($cid)';
    // Operazioni: le tre standard di ogni OdL (kOperazioniStandard: 0010
    // Trasferimento, 0040 Lavori Idraulici, 0200 Automezzi, quelle del
    // backend). Quando l'ordine è sincronizzato valgono quelle che il backend
    // manda. Le tre fittizie di una volta (0010 "Sopralluogo iniziale", 0020,
    // 0030) NON esistono in SAP e sono rimosse.
    final now = DateTime.now();
    // Campi dinamici (per tipo OdL, dal cruscotto) → Meter + note strutturate.
    final dynFields = _woType == null
        ? const <DynFieldSpec>[]
        : (ref.read(workOrderFieldsProvider(_woType!)).valueOrNull ??
            const <DynFieldSpec>[]);
    String dynVal(String id, {bool option = false}) =>
        option ? (_dynSel[id] ?? '') : (_dynCtrls[id]?.text.trim() ?? '');
    // Valori dei campi specifici che NON hanno un campo proprio: finiscono nelle
    // note senza intestazione. La matricola viaggia nel suo campo: non si ripete.
    final dynExtra = <({String label, String value})>[];
    for (final f in dynFields) {
      if (kCampiConCampoProprio.contains(f.key)) continue;
      final v = dynVal(f.key, option: f.type == DynFieldType.select);
      if (v.isNotEmpty) dynExtra.add((label: f.label, value: v));
    }
    Meter? meter;
    // Matricola del contatore: DEVE finire anche nel campo top-level dell'OdL,
    // perché è quello che il serializzatore invia (`workOrderToJson` non emette
    // il nodo `meter`) e che il backend legge (`body.matricola`). Senza, una
    // SOST viene rifiutata con 422 anche se il tecnico l'ha digitata.
    String matricolaOdl = dynVal('matricola');
    if (_woType == 'ATTI' || _woType == 'SOST' || _woType == 'DISA') {
      if (matricolaOdl.isNotEmpty) {
        final sigillo = dynVal('sigillo');
        meter = Meter(
          matricola: matricolaOdl,
          caliber: dynVal('calibro'),
          brand: dynVal('marca'),
          sealNumber: sigillo.isEmpty ? null : sigillo,
          lastReading: num.tryParse(dynVal('lettura').replaceAll(',', '.')),
        );
      }
    }
    final notes = componiNoteCreazione(extra: dynExtra, base: _noteCtrl.text);

    // Tipo attività scelto (o predefinito del tipo): il backend deriva
    // ciclo/settore, ma se il tecnico ha scelto una riga la mandiamo così il
    // cruscotto sa quale attività PM e quale ciclo sono (es. ZA02: CONRCO1 o
    // CONRID1, che il backend non può indovinare).
    final tmplRows =
        ref.read(workOrderTemplatesProvider(_woType!)).valueOrNull ??
            const <WorkOrderActivityTemplate>[];
    final tmpl = _template ?? _defaultTemplate(tmplRows);
    // Settore contabile: il CODICE che il backend deriva dal tipo (POT, FOG…).
    // Niente valore di ripiego inventato: se il tipo non ne ha (ZMAV), resta
    // vuoto e lo decide il backend.
    final settore = tmpl?.settoreContabile ?? '';
    // Priorità: al backend va il codice; la descrizione serve solo a mostrarla.
    final prioList = ref.read(orderPrioritiesProvider(_woType!)).valueOrNull ??
        const <CodeLabel>[];
    final prioDesc = prioList
        .where((c) => c.code == _priorita)
        .map((c) => c.label)
        .firstOrNull;

    final code = ref.read(creationControllerProvider).newWorkOrderId();
    final order = WorkOrder(
      externalCode: code,
      woType: _woType!,
      woTypeDescription: _descCtrl.text.trim(),
      tam: _woType!,
      tipoAttivitaCodice: tmpl?.tipoAttivita,
      tipoAttivitaNome: tmpl?.tipoAttivitaDesc,
      status: WorkOrderStatus.ricevuto,
      operations: kOperazioniStandard,
      priorita: prioDesc ?? '',
      prioritaCodice: _priorita,
      gruppoCicli: (tmpl?.gruppoCicli ?? '').isEmpty ? null : tmpl!.gruppoCicli,
      creatoDa: creatore,
      // Tracciabilità: Notifica Precedente (avviso, letta dal backend) e
      // Ordine Precedente (pronto per il backend).
      notificationNumberSap: _notificaPrecedenteCtrl.text.trim().isEmpty
          ? null
          : _notificaPrecedenteCtrl.text.trim(),
      avvisoOrigine: _notificaPrecedenteCtrl.text.trim().isEmpty
          ? null
          : _notificaPrecedenteCtrl.text.trim(),
      ordineOrigine: _ordinePrecedenteCtrl.text.trim().isEmpty
          ? null
          : _ordinePrecedenteCtrl.text.trim(),
      // Nessun appuntamento inventato: la data e l'ora si mandano solo se il
      // tecnico le ha scelte (il backend non ne mette: senza data niente
      // appuntamento).
      appointmentDate: _appointmentDate,
      appointmentStartTime: _appointmentDate == null ? '' : _startTime,
      address: Address(
        city: _cityCtrl.text.trim(),
        street: _streetCtrl.text.trim(),
        streetNumber: _numberCtrl.text.trim(),
        additionalInfo: _additionalCtrl.text.trim(),
        provincia: _provinciaCtrl.text.trim(),
        cap: _capCtrl.text.trim(),
        latitude: _parseCoordinate(_latitudeCtrl.text),
        longitude: _parseCoordinate(_longitudeCtrl.text),
      ),
      customer: Customer(
        nome: _nomeCtrl.text.trim(),
        cognome: _cognomeCtrl.text.trim(),
        telefono: _telefonoCtrl.text.trim(),
        codBp: _codBpCtrl.text.trim(),
      ),
      referente: '${_nomeCtrl.text.trim()} ${_cognomeCtrl.text.trim()}'.trim(),
      telefonoCliente: _telefonoCtrl.text.trim(),
      sedeTecnica: _sedeCtrl.text.trim(),
      // Campo top-level letto dal backend (body.matricola): senza, SOST → 422.
      matricola: matricolaOdl.isEmpty ? null : matricolaOdl,
      meter: meter,
      notes: notes,
      accountingSector: settore,
      cidAssegnato: cid,
      assegnaA: _assegnaA,
      createdAt: now,
      localStatus: LocalSyncStatus.pendingUpload,
    );
    // Local-first: l'OdL resta sul tablet finché l'operatore non sincronizza.
    await ref.read(creationControllerProvider).addWorkOrder(order);
    // Da avviso: l'avviso risulta "OdL generato" e non ricompare tra i Pronto
    // Intervento da prendere in carico (stesso comportamento di "Genera OdL").
    final daAvviso = _notificaPrecedenteCtrl.text.trim();
    if (daAvviso.isNotEmpty && (widget.originAvviso ?? '').trim() == daAvviso) {
      await ref
          .read(avvisoExtensionProvider(daAvviso).notifier)
          .setOrdineGenerato(code);
    }
    if (!mounted) return;
    setState(() => _saving = false);

    // Conferma della creazione con l'invio proposto subito: l'operatore non
    // deve cercare altrove il pulsante di sincronizzazione.
    await showCreatedSyncDialog(
      context,
      ref,
      title: 'Ordine creato',
      message: _assegnaA == null
          ? 'L\'ordine di lavoro è salvato sul tablet. '
              'Vuoi inviarlo subito al cruscotto?'
          : 'L\'ordine di lavoro è salvato sul tablet: passerà a $_assegnaA '
              'appena inviato al cruscotto. Vuoi inviarlo subito?',
    );
    if (!mounted) return;
    // Dopo la creazione si torna alla LISTA degli OdL (non al dettaglio): il
    // nuovo OdL è lì, in attesa di sincronizzazione, e il tasto Indietro non
    // riporta più negli step del wizard. Per modificarlo si apre l'OdL dalla
    // lista. `go` azzera lo stack del wizard.
    context.go(AppRoutes.workOrders);
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
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
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
            if (_prefilling)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: const Row(
                  children: const [
                    SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 10),
                    Text('Recupero dati dalla casetta…',
                        style: TextStyle(
                            fontSize: 12.5, color: AppColors.textSecondary)),
                  ],
                ),
              ),
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
                          // Match code: tocca il campo per aprire l'elenco dei
                          // tipi OdL selezionabili (valori/etichette dal cruscotto).
                          // ZF01 e SOST sono i tipi più usati sul campo: in testa
                          // alla lista, gli altri a seguire nell'ordine ricevuto.
                          final tipiOrdinati = [...types]..sort((a, b) {
                              const priorita = ['ZF01', 'SOST'];
                              final ia = priorita.indexOf(a.code);
                              final ib = priorita.indexOf(b.code);
                              if (ia == -1 && ib == -1) return 0;
                              if (ia == -1) return 1;
                              if (ib == -1) return -1;
                              return ia.compareTo(ib);
                            });
                          // Demo del 2026-09-28 (OdL da riduttore di pressione,
                          // ZA02): cliccabili solo SOST e ZA02, gli altri tipi
                          // restano visibili ma grigi per non sceglierli per
                          // sbaglio. Tutti i tipi, ZA02 compreso, arrivano dal
                          // backend (`wo-types`): nessuna voce aggiunta qui.
                          return MatchCodeField<String>(
                            label: 'Tipo OdL',
                            hint: 'Tocca per scegliere il tipo di ordine…',
                            value: _woType,
                            options: [
                              for (final t in tipiOrdinati)
                                MatchCodeOption(
                                  value: t.code,
                                  code: t.code,
                                  label: t.label,
                                  icon: _woTypeVisual(t).icon,
                                  color: _woTypeVisual(t).color,
                                ),
                            ],
                            isOptionEnabled: (o) =>
                                kTipiOdlAbilitati.contains(o.value),
                            onChanged: (code) => setState(() {
                              _woType = code;
                              // Cambiando tipo, il tipo attività scelto non
                              // vale più: si ricarica dalla tabella del tipo.
                              _template = null;
                              if (_descCtrl.text.isEmpty) {
                                final trovati =
                                    tipiOrdinati.where((x) => x.code == code);
                                if (trovati.isNotEmpty) {
                                  _descCtrl.text = trovati.first.label;
                                }
                              }
                            }),
                          );
                        },
                      ),
                  if (_woType == null)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('Seleziona un tipo per continuare',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textHint)),
                    ),
                  const SizedBox(height: 14),
                  _field(
                    controller: _descCtrl,
                    label: 'Descrizione intervento *',
                    hint: 'Es. Sostituzione contatore DN15',
                    validator: Validators.required,
                    maxLines: 2,
                    suffixIcon: VoiceSuffixIcons(controller: _descCtrl),
                  ),
                  // Tracciabilità: compare SOLO se l'OdL nasce da un altro OdL
                  // o da un avviso (valori precompilati dall'origine). In una
                  // creazione libera non ha senso e resta nascosta. Sola
                  // lettura: sono un riferimento, non si digitano a mano.
                  if (_hasTracciabilita) ...[
                    const SizedBox(height: 14),
                    Row(children: [
                      if (_ordinePrecedenteCtrl.text.trim().isNotEmpty)
                        Expanded(
                          child: _field(
                            controller: _ordinePrecedenteCtrl,
                            label: 'Ordine Precedente',
                            readOnly: true,
                          ),
                        ),
                      if (_ordinePrecedenteCtrl.text.trim().isNotEmpty &&
                          _notificaPrecedenteCtrl.text.trim().isNotEmpty)
                        const SizedBox(width: 12),
                      if (_notificaPrecedenteCtrl.text.trim().isNotEmpty)
                        Expanded(
                          child: _field(
                            controller: _notificaPrecedenteCtrl,
                            label: 'Notifica Precedente',
                            readOnly: true,
                          ),
                        ),
                    ]),
                  ],
                  // Tipo attività (dalla tabella di correlazione del cruscotto
                  // /anagrafica/wo-templates): sceglie il ciclo SAP e quindi le
                  // operazioni vere. Compare solo se il tipo offre più di una
                  // scelta; con una sola riga il backend usa la predefinita.
                  if (_woType != null)
                    ref.watch(workOrderTemplatesProvider(_woType!)).maybeWhen(
                          data: (rows) {
                            if (rows.length < 2) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  DropdownButtonFormField<
                                      WorkOrderActivityTemplate>(
                                    // Nuovo tipo OdL = nuove righe: la tendina
                                    // riparte da zero, senza la scelta del tipo
                                    // precedente.
                                    key: ValueKey('tipo-attivita-$_woType'),
                                    initialValue:
                                        _template ?? _rigaDelCiclo(rows),
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                        labelText: 'Tipo attività'),
                                    items: rows
                                        .map((t) => DropdownMenuItem(
                                            value: t,
                                            child: Text(t.labelIn(rows),
                                                overflow:
                                                    TextOverflow.ellipsis)))
                                        .toList(),
                                    onChanged: (v) =>
                                        setState(() => _template = v),
                                  ),
                                  if ((_template ?? _defaultTemplate(rows))
                                          ?.cicloSettore
                                          .isNotEmpty ??
                                      false)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(
                                        'Ciclo/settore: ${(_template ?? _defaultTemplate(rows))!.cicloSettore}',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textHint),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                          orElse: () => const SizedBox.shrink(),
                        ),
                  const SizedBox(height: 14),
                  // Priorità dal catalogo reale del backend (/anagrafica/priorities):
                  // lo schema giusto per il tipo (SOST → ZS) lo sceglie il backend.
                  ref.watch(orderPrioritiesProvider(_woType ?? '')).when(
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
                                  value: c.code,
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
                      final parts = (_startTime.isEmpty ? '08:00' : _startTime)
                          .split(':');
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
                      text: _startTime.isEmpty ? 'Seleziona ora' : _startTime,
                      empty: _startTime.isEmpty,
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
                    child:
                        _field(controller: _numberCtrl, label: 'N°', hint: '1'),
                  ),
                ]),
                const SizedBox(height: 10),
                _field(
                    controller: _additionalCtrl,
                    label: 'Info aggiuntive',
                    hint: 'Scala, piano, interno…'),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: _field(
                        controller: _provinciaCtrl,
                        label: 'Provincia',
                        hint: 'Es. AN'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _field(
                        controller: _capCtrl,
                        label: 'CAP',
                        hint: 'Es. 60019',
                        keyboardType: TextInputType.number),
                  ),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: _field(
                      controller: _latitudeCtrl,
                      label: 'Latitudine GPS',
                      hint: 'Es. 43.615000',
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _field(
                      controller: _longitudeCtrl,
                      label: 'Longitudine GPS',
                      hint: 'Es. 13.519000',
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                    ),
                  ),
                ]),
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
                          controller: _nomeCtrl, label: 'Nome', hint: 'Mario')),
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

                  // const SizedBox(width: 10),
                  // Expanded(
                  //     child: _field(
                  //         controller: _codBpCtrl,
                  //         label: 'Cod. BP SAP',
                  //         hint: '90012345')),
                ]),
              ]),
            ),
            const SizedBox(height: 12),

            // ── Assegnazione ─────────────────────────────────────────────────
            _SectionCard(
              title: 'Assegnazione',
              icon: Icons.assignment_ind_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AssegnatarioField(
                    value: _assegnaA,
                    onChanged: (cid) => setState(() => _assegnaA = cid),
                  ),
                  if (_assegnaA != null)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        'L\'OdL passa al collega appena viene inviato al '
                        'cruscotto: da quel momento non sarà più su questo tablet.',
                        style:
                            TextStyle(fontSize: 12, color: AppColors.textHint),
                      ),
                    ),
                ],
              ),
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
                suffixIcon: VoiceSuffixIcons(controller: _noteCtrl),
              ),
            ),
            const SizedBox(height: 15),

            // ── Bouton Crea ──────────────────────────────────────────────────
            ElevatedButton.icon(
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.add_circle_outline_rounded, size: 20),
              label: Text(
                  _saving ? 'Creazione in corso…' : 'Crea Ordine di Lavoro'),
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
    // Il backend marca alcuni campi come obbligatori (es. matricola per la
    // SOST): vanno validati QUI, altrimenti si crea un OdL che il backend
    // rifiuterà sempre (422) e che non si sincronizza mai. L'etichetta porta
    // il "*" quando serve.
    final label = f.required ? '${f.label} *' : f.label;
    if (f.type == DynFieldType.select) {
      return DropdownButtonFormField<String>(
        initialValue: _dynSel[f.key],
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
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
        validator: f.required
            ? (v) => (v == null || v.isEmpty) ? 'Campo obbligatorio' : null
            : null,
        onChanged: (v) => setState(() => _dynSel[f.key] = v ?? ''),
      );
    }
    return _field(
      controller: _dynCtrl(f.key),
      label: label,
      validator: f.required ? Validators.required : null,
      maxLines: f.type == DynFieldType.multiline ? 3 : 1,
      // La matricola del contatore è il suo numero di serie: leggibile col
      // barcode/QR stampato sull'apparecchio, come già in Gestione contatore.
      suffixIcon: f.key == 'matricola'
          ? IconButton(
              icon: const Icon(Icons.qr_code_scanner),
              tooltip: 'Scansiona matricola',
              onPressed: () async {
                final code = await context.push<String>(AppRoutes.scanner);
                if (code != null && code.isNotEmpty) {
                  setState(() => _dynCtrl(f.key).text = code);
                }
              },
            )
          // I campi di testo libero (es. "Lavoro da eseguire") si possono dettare.
          : (f.type == DynFieldType.multiline
              ? VoiceSuffixIcons(controller: _dynCtrl(f.key))
              : null),
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
    bool readOnly = false,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      readOnly: readOnly,
      decoration: InputDecoration(
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
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  static String _coordinateText(double? value) =>
      value == null ? '' : value.toStringAsFixed(6);

  static double? _parseCoordinate(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.'));

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
