// Aggiungi componenti all'OdL.
//
// Selezione dei materiali e del magazzino:
//   • Elenco a tendina con caselle da spuntare: più materiali in una volta
//   • Per ogni materiale spuntato: i magazzini in cui è disponibile, con la
//     quantità rimanente di ciascuno; il tecnico sceglie da quale prelevare
//   • La giacenza è separata per magazzino: prelevare da un magazzino scala
//     solo quello (StockImpegnatoStore), mai gli altri
//   • Giacenze: `stockPerMagazzino` del backend se c'è; altrimenti lo stock
//     unico nel magazzino predefinito del materiale (anagrafiche.json)
//   • Pulsante "Aggiungi N all'OdL" che inserisce tutto in una volta

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/services/stock_impegnato_store.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../widgets/odl_actions_menu.dart';
import '../../../../domain/entities/entities.dart';
import '../../../providers/anagrafica_provider.dart';
import '../../../providers/odl_extension_provider.dart';
import '../../../providers/work_orders_provider.dart';

class AddComponenteScreen extends ConsumerStatefulWidget {
  final String code;
  const AddComponenteScreen({super.key, required this.code});

  @override
  ConsumerState<AddComponenteScreen> createState() =>
      _AddComponenteScreenState();
}

/// Riga del carrello : 1 materiale, il magazzino scelto e la quantita richiesta.
class _CartLine {
  final MaterialItem material;
  String magazzino;
  num quantita;
  final TextEditingController qtaCtrl;
  _CartLine({required this.material})
      : magazzino = _magazzinoIniziale(material),
        quantita = 1,
        qtaCtrl = TextEditingController(text: '1');

  /// Giacenza residua di un magazzino per questo materiale (backend meno i
  /// prelievi già fatti da QUEL magazzino).
  num residuoDi(String codice) => StockImpegnatoStore.residuo(
      material.giacenze[codice] ?? 0, material.materialCode, codice);

  /// Residuo del magazzino scelto, prima di questo prelievo.
  num get disponibile => residuoDi(magazzino);

  /// Quanto resterebbe nel magazzino scelto dopo il prelievo.
  num get disponibileResiduo =>
      (disponibile - quantita).clamp(0, double.infinity);

  bool get isOverstock => quantita > disponibile;

  /// Magazzino da proporre: quello predefinito se ha ancora materiale,
  /// altrimenti il primo che ne ha.
  static String _magazzinoIniziale(MaterialItem m) {
    num r(String c) => StockImpegnatoStore.residuo(
        m.giacenze[c] ?? 0, m.materialCode, c);
    if (r(m.defaultWarehouseCode) > 0) return m.defaultWarehouseCode;
    for (final c in m.giacenze.keys) {
      if (r(c) > 0) return c;
    }
    return m.defaultWarehouseCode;
  }

  void dispose() {
    qtaCtrl.dispose();
  }
}

