// Creazione Avviso dal campo (local-first).
//
// L'avviso creato resta SUL TABLET (id provvisorio "TMP-…") finché l'operatore
// non lo sincronizza verso il cruscotto. Tipo dal lookup del cruscotto (più
// IS/ZI della demo, vedi kAvvisiDemo); priorità dallo schema del tipo
// (`/anagrafica/priorities?type=`), testo libero se lo schema non c'è.

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

/// Tipi avviso della demo, con l'etichetta del backend (`tipiOrdine.ts`:
/// "IS (interruzione di servizio) e ZI (Investimento H2O)"). Il backend li
/// accetta in `POST /notifications` ma non li serve ancora nel lookup
/// `avviso-types` del tablet (dato di `data/anagrafiche.json`).
const kAvvisiDemo = {
  'IS': 'Interruzione di servizio',
  'ZI': 'Investimento H2O',
};

class CreateAvvisoScreen extends ConsumerStatefulWidget {
  /// Prefill da un punto della rete (mappa ArcGIS): matricola del contatore
  /// (se il livello la porta) e posizione, che va sull'indirizzo dell'avviso.
  final String? matricola;
  final double? latitudine;
  final double? longitudine;

  /// Indirizzo del punto scelto sulla mappa (geocodifica inversa Esri).
  final IndirizzoMappa? indirizzo;

  const CreateAvvisoScreen(
      {super.key,
      this.matricola,
      this.latitudine,
      this.longitudine,
      this.indirizzo});

  @override
  ConsumerState<CreateAvvisoScreen> createState() => _CreateAvvisoScreenState();
}

class _CreateAvvisoScreenState extends ConsumerState<CreateAvvisoScreen> {
  final _formKey = GlobalKey<FormState>();

