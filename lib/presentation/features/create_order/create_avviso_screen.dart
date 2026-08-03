// Creazione Avviso dal campo (local-first).
//
// L'avviso creato resta SUL TABLET (id provvisorio "TMP-…") finché l'operatore
// non lo sincronizza verso il cruscotto. Nessun valore hardcoded: tipo e
// priorità arrivano dal cruscotto (lookup); se il cruscotto non li serve ancora,
// il campo diventa un testo libero così la creazione resta comunque possibile.

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

class CreateAvvisoScreen extends ConsumerStatefulWidget {
  const CreateAvvisoScreen({super.key});

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
  final _nomeCtrl = TextEditingController();
  final _cognomeCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [
      _tipoCtrl, _prioritaCtrl, _descCtrl, _cityCtrl, _streetCtrl,
      _numberCtrl, _additionalCtrl, _nomeCtrl, _cognomeCtrl,
      _telefonoCtrl, _noteCtrl,
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
      ),
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
    context.pushReplacement(AppRoutes.avvisoDetailPath(code));
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
            _SectionCard(
              title: 'Tipo e descrizione',
              icon: Icons.report_gmailerrorred_outlined,
              child: Column(children: [
                _pickerOrText('Tipo avviso *', 'avviso-types', _tipoCtrl),
                const SizedBox(height: 10),
                _pickerOrText('Priorità', 'avviso-priorities', _prioritaCtrl),
                const SizedBox(height: 10),
                _field(
                    controller: _descCtrl,
                    label: 'Descrizione *',
                    hint: 'Es. Perdita in strada all\'altezza del civico 10',
                    validator: Validators.required,
                    maxLines: 2),
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
                  maxLines: 3),
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

  /// Dropdown se il cruscotto serve il catalogo `kind`, altrimenti campo testo
  /// (così la creazione è possibile anche prima che il cruscotto lo esponga).
  Widget _pickerOrText(String label, String kind, TextEditingController ctrl) {
    final async = ref.watch(lookupProvider(kind));
    return async.maybeWhen(
      data: (items) {
        if (items.isEmpty) return _field(controller: ctrl, label: label);
        final v = items.any((e) => e.code == ctrl.text) ? ctrl.text : null;
        return DropdownButtonFormField<String>(
          initialValue: v,
          isExpanded: true,
          decoration: _decoration(label),
          items: items
              .map((e) => DropdownMenuItem(
                    value: e.code,
                    child: Text('${e.code} — ${e.label}',
                        overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: (val) => setState(() => ctrl.text = val ?? ''),
        );
      },
      orElse: () => _field(controller: ctrl, label: label),
    );
  }

  InputDecoration _decoration(String label, {String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
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
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: _decoration(label, hint: hint),
    );
  }
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