class _AddComponenteScreenState extends ConsumerState<AddComponenteScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  // Carrello : materiale → riga (per preservare ordine d'aggiunta).
  final Map<String, _CartLine> _cart = {};
  bool _saving = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    for (final l in _cart.values) {
      l.dispose();
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

  void _setMagazzino(String code, String magazzino) =>
      setState(() => _cart[code]!.magazzino = magazzino);

  void _setQta(String code, String v) {
    final n = num.tryParse(v.replaceAll(',', '.')) ?? 0;
    setState(() => _cart[code]!.quantita = n);
  }

  String _fmtQta(num n) => n % 1 == 0 ? n.toInt().toString() : n.toString();

  /// Nome del magazzino dall'anagrafica (`/anagrafica/warehouses`); il codice
  /// finché non è caricata.
  String _nomeMagazzino(String codice) {
    final lista = ref.read(warehousesProvider).valueOrNull ?? const [];
    for (final w in lista) {
      if (w.code == codice) return w.name.isEmpty ? codice : w.name;
    }
    return codice;
  }

  void _incrementQta(String code) {
    final line = _cart[code];
    if (line == null) return;
    final n = line.quantita + 1;
    line.quantita = n;
    line.qtaCtrl.text = _fmtQta(n);
    setState(() {});
  }

  void _decrementQta(String code) {
    final line = _cart[code];
    if (line == null) return;
    final n = line.quantita - 1 < 1 ? 1 : line.quantita - 1; // minimo 1
    line.quantita = n;
    line.qtaCtrl.text = _fmtQta(n);
    setState(() {});
  }

  Future<void> _scanBarcode() async {
    final scanned = await context.push<String>(AppRoutes.scanner);
    if (scanned != null && scanned.isNotEmpty) {
      _searchCtrl.text = scanned;
      setState(() => _query = scanned);
    }
  }

  Future<void> _confirm() async {
    if (_cart.isEmpty) {
      showSapToast(context, 'Seleziona almeno un materiale', isError: true);
      return;
    }
    final invalid = _cart.values.where((l) => l.quantita <= 0).toList();
    if (invalid.isNotEmpty) {
      showSapToast(context, 'Quantita non valida per alcuni materiali',
          isError: true);
      return;
    }
    // Stock insufficiente: impegno non consentito. Non è un avviso da
    // ignorare, il materiale in magazzino non c'è.
    final overstock = _cart.values.where((l) => l.isOverstock).toList();
    if (overstock.isNotEmpty) {
      final elenco = overstock
          .map((l) =>
              '• ${l.material.description} (${_nomeMagazzino(l.magazzino)}): '
              'richiesti ${_fmtQta(l.quantita)}, '
              'disponibili ${_fmtQta(l.disponibile)}')
          .join('\n');
      await showWfmInfoDialog(
        context: context,
        title: 'Stock insufficiente',
        message: 'Non è possibile prelevare più di quanto disponibile nel '
            'magazzino scelto:\n\n$elenco',
        confirmLabel: 'Ho capito',
        tone: WfmDialogTone.danger,
        icon: Icons.block_rounded,
      );
      return;
    }

    setState(() => _saving = true);

    // I materiali restano sul tablet: il cruscotto li accetta solo con
    // l'esito, non con un aggiornamento dell'ordine. Vengono aggiunti a
    // quelli già impegnati per questo OdL.
    final nuovi = _cart.values
        .map((l) => MaterialUsage(
              materialCode: l.material.materialCode,
              description: l.material.description,
              plannedQuantity: l.quantita,
              usedQuantity: l.quantita,
              unitOfMeasure: l.material.unitOfMeasure,
              warehouseCode: l.magazzino,
            ))
        .toList();

    final notifier = ref.read(odlExtensionProvider(widget.code).notifier);
    await notifier.addMateriali(nuovi);
    // Il prelievo scala SOLO il magazzino scelto per ogni materiale.
    for (final l in _cart.values) {
      await StockImpegnatoStore.impegna(
          l.material.materialCode, l.magazzino, l.quantita);
    }

    if (!mounted) return;
    setState(() => _saving = false);
    showSapToast(context,
        '${_cart.length} ${_cart.length == 1 ? "materiale aggiunto" : "materiali aggiunti"} all\'OdL');
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(workOrderDetailProvider(widget.code));
    final materials = ref.watch(materialSearchProvider(_query));
    // I nomi dei magazzini (anagrafica): si osserva perché la schermata si
    // ridisegni quando la lista arriva.
    ref.watch(warehousesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aggiungi componenti'),
        actions: [
          OdlActionsMenu(code: widget.code, scope: OdlMenuScope.addComponente)
        ],
      ),
      body: orderAsync.when(
        loading: () => const WfmLoading(),
        error: (e, _) => WfmErrorState(message: e.toString()),
        data: (order) => Column(
          children: [
            // Barra di ricerca + scanner
            Padding(
              padding: kPagePadding,
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Cerca materiale (codice o descrizione)',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: _scanBarcode,
                  icon: const Icon(Icons.qr_code_scanner),
                  tooltip: 'Scansiona barcode',
                ),
              ]),
            ),
            const Divider(height: 1),
            // Elenco a tendina dei materiali, con caselle da spuntare. I
            // materiali spuntati compaiono sotto, ciascuno con i suoi magazzini.
            Expanded(
              child: materials.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Errore: $e')),
                data: (list) => list.isEmpty
                    ? const EmptyState(
                        title: 'Nessun materiale',
                        subtitle: 'Affina la ricerca o scansiona un barcode.',
                        icon: Icons.inventory_2_outlined,
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.borderLight),
                          ),
                          child: Theme(
                            data: Theme.of(context)
                                .copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              key: const PageStorageKey('tendina-materiali'),
                              initiallyExpanded: true,
                              leading: const Icon(Icons.inventory_2_outlined,
                                  color: AppColors.primary),
                              title: Text('Materiali disponibili',
                                  style: AppTextStyles.headingSmall),
                              subtitle: Text(
                                  _cart.isEmpty
                                      ? '${list.length} materiali'
                                      : '${_cart.length} selezionati su ${list.length}',
                                  style: AppTextStyles.bodySmall),
                              childrenPadding: const EdgeInsets.fromLTRB(
                                  8, 0, 8, 8),
                              children: [
                                for (final m in list)
                                  _MaterialeRow(
                                    material: m,
                                    cartLine: _cart[m.materialCode],
                                    onToggle: () => _toggle(m),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
              ),
            ),
            // Carrello (se almeno un materiale è selezionato)
            if (_cart.isNotEmpty) _cartEditor(),
          ],
        ),
      ),
    );
  }

  Widget _cartEditor() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Material(
        elevation: 10,
        color: AppColors.backgroundPage,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              14, 10, 14, MediaQuery.of(context).viewInsets.bottom + 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Maniglia visiva: richiama i pannelli a comparsa dell'app.
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Row(children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.shopping_cart_outlined,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text('${_cart.length}',
                        style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800)),
                  ]),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                      _cart.length == 1
                          ? 'materiale selezionato'
                          : 'materiali selezionati',
                      style: AppTextStyles.headingSmall
                          .copyWith(color: AppColors.primary)),
                ),
              ]),
              const SizedBox(height: 10),
              // Lista delle righe carrello
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 420),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final line in _cart.values)
                      _CartLineRow(
                        line: line,
                        nomeMagazzino: _nomeMagazzino,
                        onMagazzino: (c) =>
                            _setMagazzino(line.material.materialCode, c),
                        onSetQta: (v) => _setQta(line.material.materialCode, v),
                        onRemove: () => _toggle(line.material),
                        onIncrement: () =>
                            _incrementQta(line.material.materialCode),
                        onDecrement: () =>
                            _decrementQta(line.material.materialCode),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _confirm,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_circle_outline),
                  label: Text(
                      _saving ? 'Invio…' : 'Aggiungi ${_cart.length} all\'OdL'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Riga dell'elenco : casella da spuntare + descrizione + giacenza + barcode.
class _MaterialeRow extends StatelessWidget {
  final MaterialItem material;
  final _CartLine? cartLine;
  final VoidCallback onToggle;

  const _MaterialeRow({
    required this.material,
    required this.cartLine,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final selected = cartLine != null;
    // Giacenza totale rimasta (somma dei magazzini, al netto dei prelievi).
    num totale = 0;
    for (final e in material.giacenze.entries) {
      totale += StockImpegnatoStore.residuo(
          e.value, material.materialCode, e.key);
    }
    // Meno quanto è già nel carrello per questo materiale.
    totale -= cartLine?.quantita ?? 0;
    if (totale < 0) totale = 0;
    final colore = totale <= 0
        ? AppColors.accentRed
        : (totale < 5 ? AppColors.accentOrange : AppColors.accentGreen);
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySurface : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.borderLight,
              width: selected ? 1.5 : 1),
        ),
        child: Row(children: [
          Checkbox(
            value: selected,
            onChanged: (_) => onToggle(),
            activeColor: AppColors.primary,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(material.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.headingSmall),
                const SizedBox(height: 2),
                Text('${material.materialCode} · ${material.unitOfMeasure}',
                    style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: colore.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.inventory_2_outlined, size: 12, color: colore),
              const SizedBox(width: 4),
              Text('${totale.toStringAsFixed(0)} ${material.unitOfMeasure}',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: colore)),
            ]),
          ),
          if (material.barcode != null && material.barcode!.isNotEmpty) ...[
            const SizedBox(width: 6),
            const Icon(Icons.qr_code, size: 16, color: AppColors.primary),
          ],
          const SizedBox(width: 8),
        ]),
      ),
    );
  }
}