  final _tipoCtrl = TextEditingController();
  final _prioritaCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _streetCtrl = TextEditingController();
  final _numberCtrl = TextEditingController();
  final _additionalCtrl = TextEditingController();
  final _latitudeCtrl = TextEditingController();
  final _longitudeCtrl = TextEditingController();
  final _nomeCtrl = TextEditingController();
  final _cognomeCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _latitudeCtrl.text = _coordinateText(widget.latitudine);
    _longitudeCtrl.text = _coordinateText(widget.longitudine);
    final ind = widget.indirizzo;
    if (ind != null) {
      _streetCtrl.text = ind.via;
      _numberCtrl.text = ind.civico;
      _cityCtrl.text = ind.comune;
    }
  }

  @override
  void dispose() {
    for (final c in [
      _tipoCtrl, _prioritaCtrl, _descCtrl, _cityCtrl, _streetCtrl,
      _numberCtrl, _additionalCtrl, _nomeCtrl, _cognomeCtrl,
      _latitudeCtrl, _longitudeCtrl, _telefonoCtrl, _noteCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_tipoCtrl.text.trim().isEmpty) {
      showSapToast(context, 'Indica il tipo avviso', isError: true);
      return;
    }
    setState(() => _saving = true);
    final utente = ref.read(authControllerProvider.notifier).user;
    final cid = utente?.cid ?? '';
    final creatore =
        utente == null ? 'wfm.mobile' : '${utente.fullName} ($cid)';
    final now = DateTime.now();
    final code = ref.read(creationControllerProvider).newAvvisoId();
    final avviso = NotificationAvviso(
      numeroAvviso: code,
      descrizione: _descCtrl.text.trim(),
      tipo: _tipoCtrl.text.trim(),
      priorita: _prioritaCtrl.text.trim(),
      stato: 'Creato',
      cid: cid,
      cidAssegnato: cid,
      creatoDa: creatore,
      address: Address(
        city: _cityCtrl.text.trim(),
        street: _streetCtrl.text.trim(),
        streetNumber: _numberCtrl.text.trim(),
        additionalInfo: _additionalCtrl.text.trim(),
        cap: widget.indirizzo?.cap ?? '',
        latitude: _parseCoordinate(_latitudeCtrl.text),
        longitude: _parseCoordinate(_longitudeCtrl.text),
      ),
      matricola: (widget.matricola ?? '').trim().isEmpty
          ? null
          : widget.matricola!.trim(),
      customer: Customer(
        nome: _nomeCtrl.text.trim(),
        cognome: _cognomeCtrl.text.trim(),
        telefono: _telefonoCtrl.text.trim(),
      ),
      referente: '${_nomeCtrl.text.trim()} ${_cognomeCtrl.text.trim()}'.trim(),
      cellulare: _telefonoCtrl.text.trim(),
      noteOperatore: _noteCtrl.text.trim(),
      dataApertura: now,
      localStatus: LocalSyncStatus.pendingUpload,
    );
    await ref.read(creationControllerProvider).addAvviso(avviso);
    if (!mounted) return;
    setState(() => _saving = false);

    // Conferma con invio proposto subito, senza tornare alla Home.
    await showCreatedSyncDialog(
      context,
      ref,
      title: 'Avviso creato',
      message: 'L\'avviso è salvato sul tablet. '
          'Vuoi inviarlo subito al cruscotto?',
    );
    if (!mounted) return;
    // Come per gli OdL: dopo la creazione si torna alla LISTA degli avvisi,
    // non al dettaglio. Il tasto Indietro non riporta più nel wizard.
    context.go(AppRoutes.avvisi);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPage,
      appBar: AppBar(
        title: const Text('Nuovo Avviso'),
        actions: [
          // Sincronizzazione raggiungibile anche durante la compilazione.
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20, height: 20,
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
            if (widget.latitudine != null || widget.matricola != null) ...[
              _DallaMappa(
                  matricola: widget.matricola,
                  conPosizione: widget.latitudine != null),
              const SizedBox(height: 12),
            ],
            _SectionCard(
              title: 'Tipo e descrizione',
              icon: Icons.report_gmailerrorred_outlined,
              child: Column(children: [
                _tipoAvvisoField(),
                const SizedBox(height: 10),
                _prioritaField(),
                const SizedBox(height: 10),
                _field(
                    controller: _descCtrl,
                    label: 'Descrizione *',
                    hint: 'Es. Perdita in strada all\'altezza del civico 10',
                    validator: Validators.required,
                    maxLines: 2,
                    suffixIcon: VoiceSuffixIcons(controller: _descCtrl)),
              ]),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Indirizzo',
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
                        label: 'Via',
                        hint: 'Es. VIA ROMA'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _field(
                        controller: _numberCtrl, label: 'N°', hint: '1'),
                  ),
                ]),
                const SizedBox(height: 10),
                _field(
                    controller: _additionalCtrl,
                    label: 'Info aggiuntive',
                    hint: 'Scala, piano, riferimento…'),
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
              ]),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Cliente (opzionale)',
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
                _field(
                    controller: _telefonoCtrl,
                    label: 'Telefono',
                    hint: '3401234567',
                    keyboardType: TextInputType.phone),
              ]),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Note',
              icon: Icons.notes_rounded,
              child: _field(
                  controller: _noteCtrl,
                  label: 'Note operatore',
                  hint: 'Informazioni aggiuntive…',
                  maxLines: 3,
                  suffixIcon: VoiceSuffixIcons(controller: _noteCtrl)),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.add_circle_outline_rounded, size: 20),
              label: Text(_saving ? 'Creazione in corso…' : 'Crea Avviso'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  /// Tipo avviso: match code. Demo del 2026-09-28: gli avvisi da creare sono
  /// IS e ZI, gli unici cliccabili; gli altri tipi (serviti dal cruscotto, es.
  /// ZH) restano visibili ma grigi.
  Widget _tipoAvvisoField() {
    final async = ref.watch(lookupProvider('avviso-types'));
    final items = async.valueOrNull ?? const <CodeLabel>[];
    final codiciServiti = items.map((e) => e.code).toSet();
    return MatchCodeField<String>(
      label: 'Tipo avviso',
      hint: 'Tocca per scegliere il tipo di avviso…',
      value: _tipoCtrl.text.isEmpty ? null : _tipoCtrl.text,
      options: [
        // IS e ZI non sono (ancora) nel lookup `avviso-types`: si mostrano con
        // l'etichetta del backend. Se il lookup li porta, vale la sua.
        for (final e in kAvvisiDemo.entries)
          if (!codiciServiti.contains(e.key))
            MatchCodeOption(value: e.key, code: e.key, label: e.value),
        for (final e in items)
          MatchCodeOption(value: e.code, code: e.code, label: e.label),
      ],
      isOptionEnabled: (o) => kAvvisiDemo.containsKey(o.value),
      onChanged: (code) => setState(() {
        if (_tipoCtrl.text != code) _prioritaCtrl.clear();
        _tipoCtrl.text = code;
      }),
    );
  }

  /// Priorità: il codice dello schema del TIPO avviso (IS: 1 Non programmata,
  /// 2 Programmata; ZI: 1/2/4/6…), da `GET /anagrafica/priorities?type=`. Lo
  /// stesso codice vale cose diverse in schemi diversi: senza tipo non si
  /// sceglie.
  Widget _prioritaField() {
    final tipo = _tipoCtrl.text.trim();
    if (tipo.isEmpty) {
      return TextFormField(
        enabled: false,
        decoration: _decoration('Priorità',
            hint: 'Scegli prima il tipo avviso'),
      );
    }
    return ref.watch(orderPrioritiesProvider(tipo)).when(
          loading: () => const LinearProgressIndicator(),
          // Schema non disponibile: resta possibile scriverla a mano.
          error: (_, __) => _field(controller: _prioritaCtrl, label: 'Priorità'),
          data: (list) {
            if (list.isEmpty) {
              return _field(controller: _prioritaCtrl, label: 'Priorità');
            }
            final v = list.any((e) => e.code == _prioritaCtrl.text)
                ? _prioritaCtrl.text
                : null;
            return DropdownButtonFormField<String>(
              key: ValueKey('priorita-$tipo'),
              initialValue: v,
              isExpanded: true,
              decoration: _decoration('Priorità'),
              items: list
                  .map((e) => DropdownMenuItem(
                        value: e.code,
                        child: Text('${e.code} — ${e.label}',
                            overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (val) => setState(() => _prioritaCtrl.text = val ?? ''),
            );
          },
        );
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: _decoration(label, hint: hint, suffixIcon: suffixIcon),
    );
  }

  static String _coordinateText(double? value) =>
      value == null ? '' : value.toStringAsFixed(6);

  static double? _parseCoordinate(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.'));
}

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

/// Promemoria di ciò che arriva dal punto della rete scelto sulla mappa.
class _DallaMappa extends StatelessWidget {
  final String? matricola;
  final bool conPosizione;
  const _DallaMappa({required this.matricola, required this.conPosizione});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        const Icon(Icons.map_outlined, color: AppColors.primary, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            [
              if ((matricola ?? '').isNotEmpty) 'Contatore $matricola',
              if (conPosizione) 'posizione presa dalla mappa',
            ].join(' · '),
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primary),
          ),
        ),
      ]),
    );
  }
}
