// Aggiungi componenti all'OdL.
//
// UX semplificata :
//   • Multi-select : seleziona piu materiali con un solo tap
//   • Magazzino auto-recuperato dal materiale (defaultWarehouseCode)
//   • Quantita modificabile per ogni materiale selezionato
//   • Calcolo automatico dei pezzi disponibili rimanenti
//   • Nessun campo "Operazione" (rimosso — non era necessario)
//   • Pulsante "Aggiungi N all'OdL" che inserisce tutto in una volta

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../domain/entities/entities.dart';
import '../../../providers/anagrafica_provider.dart';
import '../../../providers/work_orders_provider.dart';

class AddComponenteScreen extends ConsumerStatefulWidget {
  final String code;
  const AddComponenteScreen({super.key, required this.code});

  @override
  ConsumerState<AddComponenteScreen> createState() =>
      _AddComponenteScreenState();
}

/// Riga del carrello : 1 materiale con la sua quantita richiesta.
class _CartLine {
  final MaterialItem material;
  num quantita;
  final TextEditingController qtaCtrl;
  _CartLine({required this.material})
      : quantita = 1,
        qtaCtrl = TextEditingController(text: '1');

  num get disponibileResiduo =>
      (material.stockDisponibile - quantita).clamp(0, double.infinity);

  bool get isOverstock => quantita > material.stockDisponibile;

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

  void _setQta(String code, String v) {
    final n = num.tryParse(v.replaceAll(',', '.')) ?? 0;
    setState(() => _cart[code]!.quantita = n);
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
    final invalid =
        _cart.values.where((l) => l.quantita <= 0).toList();
    if (invalid.isNotEmpty) {
      showSapToast(context, 'Quantita non valida per alcuni materiali',
          isError: true);
      return;
    }
    final overstock =
        _cart.values.where((l) => l.isOverstock).toList();
    if (overstock.isNotEmpty) {
      final ok = await showWfmConfirmDialog(
        context: context,
        title: 'Stock insufficiente',
        message: 'La quantita richiesta supera la disponibilita per '
            '${overstock.length} materiali. Continuare comunque?',
        confirmLabel: 'Continua',
        tone: WfmDialogTone.warning,
        icon: Icons.warning_amber_rounded,
      );
      if (ok != true) return;
    }
    setState(() => _saving = true);
    await Future<void>.delayed(const Duration(milliseconds: 400));
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
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Aggiungi componenti'),
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
            // Catalogo materiali (checkbox multi-select)
            Expanded(
              child: materials.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Errore: $e')),
                data: (list) => list.isEmpty
                    ? const EmptyState(
                        title: 'Nessun materiale',
                        subtitle:
                            'Affina la ricerca o scansiona un barcode.',
                        icon: Icons.inventory_2_outlined,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        itemCount: list.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 6),
                        itemBuilder: (_, i) =>
                            _MaterialeRow(
                          material: list[i],
                          cartLine: _cart[list[i].materialCode],
                          onToggle: () => _toggle(list[i]),
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
    return Material(
      elevation: 6,
      color: AppColors.backgroundPage,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            12, 12, 12, MediaQuery.of(context).viewInsets.bottom + 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              const Icon(Icons.shopping_cart_outlined,
                  color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                  '${_cart.length} '
                  '${_cart.length == 1 ? "materiale selezionato" : "materiali selezionati"}',
                  style: AppTextStyles.headingSmall
                      .copyWith(color: AppColors.primary)),
            ]),
            const SizedBox(height: 8),
            // Lista delle righe carrello
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final line in _cart.values)
                    _CartLineRow(
                      line: line,
                      onSetQta: (v) =>
                          _setQta(line.material.materialCode, v),
                      onRemove: () => _toggle(line.material),
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
                label: Text(_saving
                    ? 'Invio…'
                    : 'Aggiungi ${_cart.length} all\'OdL'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Riga del catalogo : checkbox + descrizione + stock disponibile + barcode.
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
    final residuo = cartLine?.disponibileResiduo ?? material.stockDisponibile;
    final overstock = cartLine?.isOverstock == true;
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySurface : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected
                  ? AppColors.primary
                  : AppColors.borderLight,
              width: selected ? 1.5 : 1),
        ),
        child: Row(children: [
          Icon(
              selected
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              color: selected
                  ? AppColors.accentGreen
                  : AppColors.textHint),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(material.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.headingSmall),
                const SizedBox(height: 2),
                Text(
                    '${material.materialCode} · ${material.unitOfMeasure}',
                    style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          // Badge stock disponibile (verde / arancio / rosso)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: overstock
                  ? AppColors.accentRed.withValues(alpha: 0.14)
                  : (residuo < 5
                      ? AppColors.accentOrange.withValues(alpha: 0.14)
                      : AppColors.accentGreen.withValues(alpha: 0.14)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                  overstock
                      ? Icons.warning_amber_rounded
                      : Icons.inventory_2_outlined,
                  size: 12,
                  color: overstock
                      ? AppColors.accentRed
                      : (residuo < 5
                          ? AppColors.accentOrange
                          : AppColors.accentGreen)),
              const SizedBox(width: 4),
              Text(
                  '${residuo.toStringAsFixed(0)} ${material.unitOfMeasure}',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: overstock
                          ? AppColors.accentRed
                          : (residuo < 5
                              ? AppColors.accentOrange
                              : AppColors.accentGreen))),
            ]),
          ),
          if (material.barcode != null && material.barcode!.isNotEmpty) ...[
            const SizedBox(width: 6),
            const Icon(Icons.qr_code, size: 16, color: AppColors.primary),
          ],
        ]),
      ),
    );
  }
}

/// Riga del carrello : material + Quantita editabile + stock residuo.
class _CartLineRow extends StatelessWidget {
  final _CartLine line;
  final void Function(String v) onSetQta;
  final VoidCallback onRemove;

  const _CartLineRow({
    required this.line,
    required this.onSetQta,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final m = line.material;
    final residuo = line.disponibileResiduo;
    final overstock = line.isOverstock;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: overstock
                  ? AppColors.accentRed
                  : AppColors.borderLight,
              width: overstock ? 1.5 : 1),
        ),
        child: Row(children: [
          const Icon(Icons.inventory_2_outlined,
              size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium
                        .copyWith(fontWeight: FontWeight.w600)),
                Text(
                    '${m.materialCode} · Magazz.: ${m.defaultWarehouseCode}',
                    style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Campo quantita
          SizedBox(
            width: 80,
            child: TextField(
              controller: line.qtaCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 8),
                labelText: 'Qta',
                suffixText: m.unitOfMeasure,
              ),
              onChanged: onSetQta,
            ),
          ),
          const SizedBox(width: 8),
          // Stock residuo dopo quantita
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: overstock
                  ? AppColors.accentRed.withValues(alpha: 0.14)
                  : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(overstock ? '!' : residuo.toStringAsFixed(0),
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: overstock
                            ? AppColors.accentRed
                            : AppColors.primary)),
                Text('Resid.',
                    style: TextStyle(
                        fontSize: 9, color: AppColors.textSecondary)),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close, size: 16),
            onPressed: onRemove,
          ),
        ]),
      ),
    );
  }
}
