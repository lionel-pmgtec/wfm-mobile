// Menu azioni OdL (⋮) riutilizzabile — accessibile ovunque nel contesto OdL:
// barra del dettaglio, sotto-schermate e righe della lista.
//
// Il contenuto dipende da TRE cose:
//  1. la SCHERMATA da cui è aperto ([scope]) — ogni pagina mostra solo le voci
//     pertinenti ed esclude l'azione della schermata stessa (niente auto-link);
//  2. il TIPO dell'OdL (contatore, preventivo);
//  3. lo STATO dell'OdL (le azioni di modifica spariscono se è chiuso).
//
// Passa [order] quando è già disponibile (dettaglio/lista); altrimenti passa
// solo [code] e il widget legge l'OdL dalla cache per le voci condizionali.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../domain/entities/entities.dart';
import '../../../providers/work_orders_provider.dart';
import 'reassign_sheet.dart';

/// Schermata da cui viene aperto il menu: decide quali voci mostrare.
enum OdlMenuScope {
  detail, // Dettaglio OdL — hub completo
  list, // Riga della lista OdL — set compatto
  esito, // Esito OdL
  esitoAppuntamento, // Esito appuntamento
  appuntamenti, // Appuntamenti
  storico, // Storico appuntamenti
  sospensioni, // Sospensioni
  genOre, // Genera ore
  addComponente, // Aggiungi componente
  cambioCid, // Cambio CID
  copia, // Copia OdL
  meter, // Gestione contatore
}

class OdlActionsMenu extends ConsumerWidget {
  final String code;
  final WorkOrder? order;
  final Color? iconColor;

  /// Schermata da cui è mostrato il menu (default: dettaglio = menu completo).
  final OdlMenuScope scope;

  const OdlActionsMenu({
    super.key,
    required this.code,
    this.order,
    this.iconColor,
    this.scope = OdlMenuScope.detail,
  });

  // Voci pertinenti a ciascuna schermata (l'ordine di visualizzazione è quello
  // di [_ordered]). Facilmente modificabile: per aggiungere/togliere una voce
  // da una pagina basta agire qui.
  static const Map<OdlMenuScope, Set<String>> _scopeKeys = {
    OdlMenuScope.detail: {
      // Voci escluse volutamente perché già presenti come azioni rapide nella
      // pagina di dettaglio: 'appointments', 'gen_ore'→Riepilogo ore resta,
      // 'add_comp'. In dettaglio compaiono anche Contatore ed Elimina Ordine.
      'storico', 'esito_app', 'sospensioni', 'gen_ore', 'meter', 'preventivo',
      'copia', 'cambio_cid', 'scanner', 'map', 'reassign', 'cancel', 'delete',
    },
    OdlMenuScope.list: {
      'esito_app', 'appointments', 'copia', 'reassign', 'cancel',
    },
    OdlMenuScope.esito: {
      'appointments', 'storico', 'sospensioni', 'gen_ore', 'add_comp',
      'meter', 'preventivo', 'map',
    },
    OdlMenuScope.esitoAppuntamento: {
      'appointments', 'storico', 'sospensioni', 'map',
    },
    OdlMenuScope.appuntamenti: {
      'storico', 'esito_app', 'sospensioni', 'map',
    },
    OdlMenuScope.storico: {
      'appointments', 'esito_app', 'sospensioni', 'map',
    },
    OdlMenuScope.sospensioni: {
      'appointments', 'storico', 'esito_app', 'gen_ore', 'map',
    },
    OdlMenuScope.genOre: {
      'appointments', 'add_comp', 'meter', 'map',
    },
    OdlMenuScope.addComponente: {
      'appointments', 'gen_ore', 'meter', 'map',
    },
    OdlMenuScope.cambioCid: {
      'appointments', 'reassign', 'map',
    },
    OdlMenuScope.copia: {
      'appointments', 'map',
    },
    OdlMenuScope.meter: {
      'appointments', 'gen_ore', 'add_comp', 'map',
    },
  };

