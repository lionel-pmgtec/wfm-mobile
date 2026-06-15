// Categoria e sottotipo di Avviso di Servizio (spec aziendale).
//
// L'app gestisce SOLO 5 tipologie:
//   • PRONTO INTERVENTO : ZF-PF, ZA01, ZF-ZF01, ZA02
//   • RICHIESTA DI PREVENTIVO : PA
//
// Per aggiungere un nuovo tipo nel futuro: bastera aggiungere una riga
// nel registry [AvvisoSubType.all].

import 'package:flutter/material.dart';

/// Macro-categoria dell'avviso (flusso operativo).
enum AvvisoCategory {
  prontoIntervento,
  richiestaPreventivo;

  String get label => switch (this) {
        AvvisoCategory.prontoIntervento => 'Pronto Intervento',
        AvvisoCategory.richiestaPreventivo => 'Richiesta di Preventivo',
      };

  String get shortLabel => switch (this) {
        AvvisoCategory.prontoIntervento => 'PI',
        AvvisoCategory.richiestaPreventivo => 'RP',
      };

  IconData get icon => switch (this) {
        AvvisoCategory.prontoIntervento => Icons.flash_on_rounded,
        AvvisoCategory.richiestaPreventivo => Icons.description_outlined,
      };

  /// Vero se il flusso prevede preventivo + firma + PDF + pagamento.
  bool get hasPreventivoFlow => this == AvvisoCategory.richiestaPreventivo;
}

/// Sottotipo concreto di Avviso. Registry CHIUSO ai 5 tipi spec.
class AvvisoSubType {
  final String code; // codice SAP
  final String label;
  final AvvisoCategory category;
  final IconData icon;
  final bool allowsCreationFromApp;

  const AvvisoSubType({
    required this.code,
    required this.label,
    required this.category,
    required this.icon,
    this.allowsCreationFromApp = false,
  });

  /// Registry dei 5 sottotipi gestiti dall'app.
  static const List<AvvisoSubType> all = [
    // ── PRONTO INTERVENTO (4 sottotipi) ──────────────────────────────
    AvvisoSubType(
      code: 'ZF-PF',
      label: 'Pronto Intervento - Pronto Fognatura',
      category: AvvisoCategory.prontoIntervento,
      icon: Icons.warning_amber_rounded,
      allowsCreationFromApp: true,
    ),
    AvvisoSubType(
      code: 'ZA01',
      label: 'Pronto Intervento - Servizio Idrico',
      category: AvvisoCategory.prontoIntervento,
      icon: Icons.water_drop_outlined,
      allowsCreationFromApp: true,
    ),
    AvvisoSubType(
      code: 'ZF-ZF01',
      label: 'Pronto Intervento - Fognatura',
      category: AvvisoCategory.prontoIntervento,
      icon: Icons.water_damage_outlined,
      allowsCreationFromApp: true,
    ),
    AvvisoSubType(
      code: 'ZA02',
      label: 'Pronto Intervento - Acqua',
      category: AvvisoCategory.prontoIntervento,
      icon: Icons.opacity_outlined,
      allowsCreationFromApp: true,
    ),
    // ── RICHIESTA PREVENTIVO ─────────────────────────────────────────
    AvvisoSubType(
      code: 'PA',
      label: 'Richiesta di Preventivo',
      category: AvvisoCategory.richiestaPreventivo,
      icon: Icons.assignment_outlined,
    ),
  ];

  /// Trova un sottotipo dal codice. Se non noto, restituisce un fallback
  /// classificato come [prontoIntervento] (per legacy data SAP).
  static AvvisoSubType fromCode(String? code) {
    final norm = (code ?? '').trim();
    for (final t in all) {
      if (t.code.toLowerCase() == norm.toLowerCase()) return t;
    }
    return AvvisoSubType(
      code: norm.isEmpty ? '-' : norm,
      label: norm.isEmpty ? 'Tipo sconosciuto' : norm,
      category: AvvisoCategory.prontoIntervento,
      icon: Icons.help_outline,
    );
  }

  static List<AvvisoSubType> byCategory(AvvisoCategory c) =>
      all.where((t) => t.category == c).toList();

  /// Sottotipi creabili direttamente dal campo (Pronto Intervento).
  static List<AvvisoSubType> get creatableFromApp =>
      all.where((t) => t.allowsCreationFromApp).toList();
}
