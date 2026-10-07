// Testi condivisi dell'eliminazione di un OdL (lista e dettaglio): eliminare un
// OdL elimina anche l'avviso a cui è associato.

import 'package:flutter/material.dart';

import '../../../../core/widgets/widgets.dart';
import '../../../providers/work_orders_provider.dart';

/// Messaggio di conferma: dice anche quale avviso verrà eliminato.
String messaggioEliminazioneOdl(String code, String? avviso) => avviso == null
    ? "L'ordine di lavoro $code sarà eliminato da questo tablet."
    : "L'ordine di lavoro $code sarà eliminato da questo tablet, insieme "
        "all'avviso associato $avviso.";

/// Esito mostrato dopo l'eliminazione. Se l'avviso non si è potuto eliminare
/// l'OdL è comunque eliminato: lo si dice, con il motivo.
void mostraEsitoEliminazioneOdl(
    BuildContext context, String code, EliminazioneOdl esito) {
  if (esito.avviso == null) {
    showSapToast(context, 'OdL $code eliminato');
  } else if (esito.avvisoEliminato) {
    showSapToast(context, 'OdL $code e avviso ${esito.avviso} eliminati');
  } else {
    showSapToast(
        context,
        'OdL $code eliminato, ma l\'avviso ${esito.avviso} non è stato '
        'eliminato: ${esito.erroreAvviso ?? 'errore sconosciuto'}',
        isError: true);
  }
}