  /// Elenco ordinato (chiave, etichetta) di tutte le voci possibili.
  static const List<(String, String)> _ordered = [
    ('appointments', 'Appuntamenti'),
    ('storico', 'Storico appuntamenti'),
    ('esito_app', 'Esito appuntamento'),
    ('sospensioni', 'Sospensioni'),
    ('gen_ore', 'Riepilogo ore'),
    ('add_comp', 'Aggiungi componente'),
    ('meter', 'Contatore'),
    ('preventivo', 'Preventivo'),
    ('copia', 'Copia OdL'),
    ('cambio_cid', 'Cambio CID'),
    ('scanner', 'Scansiona barcode'),
    ('map', 'Apri mappa'),
    ('reassign', 'Riassegna OdL'),
    ('cancel', 'Annulla OdL'),
    ('delete', 'Elimina Ordine'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wo = order ?? ref.watch(workOrderDetailProvider(code)).valueOrNull;

    // Se l'OdL non è ancora in cache (`known == false`) non nascondiamo per
    // stato: meglio non togliere azioni per un dato mancante.
    final known = wo != null;
    final active = !known || !wo.isClosed;
    final hasMeter = wo?.hasMeter ?? false;
    final hasPreventivo = wo?.hasPreventivo ?? false;
    final canCancel = wo?.canCancel ?? false;

    // Filtro per stato/tipo dell'OdL (indipendente dalla schermata).
    bool stateAllows(String key) => switch (key) {
          'esito_app' ||
          'sospensioni' ||
          'gen_ore' ||
          'add_comp' ||
          'cambio_cid' ||
          'reassign' =>
            active,
          // Contatore: sempre nel dettaglio (richiesto), altrove solo se l'OdL
          // ha un contatore.
          'meter' => hasMeter || scope == OdlMenuScope.detail,
          'preventivo' => hasPreventivo,
          'cancel' => canCancel,
          _ => true,
        };

    final allowed = _scopeKeys[scope] ?? _scopeKeys[OdlMenuScope.detail]!;

    final items = <PopupMenuEntry<String>>[];
    for (final (key, label) in _ordered) {
      if (!allowed.contains(key)) continue;
      if (!stateAllows(key)) continue;
      if (key == 'reassign') {
        items.add(const PopupMenuItem(
          value: 'reassign',
          child: Row(children: [
            Icon(Icons.swap_horiz_rounded, size: 18, color: Colors.black54),
            SizedBox(width: 8),
            Text('Riassegna OdL'),
          ]),
        ));
      } else {
        items.add(PopupMenuItem(value: key, child: Text(label)));
      }
    }

    return PopupMenuButton<String>(
      tooltip: 'Azioni OdL',
      icon: Icon(Icons.more_vert, color: iconColor),
      onSelected: (v) => _onMenu(context, ref, v, wo),
      itemBuilder: (_) => items,
    );
  }

  Future<void> _onMenu(
      BuildContext context, WidgetRef ref, String value, WorkOrder? wo) async {
    switch (value) {
      case 'appointments':
        context.push(AppRoutes.appointmentsPath(code));
        break;
      case 'storico':
        context.push(AppRoutes.storicoAppuntamentiPath(code));
        break;
      case 'esito_app':
        context.push(AppRoutes.esitoAppuntamentoPath(code));
        break;
      case 'sospensioni':
        context.push(AppRoutes.sospensioniPath(code));
        break;
      case 'gen_ore':
        context.push(AppRoutes.genOrePath(code));
        break;
      case 'add_comp':
        context.push(AppRoutes.addComponentePath(code));
        break;
      case 'copia':
        context.push(AppRoutes.copiaOrdinePath(code));
        break;
      case 'cambio_cid':
        context.push(AppRoutes.cambioCidPath(code));
        break;
      case 'meter':
        context.push(AppRoutes.meterPath(code));
        break;
      case 'preventivo':
        context.push(AppRoutes.preventivoPath(code));
        break;
      case 'scanner':
        context.push(AppRoutes.scanner);
        break;
      case 'map':
        context.go(AppRoutes.map);
        break;
      case 'reassign':
        await showReassignSheet(context, ref, code);
        break;
      case 'cancel':
        await _confirmCancel(context, ref);
        break;
      case 'delete':
        await _confirmDelete(context, ref);
        break;
    }
  }

  /// Elimina definitivamente l'OdL (diverso da "Annulla OdL", che cambia stato).
  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showWfmConfirmDialog(
      context: context,
      title: 'Eliminare l\'OdL?',
      message: 'L\'ordine di lavoro $code sarà eliminato definitivamente.',
      confirmLabel: 'Elimina',
      cancelLabel: 'Annulla',
      tone: WfmDialogTone.danger,
      icon: Icons.delete_outline,
    );
    if (ok == true && context.mounted) {
      final res = await ref.read(workOrderActionsProvider).delete(code);
      if (context.mounted) {
        res.isSuccess
            ? context.pop()
            : showSapToast(context, 'Errore eliminazione', isError: true);
      }
    }
  }

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    final reasonCtrl = TextEditingController();
    final ok = await showWfmConfirmDialog(
      context: context,
      title: 'Annulla OdL',
      message:
          'L\'OdL verrà annullato e rimosso dal tablet. Inserisci un motivo per la chiusura.',
      confirmLabel: 'Annulla OdL',
      cancelLabel: 'Indietro',
      tone: WfmDialogTone.danger,
      icon: Icons.cancel_outlined,
      extraContent: TextField(
        controller: reasonCtrl,
        decoration: const InputDecoration(labelText: 'Motivo annullamento'),
        maxLines: 2,
      ),
    );
    if (ok == true && context.mounted) {
      final res = await ref.read(workOrderActionsProvider).changeStatus(
            code,
            WorkOrderStatus.annullato,
            reason: reasonCtrl.text,
          );
      if (context.mounted) {
        res.isSuccess
            ? context.pop()
            : showSapToast(context, 'Errore annullamento', isError: true);
      }
    }
  }
}
