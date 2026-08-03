// Componenti condivisi per la SINCRONIZZAZIONE degli oggetti creati sul campo.
//
// Scopo: rendere l'azione "Sincronizza" raggiungibile ovunque l'operatore possa
// desiderarla (creazione, conferma, dettaglio, elenchi), senza tornare alla Home.
// Qui non c'è logica di sincronizzazione: si richiama solo quella esistente
// (`creationControllerProvider.syncAll()`), centralizzando aspetto e messaggi.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/widgets.dart';
import '../providers/creation_provider.dart';

/// Apre il centro di sincronizzazione: l'operatore vede tutto ciò che attende
/// di partire (ordini e avvisi) e sceglie per ognuno la destinazione.
void openSyncCenter(BuildContext context) =>
    context.push(AppRoutes.syncCenter);

/// Pulsante di sincronizzazione per le AppBar, con contatore degli elementi
/// ancora sul tablet. Da usare in tutte le schermate del percorso di creazione.
class SyncIconButton extends ConsumerWidget {
  /// Colore dell'icona (le AppBar blu usano il bianco di default).
  final Color? color;

  /// Se true, resta visibile anche senza elementi in attesa (apre il riepilogo).
  final bool alwaysVisible;

  const SyncIconButton({super.key, this.color, this.alwaysVisible = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingCreationCountProvider).valueOrNull ?? 0;
    if (pending == 0 && !alwaysVisible) return const SizedBox.shrink();

    return IconButton(
      tooltip: pending > 0
          ? 'Da sincronizzare ($pending in attesa)'
          : 'Sincronizzazione',
      icon: Badge(
        isLabelVisible: pending > 0,
        label: Text('$pending'),
        child: Icon(Icons.cloud_sync_outlined, color: color),
      ),
      onPressed: () => openSyncCenter(context),
    );
  }
}

/// Banner mostrato sul dettaglio di un oggetto ancora presente solo sul tablet
/// (id provvisorio `TMP-…`): spiega lo stato e offre l'azione immediata.
class SyncPendingBanner extends ConsumerWidget {
  /// Testo descrittivo (es. "Questo ordine è stato creato sul tablet").
  final String message;

  /// Codice OdL o numero avviso da controllare. Se valorizzato, il banner
  /// scompare non appena l'oggetto è stato inviato. Se `null`, il banner
  /// segue il totale degli elementi ancora da sincronizzare.
  final String? id;

  const SyncPendingBanner({super.key, required this.message, this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daInviare = id == null
        ? (ref.watch(pendingCreationCountProvider).valueOrNull ?? 0) > 0
        : (ref.watch(isPendingCreationProvider(id!)).valueOrNull ?? false);
    if (!daInviare) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.accentOrange.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accentOrange.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded,
              color: AppColors.accentOrange, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Non ancora sincronizzato',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accentOrange)),
                const SizedBox(height: 2),
                Text(message,
                    style: const TextStyle(
                        fontSize: 12,
                        height: 1.3,
                        color: AppColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () => openSyncCenter(context),
            icon: const Icon(Icons.cloud_upload_outlined, size: 16),
            label: const Text('Sincronizza'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accentOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              // Il tema globale usa Size.fromHeight(56), che impone larghezza
              // infinita: dentro una Row (larghezza non vincolata) manderebbe
              // in errore il layout. Qui il pulsante si adatta al contenuto.
              minimumSize: const Size(0, 40),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Conferma mostrata subito dopo la creazione di un OdL/avviso: comunica che
/// l'oggetto è salvato sul tablet e propone la sincronizzazione immediata.
/// Ritorna true se l'operatore ha scelto di sincronizzare subito.
Future<bool> showCreatedSyncDialog(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required String message,
}) async {
  final scegliSync = await showWfmConfirmDialog(
    context: context,
    title: title,
    message: message,
    confirmLabel: 'Sincronizza ora',
    cancelLabel: 'Più tardi',
    tone: WfmDialogTone.success,
    icon: Icons.check_circle_outline_rounded,
  );
  if (scegliSync != true || !context.mounted) return false;
  // Porta al centro di sincronizzazione: lì si sceglie la destinazione
  // (cruscotto o SAP) per ogni elemento.
  openSyncCenter(context);
  return true;
}
