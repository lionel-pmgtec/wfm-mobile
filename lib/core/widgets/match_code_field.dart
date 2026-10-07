// Campo "match code" in stile SAP: mostra il valore scelto, il tocco apre
// l'elenco selezionabile in un pannello, con ricerca se ci sono più voci.
// Sostituisce griglie/tendine quando i valori vengono da un catalogo del
// backend (es. tipi OdL): i VALORI restano quelli del cruscotto, qui c'è
// solo la presentazione.

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class MatchCodeOption<T> {
  final T value;
  final String code;
  final String label;
  final IconData? icon;
  final Color? color;

  const MatchCodeOption({
    required this.value,
    required this.code,
    this.label = '',
    this.icon,
    this.color,
  });

  String get display => label.isEmpty ? code : '$code — $label';
}

class MatchCodeField<T> extends StatelessWidget {
  final String label;
  final String? hint;
  final List<MatchCodeOption<T>> options;
  final T? value;
  final ValueChanged<T> onChanged;
  final bool enabled;

  /// Quali opzioni si possono ancora toccare nel pannello. `null` (default) =
  /// tutte selezionabili. Serve a "bloccare" le altre voci una volta fatta una
  /// scelta, così un tocco impreciso non la cambia per sbaglio: restano
  /// visibili (informative), ma grigie e non toccabili.
  final bool Function(MatchCodeOption<T> option)? isOptionEnabled;

  const MatchCodeField({
    super.key,
    required this.label,
    this.hint,
    required this.options,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.isOptionEnabled,
  });

  MatchCodeOption<T>? get _selected {
    for (final o in options) {
      if (o.value == value) return o;
    }
    return null;
  }

  Future<void> _open(BuildContext context) async {
    if (!enabled || options.isEmpty) return;
    final chosen = await showModalBottomSheet<MatchCodeOption<T>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MatchCodeSheet<T>(
          title: label,
          options: options,
          selected: value,
          isOptionEnabled: isOptionEnabled),
    );
    if (chosen != null) onChanged(chosen.value);
  }

  @override
  Widget build(BuildContext context) {
    final sel = _selected;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _open(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: Icon(Icons.list_alt_outlined,
              size: 20,
              color: enabled ? AppColors.primary : AppColors.textHint),
        ),
        child: Row(children: [
          if (sel?.icon != null) ...[
            Icon(sel!.icon, size: 18, color: sel.color ?? AppColors.primary),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              sel?.display ?? (hint ?? 'Tocca per scegliere…'),
              overflow: TextOverflow.ellipsis,
              style: sel == null
                  ? const TextStyle(color: AppColors.textHint, fontSize: 14)
                  : AppTextStyles.fieldValueReadOnly,
            ),
          ),
        ]),
      ),
    );
  }
}

class _MatchCodeSheet<T> extends StatefulWidget {
  final String title;
  final List<MatchCodeOption<T>> options;
  final T? selected;
  final bool Function(MatchCodeOption<T> option)? isOptionEnabled;
  const _MatchCodeSheet({
    required this.title,
    required this.options,
    required this.selected,
    this.isOptionEnabled,
  });

  @override
  State<_MatchCodeSheet<T>> createState() => _MatchCodeSheetState<T>();
}

class _MatchCodeSheetState<T> extends State<_MatchCodeSheet<T>> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.options.where((o) {
      if (_query.trim().isEmpty) return true;
      final q = _query.toLowerCase();
      return o.code.toLowerCase().contains(q) ||
          o.label.toLowerCase().contains(q);
    }).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: AppColors.border, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Row(children: [
              Expanded(
                  child:
                      Text(widget.title, style: AppTextStyles.headingSmall)),
              IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context)),
            ]),
          ),
          if (widget.options.length > 5)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search, size: 20),
                  hintText: 'Cerca per codice o descrizione…',
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text('Nessun risultato',
                        style: TextStyle(color: AppColors.textHint)))
                : ListView.separated(
                    controller: scrollCtrl,
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: AppColors.borderLight),
                    itemBuilder: (_, i) {
                      final o = filtered[i];
                      final sel = o.value == widget.selected;
                      final abilitata =
                          widget.isOptionEnabled?.call(o) ?? true;
                      final tintaIcona =
                          abilitata ? (o.color ?? AppColors.primary) : AppColors.textHint;
                      return ListTile(
                        enabled: abilitata,
                        leading: o.icon != null
                            ? Icon(o.icon, color: tintaIcona)
                            : CircleAvatar(
                                radius: 14,
                                backgroundColor: tintaIcona.withValues(alpha: 0.12),
                                child: Text(
                                    o.code.isNotEmpty ? o.code[0] : '?',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: tintaIcona)),
                              ),
                        title: Text(o.code,
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: abilitata
                                    ? null
                                    : AppColors.textHint)),
                        subtitle: o.label.isNotEmpty
                            ? Text(o.label,
                                style: abilitata
                                    ? null
                                    : const TextStyle(color: AppColors.textHint))
                            : null,
                        // Grigia e non toccabile: la scelta è già fatta, non si
                        // cambia per sbaglio con un tocco impreciso.
                        trailing: sel
                            ? const Icon(Icons.check_circle,
                                color: AppColors.accentGreen)
                            : (!abilitata
                                ? const Icon(Icons.lock_outline,
                                    size: 18, color: AppColors.textHint)
                                : null),
                        onTap: abilitata ? () => Navigator.pop(context, o) : null,
                      );
                    },
                  ),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}
