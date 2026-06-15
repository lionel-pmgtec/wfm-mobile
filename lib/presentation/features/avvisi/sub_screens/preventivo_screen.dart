// Modulo Preventivo — gestione completa del devis di un Avviso di Servizio.
//
// Persistenza: tramite AvvisoExtension (Hive).
// Materiali: catalogo SAP (MaterialItem) tramite materialSearchProvider.
// Flusso : bozza → inviato → firmato → pagato → chiuso.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../domain/entities/entities.dart';
import '../../../providers/anagrafica_provider.dart';
import '../../../providers/avviso_extension_provider.dart';

class PreventivoScreen extends ConsumerStatefulWidget {
  final String numeroAvviso;
  const PreventivoScreen({super.key, required this.numeroAvviso});

  @override
  ConsumerState<PreventivoScreen> createState() => _PreventivoScreenState();
}

class _PreventivoScreenState extends ConsumerState<PreventivoScreen> {
  late final TextEditingController _motivoCtrl;
  late final TextEditingController _classFiscCtrl;
  late final TextEditingController _settoreCtrl;
  late final TextEditingController _ordineSdCtrl;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _motivoCtrl = TextEditingController();
    _classFiscCtrl = TextEditingController();
    _settoreCtrl = TextEditingController();
    _ordineSdCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _motivoCtrl.dispose();
    _classFiscCtrl.dispose();
    _settoreCtrl.dispose();
    _ordineSdCtrl.dispose();
    super.dispose();
  }

  void _hydrate(Preventivo? p) {
    if (_initialized) return;
    _initialized = true;
    if (p == null) return;
    _motivoCtrl.text = p.motivo;
    _classFiscCtrl.text = p.classificazioneFiscale;
    _settoreCtrl.text = p.settoreMerceologico;
    _ordineSdCtrl.text = p.numeroOrdineSd;
  }

  Preventivo _ensurePreventivo() {
    final ext = ref.read(avvisoExtensionProvider(widget.numeroAvviso));
    return ext.preventivo ?? Preventivo.bozza(widget.numeroAvviso);
  }

  Future<void> _persistHeader() async {
    final p = _ensurePreventivo().copyWith(
      motivo: _motivoCtrl.text.trim(),
      classificazioneFiscale: _classFiscCtrl.text.trim(),
      settoreMerceologico: _settoreCtrl.text.trim(),
      numeroOrdineSd: _ordineSdCtrl.text.trim(),
    );
    await ref
        .read(avvisoExtensionProvider(widget.numeroAvviso).notifier)
        .setPreventivo(p);
  }

  Future<void> _addMateriale() async {
    final res = await showModalBottomSheet<List<PreventivoMateriale>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AggiungiMaterialeSheet(),
    );
    if (res == null || res.isEmpty) return;
    await _persistHeader();
    final p = _ensurePreventivo();
    final updated = p.copyWith(materiali: [...p.materiali, ...res]);
    await ref
        .read(avvisoExtensionProvider(widget.numeroAvviso).notifier)
        .setPreventivo(updated);
    if (mounted) {
      showSapToast(
          context,
          res.length == 1
              ? '1 materiale aggiunto'
              : '${res.length} materiali aggiunti');
    }
  }

  Future<void> _removeMateriale(int index) async {
    final p = _ensurePreventivo();
    final updated = [...p.materiali]..removeAt(index);
    await ref
        .read(avvisoExtensionProvider(widget.numeroAvviso).notifier)
        .setPreventivo(p.copyWith(materiali: updated));
  }

  Future<void> _markInviato() async {
    await _persistHeader();
    final p = _ensurePreventivo();
    final updated = p.copyWith(
      stato: PreventivoStato.inviato,
      dataInvio: DateTime.now(),
    );
    await ref
        .read(avvisoExtensionProvider(widget.numeroAvviso).notifier)
        .setPreventivo(updated);
    if (mounted) showSapToast(context, 'Preventivo contrassegnato come inviato');
  }

  Future<void> _markPagato() async {
    final p = _ensurePreventivo();
    final updated = p.copyWith(
      stato: PreventivoStato.pagato,
      dataPagamento: DateTime.now(),
    );
    await ref
        .read(avvisoExtensionProvider(widget.numeroAvviso).notifier)
        .setPreventivo(updated);
    if (mounted) showSapToast(context, 'Pagamento registrato');
  }

  Future<void> _firma() async {
    await _persistHeader();
    final ok = await context.push<bool>(
      AppRoutes.preventivoFirmaPath(widget.numeroAvviso),
    );
    if (ok == true && mounted) {
      showSapToast(context, 'Firma cliente acquisita');
    }
  }

  Future<void> _generaPdf() async {
    await _persistHeader();
    await context.push(AppRoutes.preventivoPdfPath(widget.numeroAvviso));
  }

  @override
  Widget build(BuildContext context) {
    final ext = ref.watch(avvisoExtensionProvider(widget.numeroAvviso));
    final p = ext.preventivo;
    _hydrate(p);

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Preventivo'),
        actions: [
          if (p != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: p.stato.color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(p.stato.icon, size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(p.stato.label,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: kPagePadding,
        children: [
          if (p?.firma != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.statusDoneBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                const Icon(Icons.draw_outlined, color: AppColors.accentGreen),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Firmato da ${p!.firma!.nomeFirmatario}',
                          style: AppTextStyles.headingSmall),
                      Text(
                          '${p.firma!.dataFormattata} alle ${p.firma!.oraFormattata}',
                          style: AppTextStyles.bodySmall),
                    ],
                  ),
                ),
              ]),
            ),
          const SectionHeader(title: 'INTESTAZIONE'),
          TextField(
            controller: _motivoCtrl,
            maxLines: 2,
            decoration:
                const InputDecoration(labelText: 'Motivo dell\'ordine'),
            onChanged: (_) => _persistHeader(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _classFiscCtrl,
            decoration: const InputDecoration(
                labelText: 'Classificazione fiscale cliente'),
            onChanged: (_) => _persistHeader(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _settoreCtrl,
            decoration:
                const InputDecoration(labelText: 'Settore merceologico'),
            onChanged: (_) => _persistHeader(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ordineSdCtrl,
            decoration:
                const InputDecoration(labelText: 'Numero ordine SD'),
            onChanged: (_) => _persistHeader(),
          ),
          SectionHeader(
            title: 'MATERIALI',
            trailing: Text(
              '${p?.materiali.length ?? 0}',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary),
            ),
          ),
          if (p == null || p.materiali.isEmpty)
            // Empty state cliccabile : tap per aprire la selezione multipla.
            InkWell(
              onTap: _addMateriale,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      style: BorderStyle.solid,
                      width: 1.5),
                ),
                child: Column(
                  children: [
                    Icon(Icons.inventory_2_outlined,
                        size: 32,
                        color: AppColors.primary.withValues(alpha: 0.7)),
                    const SizedBox(height: 8),
                    const Text('Nessun materiale aggiunto',
                        style: AppTextStyles.headingSmall),
                    const SizedBox(height: 4),
                    const Text(
                        'Tocca per scegliere uno o più materiali dal catalogo SAP',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
            )
          else
            ...List.generate(p.materiali.length, (i) {
              final m = p.materiali[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: WfmCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    const Icon(Icons.inventory_2_outlined,
                        color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.descrizione,
                              style: AppTextStyles.headingSmall),
                          const SizedBox(height: 2),
                          Text(
                              '${m.codice} · ${m.quantita} ${m.unitaMisura} × €${m.prezzoUnitario.toStringAsFixed(2)}',
                              style: AppTextStyles.bodySmall),
                        ],
                      ),
                    ),
                    Text('€ ${m.totale.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary)),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: p.stato.isFinal ? null : () => _removeMateriale(i),
                    ),
                  ]),
                ),
              );
            }),
          const SizedBox(height: 8),
          if (p == null || !p.stato.isFinal)
            ElevatedButton.icon(
              onPressed: _addMateriale,
              icon: const Icon(Icons.checklist_rounded),
              label: Text(p == null || p.materiali.isEmpty
                  ? 'Seleziona materiali dal catalogo'
                  : 'Aggiungi altri materiali'),
            ),
          const SectionHeader(title: 'TOTALI'),
          _TotaleBox(preventivo: p ?? Preventivo.bozza(widget.numeroAvviso)),
          const SectionHeader(title: 'AZIONI'),
          _ActionButtons(
            preventivo: p,
            onFirma: _firma,
            onPdf: _generaPdf,
            onMarkInviato: _markInviato,
            onMarkPagato: _markPagato,
          ),
          const SizedBox(height: 90),
        ],
      ),
    );
  }
}

