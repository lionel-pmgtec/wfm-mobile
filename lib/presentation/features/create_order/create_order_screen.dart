// Création OdL depuis le terrain (M10) — formulaire moderne multi-sections.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';
import '../../providers/auth_provider.dart';
import '../../providers/work_orders_provider.dart';

// ─── Types d'ODL disponibles ─────────────────────────────────────────────────

const _woTypes = [
  _WoTypeOption('ATTI', 'Apertura contatore', Icons.lock_open_rounded, Color(0xFF1565C0)),
  _WoTypeOption('SOST', 'Sostituzione contatore', Icons.swap_horiz_rounded, Color(0xFF6A1B9A)),
  _WoTypeOption('ZA02', 'Riparazione perdita', Icons.build_rounded, Color(0xFFE65100)),
  _WoTypeOption('DISA', 'Disattivazione fornitura', Icons.block_rounded, Color(0xFFC62828)),
  _WoTypeOption('PA', 'Preventivo allaccio', Icons.description_outlined, Color(0xFF2E7D32)),
];

class _WoTypeOption {
  final String code;
  final String label;
  final IconData icon;
  final Color color;
  const _WoTypeOption(this.code, this.label, this.icon, this.color);
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

  @override
  void dispose() {
    for (final c in [
      _descCtrl, _cityCtrl, _streetCtrl, _numberCtrl,
      _additionalCtrl, _sedeCtrl, _nomeCtrl, _cognomeCtrl,
      _telefonoCtrl, _codBpCtrl, _noteCtrl,
    ]) {
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
    final cid = ref.read(authControllerProvider.notifier).user?.cid ?? '';
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
    final order = WorkOrder(
      externalCode: '',
      woType: _woType!,
      woTypeDescription: _descCtrl.text.trim(),
      tam: _woType!,
      status: WorkOrderStatus.ricevuto,
      priorita: 'Media',
      creatoDa: 'wfm.mobile',
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
      notes: _noteCtrl.text.trim(),
      accountingSector: 'POT - Servizio acqua potabile',
      cidAssegnato: cid,
      createdAt: now,
      localStatus: LocalSyncStatus.pendingUpload,
    );
    final res = await ref.read(workOrderActionsProvider).create(order);
    if (!mounted) return;
    setState(() => _saving = false);
    res.when(
      success: (wo) {
        showSapToast(context, 'OdL ${wo.externalCode} creato con successo');
        // Vai direttamente al dettaglio dell'OdL appena creato (no ritorno
        // alla lista). context.go sostituisce lo stack quindi il back porta
        // alla schermata precedente al wizard.
        context.go(AppRoutes.workOrderDetailPath(wo.externalCode));
      },
      failure: (f) => showSapToast(context, f.message, isError: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPage,
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Nuovo Ordine di Lavoro'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
            )
          else
            TextButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
              label: const Text('Crea',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
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
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.05,
                    children: _woTypes.map((t) {
                      final sel = _woType == t.code;
                      return GestureDetector(
                        onTap: () => setState(() {
                          _woType = t.code;
                          if (_descCtrl.text.isEmpty) _descCtrl.text = t.label;
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          decoration: BoxDecoration(
                            color: sel
                                ? t.color.withValues(alpha: 0.1)
                                : AppColors.backgroundPage,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: sel ? t.color : AppColors.border,
                              width: sel ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(t.icon,
                                  color: sel ? t.color : AppColors.textHint,
                                  size: 24),
                              const SizedBox(height: 4),
                              Text(t.code,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: sel ? t.color : AppColors.textSecondary,
                                  )),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Text(t.label,
                                    style: const TextStyle(
                                        fontSize: 9, color: AppColors.textHint),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
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
                ],
              ),
            ),
            const SizedBox(height: 12),

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
            const SizedBox(height: 12),

            // ── Banner offline ───────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.statusInProgressBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.accentOrange.withValues(alpha: 0.3)),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline, size: 18, color: AppColors.accentOrange),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'L\'OdL sarà inviato a SAP (flusso I4) o accodato se offline.',
                    style: TextStyle(fontSize: 12, color: AppColors.accentOrange),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 20),

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
