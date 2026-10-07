// Testo delle note di un OdL creato sul tablet.

const Set<String> kCampiConCampoProprio = {'matricola'};

/// Compone le note della creazione.
///
/// [extra] sono i valori digitati nei campi specifici del tipo che non hanno un
/// campo proprio (es. "Lavoro da eseguire" di ZMAV: il backend non lo legge
/// altrove). Se è uno solo si scrive il solo valore; se sono più di uno, per
/// distinguerli, "Etichetta: valore". [base] è la nota libera.
String componiNoteCreazione({
  required List<({String label, String value})> extra,
  required String base,
}) {
  final pieni = extra.where((e) => e.value.trim().isNotEmpty).toList();
  final righe = pieni.length == 1
      ? [pieni.first.value.trim()]
      : [for (final e in pieni) '${e.label}: ${e.value.trim()}'];
  return [
    if (righe.isNotEmpty) righe.join('\n'),
    if (base.trim().isNotEmpty) base.trim(),
  ].join('\n\n');
}

String notaPulita(String s) {
  final righe = s.split('\n').where((r) {
    final t = r.trim();
    return t != 'Dati specifici:' &&
        !t.startsWith('Matricola contatore da sostituire:');
  });
  return righe.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}