class _TotaleBox extends StatelessWidget {
  final Preventivo preventivo;
  const _TotaleBox({required this.preventivo});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(children: [
            const Expanded(
                child: Text('Imponibile', style: AppTextStyles.bodyMedium)),
            Text('€ ${preventivo.totaleSenzaIva.toStringAsFixed(2)}',
                style: AppTextStyles.bodyLarge
                    .copyWith(fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Expanded(
                child: Text(
                    'IVA ${preventivo.aliquotaIva.toStringAsFixed(0)}%',
                    style: AppTextStyles.bodyMedium)),
            Text('€ ${preventivo.importoIva.toStringAsFixed(2)}',
                style: AppTextStyles.bodyLarge
                    .copyWith(fontWeight: FontWeight.w600)),
          ]),
          const Divider(height: 16),
          Row(children: [
            const Expanded(
              child: Text('TOTALE',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      letterSpacing: 0.5)),
            ),
            Text('€ ${preventivo.totaleConIva.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary)),
          ]),
        ],
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final Preventivo? preventivo;
  final VoidCallback onFirma;
  final VoidCallback onPdf;
  final VoidCallback onMarkInviato;
  final VoidCallback onMarkPagato;

  const _ActionButtons({
    required this.preventivo,
    required this.onFirma,
    required this.onPdf,
    required this.onMarkInviato,
    required this.onMarkPagato,
  });

  @override
  Widget build(BuildContext context) {
    final p = preventivo;
    final canFirma = p != null && p.hasMateriali && !p.stato.isFinal;
    final canPdf = p != null && p.hasMateriali;
    final canInviato = p != null &&
        p.hasMateriali &&
        p.stato == PreventivoStato.bozza;
    final canPagato = p != null &&
        (p.stato == PreventivoStato.firmato ||
            p.stato == PreventivoStato.inviato);
    return Column(
      children: [
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: canFirma ? onFirma : null,
              icon: const Icon(Icons.draw_outlined),
              label: const Text('Firma'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: canPdf ? onPdf : null,
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('PDF'),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: canInviato ? onMarkInviato : null,
              icon: const Icon(Icons.send_outlined),
              label: const Text('Marca inviato'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: canPagato ? onMarkPagato : null,
              icon: const Icon(Icons.payments_outlined),
              label: const Text('Registra pagamento'),
            ),
          ),
        ]),
      ],
    );
  }
}

