// Categoria e sottotipo di Avviso di Servizio.
//
// **SAP è la fonte di verità.** I codici di questo registry sono quelli veri
// letti da DG1, non quelli ipotizzati in fase di specifica: la specifica
// prevedeva ZF-PF, ZA01, ZF-ZF01, ZA02, PA, e sul centro SP1 (2026-07-17,
// finestra 90 giorni, 55 avvisi) **nessuno di questi cinque esiste**. Gli avvisi
// reali sono ZP, IS e RA, e finivano tutti nel fallback "tipo sconosciuto".
//
// Il registry NON è chiuso: quando SAP introduce un tipo, si aggiunge una riga
// in [AvvisoSubType.all]. Un codice assente non rompe nulla — ricade sul
// fallback di [fromCode] — ma resta invisibile, ed è così che i cinque tipi
// sbagliati sono sopravvissuti fino ai primi dati veri.

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
    // ══ CODICI REALI — rilevati su SP1 il 2026-07-17 ═════════════════
    AvvisoSubType(
      code: 'ZP',
      label: 'Perdite Idriche',
      // 47 avvisi su 55, tutti "Perdite Idriche", collegati a ordini SOPA/ZA02
      // di perdita: è a tutti gli effetti un pronto intervento.
      category: AvvisoCategory.prontoIntervento,
      icon: Icons.water_drop_outlined,
      allowsCreationFromApp: true,
    ),
    AvvisoSubType(
      code: 'IS',
      label: 'Interruzione Servizio',
      // 5 avvisi, tutti con descrizione "Prova ..." — sono messaggi di test
      // lasciati su DG1. Il significato del codice è DA CONFERMARE: la
      // categoria qui è un'ipotesi, non un dato.
      category: AvvisoCategory.prontoIntervento,
      icon: Icons.report_problem_outlined,
    ),
    AvvisoSubType(
      code: 'RA',
      label: 'Richiesta abbuono',
      // 3 avvisi, "Richiesta abbuono fondo di garanzia": è una pratica
      // amministrativa, NON un intervento di campo. Nessuna delle due categorie
      // dell'app lo descrive davvero. Resta prontoIntervento perché è ciò che
      // il fallback faceva già, ma è una scelta DA VALIDARE col metodo:
      // forse questi avvisi non dovrebbero nemmeno arrivare al tecnico.
      category: AvvisoCategory.prontoIntervento,
      icon: Icons.receipt_long_outlined,
    ),

    // ══ ALTRI CODICI REALI — rilevati su SP1 il 2026-07-23 ════════════
    // Estrazione 2025→2026: oltre a ZP/IS/RA compaiono anche questi. Prima
    // finivano nel fallback "tipo sconosciuto" e mostravano il codice grezzo.
    AvvisoSubType(
      code: 'ZN',
      // 44 avvisi — secondo tipo più frequente dopo ZP. Manutenzione fognaria.
      label: 'Manutenzione Fognatura',
      category: AvvisoCategory.prontoIntervento,
      icon: Icons.water_damage_outlined,
    ),
    AvvisoSubType(
      code: 'ZH',
      // 10 avvisi. Semantica non confermata: etichetta provvisoria, DA VALIDARE.
      label: 'Segnalazione idrica (ZH)',
      category: AvvisoCategory.prontoIntervento,
      icon: Icons.water_drop_outlined,
    ),
    AvvisoSubType(
      code: 'ZM',
      // Manutenzione H2O (censimento IW58). 1 avviso su SP1.
      label: 'Manutenzione Acqua',
      category: AvvisoCategory.prontoIntervento,
      icon: Icons.opacity_outlined,
    ),
    AvvisoSubType(
      code: 'ZF',
      // Fognatura. 1 avviso su SP1. Etichetta prudente, DA VALIDARE.
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

