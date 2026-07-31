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
