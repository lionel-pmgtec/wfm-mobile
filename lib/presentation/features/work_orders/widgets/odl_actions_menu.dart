// Menu azioni OdL (⋮) riutilizzabile — accessibile ovunque nel contesto OdL:
// barra del dettaglio, sotto-schermate e righe della lista.
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

class OdlActionsMenu extends ConsumerWidget {
  final String code;
  final WorkOrder? order;
  final Color? iconColor;
  const OdlActionsMenu({
    super.key,
    required this.code,
    this.order,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wo =
        order ?? ref.watch(workOrderDetailProvider(code)).valueOrNull;
    return PopupMenuButton<String>(
      tooltip: 'Azioni OdL',
      icon: Icon(Icons.more_vert, color: iconColor),
      onSelected: (v) => _onMenu(context, ref, v, wo),
      itemBuilder: (_) => [
        const PopupMenuItem(
            value: 'appointments', child: Text('Appuntamenti')),
        const PopupMenuItem(
            value: 'storico', child: Text('Storico appuntamenti')),
        const PopupMenuItem(
            value: 'esito_app', child: Text('Esito appuntamento')),
        const PopupMenuItem(value: 'sospensioni', child: Text('Sospensioni')),
        const PopupMenuItem(value: 'gen_ore', child: Text('Genera ore')),
        const PopupMenuItem(
            value: 'add_comp', child: Text('Aggiungi componente')),
        const PopupMenuItem(value: 'copia', child: Text('Copia OdL')),
        const PopupMenuItem(value: 'cambio_cid', child: Text('Cambio CID')),
        if (wo?.hasMeter ?? false)
          const PopupMenuItem(
              value: 'meter', child: Text('Gestione contatore')),
        const PopupMenuItem(
            value: 'scanner', child: Text('Scansiona barcode')),
        const PopupMenuItem(value: 'map', child: Text('Apri mappa')),
        const PopupMenuItem(
          value: 'reassign',
          child: Row(children: [
            Icon(Icons.swap_horiz_rounded, size: 18, color: Colors.black54),
            SizedBox(width: 8),
            Text('Riassegna OdL'),
          ]),
        ),
        if (wo?.canCancel ?? false)
          const PopupMenuItem(value: 'cancel', child: Text('Annulla OdL')),
      ],
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
