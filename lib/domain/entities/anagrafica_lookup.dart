// Cataloghi selezionabili serviti dal cruscotto (nessun valore hardcoded).
//
// Regola: i VALORI (code/label/opzioni) arrivano SEMPRE dal cruscotto.
// Solo la presentazione (icona/colore del tipo OdL) resta lato app ed è
// derivata dalla `category`, perché SAP non trasmette elementi grafici Flutter.

/// Tipo di Ordine di Lavoro selezionabile (da `GET /anagrafica/wo-types`).
class WorkOrderTypeOption {
  final String code; // es. "ATTI", "SOST"
  final String label; // descrizione mostrata
  final String? category; // usata dall'app per icona/colore (facoltativa)

  const WorkOrderTypeOption({
    required this.code,
    required this.label,
    this.category,
  });
}

/// Riga di correlazione tipo ordine → tipo attività PM → ciclo → settore
/// (da `GET /anagrafica/wo-templates?type=CODE`). Serve a proporre il tipo
/// attività al tecnico: il ciclo/settore restano informativi (`daConfermare`
/// dice quali valori sono dedotti e non ancora verificati su SAP).
class WorkOrderActivityTemplate {
  final String woType; // es. "SOST"
  final String tipoAttivita; // codice PM (SOS, S01, D33…) → tipoAttivitaCodice
  final String tipoAttivitaDesc; // descrizione (Sostituzione, Contatore fermo…)
  final String gruppoCicli; // ciclo di lavoro (SOSCONT1, SOSPNRR…)
  final String settoreContabile; // POT, FOG…
  final String settoreContabileDesc; // "Servizio acqua potabile"…
  final List<String> daConfermare; // valori dedotti, non verificati su SAP
  final bool predefinita; // riga proposta di default

  const WorkOrderActivityTemplate({
    required this.woType,
    required this.tipoAttivita,
    this.tipoAttivitaDesc = '',
    this.gruppoCicli = '',
    this.settoreContabile = '',
    this.settoreContabileDesc = '',
    this.daConfermare = const [],
    this.predefinita = false,
  });

  /// Etichetta pronta per la tendina: "SOS · Sostituzione".
  String get label => tipoAttivitaDesc.isEmpty
      ? tipoAttivita
      : '$tipoAttivita · $tipoAttivitaDesc';

  /// Etichetta da mostrare in una tendina con queste [rows]: se un'altra riga
  /// ha la stessa etichetta (es. ZA02: DST sia con ciclo CONRCO1 sia con
  /// CONRID1) si aggiunge il ciclo, l'unica cosa che le distingue.
  String labelIn(List<WorkOrderActivityTemplate> rows) {
    final doppione = rows.any((r) => !identical(r, this) && r.label == label);
    return doppione && gruppoCicli.isNotEmpty ? '$label · $gruppoCicli' : label;
  }

  /// "SOSCONT1 · POT - Servizio acqua potabile" (riga informativa sotto).
  String get cicloSettore => [
        if (gruppoCicli.isNotEmpty) gruppoCicli,
        if (settoreContabileDesc.isNotEmpty)
          '$settoreContabile - $settoreContabileDesc'
        else if (settoreContabile.isNotEmpty)
          settoreContabile,
      ].join(' · ');
}

/// Tipo di controllo di un campo dinamico.
enum DynFieldType { text, multiline, number, select, date }

DynFieldType dynFieldTypeFrom(String? v) {
  switch ((v ?? '').toLowerCase()) {
    case 'number':
    case 'numeric':
      return DynFieldType.number;
    case 'multiline':
    case 'textarea':
      return DynFieldType.multiline;
    case 'select':
    case 'dropdown':
      return DynFieldType.select;
    case 'date':
      return DynFieldType.date;
    default:
      return DynFieldType.text;
  }
}

/// Specifica di un campo dinamico per tipo OdL
/// (da `GET /anagrafica/wo-fields?type=CODE`).
class DynFieldSpec {
  final String key; // id logico (es. "matricola")
  final String label; // etichetta mostrata
  final DynFieldType type;
  final List<String> options; // valori per i campi `select`
  final bool required;

  const DynFieldSpec({
    required this.key,
    required this.label,
    this.type = DynFieldType.text,
    this.options = const [],
    this.required = false,
  });
}
