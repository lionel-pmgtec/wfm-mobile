// Barra azioni del ciclo di vita OdL (M4): Avvia / Pausa / Riprendi / Sospendi / Concludi.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/services/geolocation_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../domain/entities/entities.dart';
import '../../../providers/work_orders_provider.dart';

class LifecycleActionBar extends ConsumerWidget {
  final WorkOrder order;
  const LifecycleActionBar({super.key, required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (order.isClosed) {
      return _closedBanner();
    }

    final buttons = <Widget>[];

    // Avvia (da ricevuto) o Riprendi (da sospeso)
    if (order.canStart) {
      buttons.add(WfmActionButton(
        icon: Icons.play_arrow_rounded,
        label: order.status == WorkOrderStatus.sospeso ? 'Riprendi' : 'Avvia',
        color: AppColors.accentGreen,
        onPressed: () => _changeStatus(context, ref, WorkOrderStatus.inEsecuzione),
      ));
    }

    // Riprendi da pausa locale (locale → inEsecuzione)
    if (order.canResumeFromPause) {
      buttons.add(WfmActionButton(
        icon: Icons.play_arrow_rounded,
        label: 'Riprendi',
        color: AppColors.accentGreen,
        onPressed: () => _resumeFromPause(context, ref),
      ));
    }

    // Metti in pausa (locale, non modifica lo stato sul server)
    if (order.canPause) {
      buttons.add(WfmActionButton(
        icon: Icons.pause_rounded,
        label: 'Pausa',
        color: AppColors.accentOrange,
        onPressed: () => _pauseLocally(context, ref),
      ));
    }

    // Sospendi (invia al server, rimuove dal tablet)
    if (order.canSuspend) {
      buttons.add(WfmActionButton(
        icon: Icons.stop_circle_outlined,
        label: 'Sospendi',
        color: AppColors.statusSuspended,
        onPressed: () => _suspend(context, ref),
      ));
    }

    // Concludi (apre schermata esito)
    if (order.canComplete) {
      buttons.add(WfmActionButton(
        icon: Icons.flag_rounded,
        label: 'Concludi',
        color: AppColors.primary,
        onPressed: () => context.push(AppRoutes.esitoPath(order.externalCode)),
      ));
    }

    if (buttons.isEmpty) return const SizedBox.shrink();

    final spaced = <Widget>[];
    for (var i = 0; i < buttons.length; i++) {
      spaced.add(buttons[i]);
      if (i < buttons.length - 1) spaced.add(const SizedBox(width: 8));
    }

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Banner pausa locale visibile quando status = inPausa
          if (order.status == WorkOrderStatus.inPausa)
            Container(
              width: double.infinity,
              color: AppColors.accentOrange.withValues(alpha: 0.12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: const Row(
                children: [
                  Icon(Icons.pause_circle_outline, size: 16, color: AppColors.accentOrange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'In pausa — sul server risulta ancora In esecuzione',
                      style: TextStyle(fontSize: 11, color: AppColors.accentOrange),
                    ),
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(children: spaced),
          ),
        ],
      ),
    );
  }

  Widget _closedBanner() => SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.all(16),
          color: AppColors.statusDoneBg,
          width: double.infinity,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                  order.status == WorkOrderStatus.completato ||
                          order.status == WorkOrderStatus.inviatoSAP
                      ? Icons.check_circle
                      : Icons.cancel,
                  color: order.status == WorkOrderStatus.annullato
                      ? AppColors.accentRed
                      : AppColors.accentGreen),
              const SizedBox(width: 8),
              Text('OdL ${order.status.label.toLowerCase()}',
                  style: AppTextStyles.headingSmall),
            ],
          ),
        ),
      );

  Future<void> _changeStatus(
      BuildContext context, WidgetRef ref, WorkOrderStatus status) async {
    // Cattura posizione su Avvia (timbratura di campo). Non blocca il flusso
    // se i permessi sono negati o il GPS è off.
    final geo = await GeolocationService.instance.getCurrentPosition();
    final res = await ref
        .read(workOrderActionsProvider)
        .changeStatus(order.externalCode, status, geolocation: geo);
    if (context.mounted) {
      res.isSuccess
          ? showSapToast(context, 'Stato: ${status.label}')
          : showSapToast(context, 'Errore aggiornamento stato', isError: true);
    }
  }

  Future<void> _pauseLocally(BuildContext context, WidgetRef ref) async {
    final res = await ref.read(workOrderActionsProvider).pauseLocally(order.externalCode);
    if (context.mounted) {
      res.isSuccess
          ? showSapToast(context, 'OdL in pausa — riprendi quando pronto')
          : showSapToast(context, 'Errore pausa', isError: true);
    }
  }

  Future<void> _resumeFromPause(BuildContext context, WidgetRef ref) async {
    final res = await ref.read(workOrderActionsProvider).resumeFromPause(order.externalCode);
    if (context.mounted) {
      res.isSuccess
          ? showSapToast(context, 'OdL ripreso')
          : showSapToast(context, 'Errore ripresa pausa', isError: true);
    }
  }

  Future<void> _suspend(BuildContext context, WidgetRef ref) async {
    final result = await showModalBottomSheet<({String motivo, String note})>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _SospendiSheet(),
    );
    if (result != null && context.mounted) {
      final geo = await GeolocationService.instance.getCurrentPosition();
      final res = await ref.read(workOrderActionsProvider).changeStatus(
            order.externalCode,
            WorkOrderStatus.sospeso,
            reason: result.motivo,
            note: result.note,
            geolocation: geo,
          );
      if (context.mounted) {
        if (res.isSuccess) {
          showSapToast(context, 'OdL sospeso — restituito al Cruscotto');
          context.pop(); // rimuove dal tablet e torna alla lista
        } else {
          showSapToast(context, 'Errore sospensione', isError: true);
        }
      }
    }
  }
}

class _SospendiSheet extends StatefulWidget {
  const _SospendiSheet();
  @override
  State<_SospendiSheet> createState() => _SospendiSheetState();
}

class _SospendiSheetState extends State<_SospendiSheet> {
  String _motivo = 'Cliente assente';
  final _noteCtrl = TextEditingController();

  static const _motivi = [
    'Cliente assente',
    'Materiale mancante',
    'Accesso impossibile',
    'Condizioni meteo',
    'Problema tecnico',
    'Altro',
  ];

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sospendi OdL', style: AppTextStyles.headingMedium),
          const SizedBox(height: 4),
          const Text(
            'L\'OdL verrà restituito al Cruscotto e rimosso dal tuo tablet.',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _motivo,
            decoration: const InputDecoration(labelText: 'Motivo sospensione'),
            items: _motivi
                .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                .toList(),
            onChanged: (v) => setState(() => _motivo = v ?? _motivo),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteCtrl,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Note (facoltative)'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(
                  context, (motivo: _motivo, note: _noteCtrl.text)),
              child: const Text('Conferma sospensione'),
            ),
          ),
        ],
      ),
    );
  }
}
