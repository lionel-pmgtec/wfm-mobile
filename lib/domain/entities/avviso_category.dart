// Categoria e sottotipo di Avviso di Servizio.
//
// **SAP è la fonte di verità.** I codici di questo registry sono quelli veri
// letti da DG1, non quelli ipotizzati in fase di specifica:  Gli avvisi
// reali sono ZP, IS e RA, e finivano tutti nel fallback "tipo sconosciuto".
//
// Il registry NON è chiuso: quando SAP introduce un tipo, si aggiunge una riga
// in [AvvisoSubType.all]. Un codice assente non rompe nulla — ricade sul
// fallback di [fromCode] — ma resta invisibile.

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

  /// Registry dei sottotipi gestiti dall'app.
  ///
  /// In testa i codici **realmente presenti su DG1**; sotto quelli di specifica,
  /// mai osservati sui dati veri e tenuti solo per compatibilità.
  static const List<AvvisoSubType> all = [
    // ══ CODICI REALI ═════════════════
    AvvisoSubType(
      code: 'ZP',
      label: 'Perdite Idriche',
      category: AvvisoCategory.prontoIntervento,
      icon: Icons.water_drop_outlined,
      allowsCreationFromApp: true,
    ),
    AvvisoSubType(
      code: 'IS',
      label: 'Interruzione Servizio',
      category: AvvisoCategory.prontoIntervento,
      icon: Icons.report_problem_outlined,
    ),
    AvvisoSubType(
      code: 'RA',
      label: 'Richiesta abbuono',
      category: AvvisoCategory.prontoIntervento,
      icon: Icons.receipt_long_outlined,
    ),

    AvvisoSubType(
      code: 'ZN',
      label: 'Manutenzione Fognatura',
      category: AvvisoCategory.prontoIntervento,
      icon: Icons.water_damage_outlined,
    ),
    AvvisoSubType(
      code: 'ZH',
      label: 'Segnalazione idrica (ZH)',
      category: AvvisoCategory.prontoIntervento,
      icon: Icons.water_drop_outlined,
    ),
    AvvisoSubType(
      code: 'ZM',
      label: 'Manutenzione Acqua',
      category: AvvisoCategory.prontoIntervento,
      icon: Icons.opacity_outlined,
    ),
    AvvisoSubType(
      code: 'ZF',
      label: 'Fognatura (ZF)',
      category: AvvisoCategory.prontoIntervento,
      icon: Icons.water_damage_outlined,
    ),

    // ══ CODICI DI SPECIFICA — mai osservati sui dati reali ═══════════
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

/// Descrizione leggibile del tipo Avviso dal codice SAP (TIPO_AVVISO).
///
/// **Rispecchia 1:1 la fonte di verità** del Cruscotto — la funzione
/// `tipoAvvisoDescrizione` in `Cruscotto-WFM/src/services/sapMappers.ts`.
/// Il backend invia al tablet solo il codice grezzo (nessuna descrizione),
/// quindi per mostrare le stesse etichette del Cruscotto replichiamo qui la
/// sua identica mappa. Se il Cruscotto aggiunge un codice, si aggiunge la
/// stessa riga qui — nessun valore inventato.
String avvisoTipoDescrizione(String codice) {
  switch (codice.trim().toUpperCase()) {
    case 'ZH':
      return 'Pronto Intervento H2O';
    case 'ZF':
      return 'Pronto Intervento Fognatura';
    case 'PA':
      return 'Richiesta Preventivo Acqua';
    case 'M1':
      return 'Manutenzione';
    case 'M2':
      return 'Avviso di attività';
    default:
      return 'Avviso SAP';
  }
}

/// Etichetta completa "CODICE · Descrizione" (formato del Cruscotto).
String avvisoTipoLabel(String codice) {
  final code = codice.trim();
  final desc = avvisoTipoDescrizione(code);
  return code.isEmpty ? desc : '$code · $desc';
}

/// Vero se il tipo è un Pronto Intervento secondo la mappa del Cruscotto
/// (le descrizioni che iniziano con "Pronto Intervento" — oggi ZH e ZF).
bool avvisoTipoIsProntoIntervento(String codice) =>
    avvisoTipoDescrizione(codice).startsWith('Pronto Intervento');