/// Riga del carrello : materiale, magazzini in cui è disponibile (con la
/// quantità rimanente di ciascuno) e quantità da prelevare.
class _CartLineRow extends StatelessWidget {
  final _CartLine line;
  final String Function(String codice) nomeMagazzino;
  final void Function(String codice) onMagazzino;
  final void Function(String v) onSetQta;
  final VoidCallback onRemove;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _CartLineRow({
    required this.line,
    required this.nomeMagazzino,
    required this.onMagazzino,
    required this.onSetQta,
    required this.onRemove,
    required this.onIncrement,
    required this.onDecrement,
  });

  String _fmt(num n) => n % 1 == 0 ? n.toInt().toString() : n.toString();

  @override
  Widget build(BuildContext context) {
    final m = line.material;
    final overstock = line.isOverstock;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: overstock ? AppColors.accentRed : AppColors.borderLight,
              width: overstock ? 1.5 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyLarge
                            .copyWith(fontWeight: FontWeight.w700)),
                    Text(m.materialCode, style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
              _QtyStepper(
                controller: line.qtaCtrl,
                onSetQta: onSetQta,
                onIncrement: onIncrement,
                onDecrement: onDecrement,
              ),
              const SizedBox(width: 4),
              // Rimuovi: tono rosso tenue, coerente con le altre azioni distruttive.
              IconButton(
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.accentRed.withValues(alpha: 0.10),
                  foregroundColor: AppColors.accentRed,
                  shape: const CircleBorder(),
                ),
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: onRemove,
                tooltip: 'Rimuovi',
              ),
            ]),
            const SizedBox(height: 6),
            // Magazzini in cui il materiale è disponibile: si sceglie da quale
            // prelevare. Il prelievo scala solo il magazzino scelto.
            for (final codice in m.giacenze.keys)
              _MagazzinoRiga(
                nome: nomeMagazzino(codice),
                // Il magazzino scelto mostra quanto resterà dopo questo
                // prelievo: il numero scende insieme alla quantità.
                rimanenti: codice == line.magazzino
                    ? line.disponibileResiduo
                    : line.residuoDi(codice),
                unita: m.unitOfMeasure,
                scelto: codice == line.magazzino,
                abilitato: line.residuoDi(codice) > 0,
                fmt: _fmt,
                onTap: () => onMagazzino(codice),
              ),
            if (overstock)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Stock insufficiente in questo magazzino',
                    style: AppTextStyles.labelSmall.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.accentRed)),
              ),
          ],
        ),
      ),
    );
  }
}

