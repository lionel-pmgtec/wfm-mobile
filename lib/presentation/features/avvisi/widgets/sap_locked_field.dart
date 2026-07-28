// Indicatore visivo "Dato SAP — sola lettura".
//
// **Importante** : i getter pubblici `label`, `value`, `hideIfEmpty` e
// `unavailable` fanno parte del contratto — FormGrid li legge via duck-typing
// per filtrare i campi vuoti dalla griglia (niente buchi nelle 2 colonne).
// Rinominarli o renderli privati rompe il layout in silenzio.

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';

/// [FieldRow] decorato con icona "lucchetto" SAP.
class SapLockedField extends StatelessWidget {
  final String label;
  final String value;
  final bool fullWidth;
  final bool hideIfEmpty;

  /// Il servizio SAP attivo non espone questo campo: si mostra spento anziché
  /// vuoto. Vedi [FieldRow.unavailable].
  final bool unavailable;
  final String? unavailableReason;

  const SapLockedField({
    super.key,
    required this.label,
    required this.value,
    this.fullWidth = false,
    this.hideIfEmpty = true,
    this.unavailable = false,
    this.unavailableReason,
  });

  @override
  Widget build(BuildContext context) => asFieldRow();

  /// Variante "field row diretto" — usata da FormGrid per il filtraggio
  /// automatico. Non chiamare direttamente, lascia che FormGrid faccia da sé.
  FieldRow asFieldRow() => FieldRow(
        label: label,
        value: value,
        fullWidth: fullWidth,
        hideIfEmpty: hideIfEmpty,
        unavailable: unavailable,
        unavailableReason: unavailableReason,
        // Il lucchetto non serve su un campo che il servizio non espone: lì
        // l'icona è già quella del motivo.
        trailing: unavailable
            ? null
            : const Tooltip(
                message: 'Dato SAP — sola lettura',
                child: Icon(Icons.lock_outline,
                    size: 14, color: AppColors.textHint),
              ),
      );
}

/// Variante booleana di [SapLockedField]: mostra una checkbox in sola
/// lettura (dato SAP) con etichetta + "Sì/No" + lucchetto.
class SapLockedCheckbox extends StatelessWidget {
  final String label;
  final bool value;
  final bool fullWidth;

  const SapLockedCheckbox({
    super.key,
    required this.label,
    required this.value,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: AppTextStyles.fieldLabel),
          const SizedBox(height: 4),
          Row(
            children: [
              // Checkbox visiva (read-only).
              SizedBox(
                width: 20,
                height: 20,
                child: IgnorePointer(
                  child: Checkbox(
                    value: value,
                    onChanged: (_) {},
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize:
                        MaterialTapTargetSize.shrinkWrap,
                    activeColor: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  value ? 'Sì' : 'No',
                  style: AppTextStyles.fieldValueReadOnly.copyWith(
                    fontWeight: FontWeight.w600,
                    color:
                        value ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
              ),
              const Tooltip(
                message: 'Dato SAP — sola lettura',
                child: Icon(Icons.lock_outline,
                    size: 14, color: AppColors.textHint),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