/// Riga selezionabile nel bottom sheet multi-select.
class _CartLine {
  final MaterialItem material;
  num quantita;
  num prezzoUnitario;
  String classificazione;
  final TextEditingController qtaCtrl;
  final TextEditingController prezzoCtrl;

  _CartLine({required this.material})
      : quantita = 1,
        prezzoUnitario = 0,
        classificazione = '-NONE-',
        qtaCtrl = TextEditingController(text: '1'),
        prezzoCtrl = TextEditingController(text: '0,00');

  num get totale => quantita * prezzoUnitario;

  void dispose() {
    qtaCtrl.dispose();
    prezzoCtrl.dispose();
  }
}

class _AggiungiMaterialeSheet extends ConsumerStatefulWidget {
  @override
  ConsumerState<_AggiungiMaterialeSheet> createState() =>
      _AggiungiMaterialeSheetState();
}

class _AggiungiMaterialeSheetState
    extends ConsumerState<_AggiungiMaterialeSheet> {
  String _query = '';
  // Materiali selezionati indicizzati per codice — preserva l'ordine d'aggiunta.
  final Map<String, _CartLine> _cart = {};

  @override
  void dispose() {
    for (final line in _cart.values) {
      line.dispose();
    }
    super.dispose();
  }

  void _toggle(MaterialItem m) {
    setState(() {
      if (_cart.containsKey(m.materialCode)) {
        _cart[m.materialCode]!.dispose();
        _cart.remove(m.materialCode);
      } else {
        _cart[m.materialCode] = _CartLine(material: m);
      }
    });
  }

  void _setQta(String code, String v) {
    final n = num.tryParse(v.replaceAll(',', '.')) ?? 0;
    setState(() => _cart[code]!.quantita = n);
  }

  void _setPrezzo(String code, String v) {
    final n = num.tryParse(v.replaceAll(',', '.')) ?? 0;
    setState(() => _cart[code]!.prezzoUnitario = n);
  }

  void _confirm() {
    if (_cart.isEmpty) {
      showSapToast(context, 'Seleziona almeno un materiale',
          isError: true);
      return;
    }
    final invalid = _cart.values.where((l) => l.quantita <= 0).toList();
    if (invalid.isNotEmpty) {
      showSapToast(
          context,
          'Quantità non valida per ${invalid.length} materiali',
          isError: true);
      return;
    }
    final result = _cart.values
        .map((l) => PreventivoMateriale(
              codice: l.material.materialCode,
              descrizione: l.material.description,
              quantita: l.quantita,
              unitaMisura: l.material.unitOfMeasure,
              prezzoUnitario: l.prezzoUnitario,
              classificazione: l.classificazione,
            ))
        .toList();
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    // LayoutBuilder cattura le constraints reali del bottom sheet
    // (importante su Flutter Web dove le constraints sono a volte ambigue).
    return LayoutBuilder(builder: (context, constraints) {
      final search = ref.watch(materialSearchProvider(_query));
      final totale =
          _cart.values.fold<num>(0, (acc, l) => acc + l.totale);
      final media = MediaQuery.of(context);
      final width = constraints.maxWidth.isFinite
          ? constraints.maxWidth
          : media.size.width;
      final height = media.size.height * 0.9;

      return SizedBox(
        width: width,
        height: height,
        child: Material(
          color: AppColors.backgroundPage,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ───────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Aggiungi materiali al preventivo',
                        style: AppTextStyles.headingMedium),
                    const SizedBox(height: 4),
                    const Text(
                        'Seleziona uno o più materiali dal catalogo SAP. '
                        'Imposta quantità e prezzo per ognuno.',
                        style: AppTextStyles.bodySmall),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Cerca per codice o descrizione',
                        prefixIcon: Icon(Icons.search),
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ],
                ),
              ),
              // ── Tab bar + contenuto ─────────────────────────────────
              Expanded(
                child: DefaultTabController(
                  length: 2,
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      TabBar(
                        labelColor: AppColors.primary,
                        unselectedLabelColor: AppColors.textSecondary,
                        indicatorColor: AppColors.primary,
                        tabs: [
                          const Tab(text: 'Catalogo SAP'),
                          Tab(text: 'Selezionati (${_cart.length})'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _CataloghoList(
                              search: search,
                              isSelected: (m) =>
                                  _cart.containsKey(m.materialCode),
                              onToggle: _toggle,
                            ),
                            _SelezionatiList(
                              cart: _cart,
                              onRemove: (code) =>
                                  _toggle(_cart[code]!.material),
                              onSetQta: _setQta,
                              onSetPrezzo: _setPrezzo,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // ── Footer (verticale, niente Row+Flex) ─────────────────
              SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    media.viewInsets.bottom + 12,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Riepilogo totale (text only, no flex)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppColors.primary
                                  .withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                _cart.isEmpty
                                    ? 'Nessuna selezione'
                                    : '${_cart.length} ${_cart.length == 1 ? "materiale" : "materiali"}',
                                style: AppTextStyles.bodySmall),
                            Text('Totale: € ${totale.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Bottone larghezza piena (stretch del Column)
                      ElevatedButton.icon(
                        onPressed: _cart.isEmpty ? null : _confirm,
                        icon: const Icon(Icons.check_rounded),
                        label: Text(_cart.isEmpty
                            ? 'Seleziona materiali'
                            : 'Aggiungi ${_cart.length} al preventivo'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

class _CataloghoList extends StatelessWidget {
  final AsyncValue<List<MaterialItem>> search;
  final bool Function(MaterialItem) isSelected;
  final void Function(MaterialItem) onToggle;

  const _CataloghoList({
    required this.search,
    required this.isSelected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return search.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) =>
          const Center(child: Text('Errore caricamento catalogo')),
      data: (list) => list.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('Nessun risultato',
                    style: AppTextStyles.bodySmall),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: list.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final m = list[i];
                final sel = isSelected(m);
                return CheckboxListTile(
                  value: sel,
                  onChanged: (_) => onToggle(m),
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: AppColors.primary,
                  title: Text(m.description,
                      style: AppTextStyles.bodyMedium
                          .copyWith(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                      '${m.materialCode} · ${m.unitOfMeasure}',
                      style: AppTextStyles.bodySmall),
                  secondary: sel
                      ? const Icon(Icons.check_circle,
                          color: AppColors.primary)
                      : const Icon(Icons.inventory_2_outlined,
                          color: AppColors.textHint),
                );
              },
            ),
    );
  }
}

class _SelezionatiList extends StatelessWidget {
  final Map<String, _CartLine> cart;
  final void Function(String code) onRemove;
  final void Function(String code, String v) onSetQta;
  final void Function(String code, String v) onSetPrezzo;

  const _SelezionatiList({
    required this.cart,
    required this.onRemove,
    required this.onSetQta,
    required this.onSetPrezzo,
  });

  @override
  Widget build(BuildContext context) {
    if (cart.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
              'Nessun materiale selezionato.\nVai su "Catalogo SAP" per scegliere.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall),
        ),
      );
    }
    final lines = cart.values.toList();
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: lines.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final l = lines[i];
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.inventory_2_outlined,
                    color: AppColors.primary, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.material.description,
                          style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text(
                          '${l.material.materialCode} · ${l.material.unitOfMeasure}',
                          style: AppTextStyles.bodySmall),
                    ],
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () => onRemove(l.material.materialCode),
                ),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: l.qtaCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Qtà', isDense: true),
                    onChanged: (v) => onSetQta(l.material.materialCode, v),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: l.prezzoCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Prezzo un.',
                        suffixText: '€',
                        isDense: true),
                    onChanged: (v) =>
                        onSetPrezzo(l.material.materialCode, v),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('€ ${l.totale.toStringAsFixed(2)}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary)),
                  ),
                ),
              ]),
            ],
          ),
        );
      },
    );
  }
}