/// Un magazzino del materiale: "Nome (rimanenti: 30)" con la scelta.
class _MagazzinoRiga extends StatelessWidget {
  final String nome;
  final num rimanenti;
  final String unita;
  final bool scelto;
  final bool abilitato;
  final String Function(num) fmt;
  final VoidCallback onTap;

  const _MagazzinoRiga({
    required this.nome,
    required this.rimanenti,
    required this.unita,
    required this.scelto,
    required this.abilitato,
    required this.fmt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colore = abilitato ? AppColors.textPrimary : AppColors.textHint;
    return InkWell(
      onTap: abilitato ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Icon(
              scelto ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              size: 20,
              color: scelto
                  ? AppColors.primary
                  : (abilitato ? AppColors.textSecondary : AppColors.textHint)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
                unita == 'PZ'
                    ? '$nome (pezzi rimanenti: ${fmt(rimanenti)})'
                    : '$nome (rimanenti: ${fmt(rimanenti)} $unita)',
                style: AppTextStyles.bodyMedium.copyWith(
                    color: colore,
                    fontWeight: scelto ? FontWeight.w700 : FontWeight.w400)),
          ),
        ]),
      ),
    );
  }
}

/// Stepper compatto "− qty +" in un'unica pillola bordata, al posto di due
/// pulsanti circolari pieni: meno pesante visivamente, più chiaro che le tre
/// parti sono un solo controllo.
class _QtyStepper extends StatelessWidget {
  final TextEditingController controller;
  final void Function(String v) onSetQta;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _QtyStepper({
    required this.controller,
    required this.onSetQta,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.backgroundPage,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _step(Icons.remove_rounded, onDecrement),
        Container(width: 1, height: 22, color: AppColors.border),
        SizedBox(
          width: 42,
          child: TextField(
            controller: controller,
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            style: AppTextStyles.headingSmall,
            onChanged: onSetQta,
          ),
        ),
        Container(width: 1, height: 22, color: AppColors.border),
        _step(Icons.add_rounded, onIncrement),
      ]),
    );
  }

  Widget _step(IconData icon, VoidCallback onTap) => InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 40,
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
      );
}
