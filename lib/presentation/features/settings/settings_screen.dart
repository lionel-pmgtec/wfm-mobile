// Impostazioni locali.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/services/excel_export_service.dart';
import '../../../core/services/lettura_vocale_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';
import '../../../domain/repositories/work_order_repository.dart';
import '../../providers/auth_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final ctrl = ref.read(settingsProvider.notifier);
    final user = ref.watch(authControllerProvider.notifier).user;
    final online = ref.watch(connectivityStatusProvider);
    final pending = ref.watch(pendingSyncCountProvider).valueOrNull ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Impostazioni')),
      body: ListView(
        padding: kPagePadding,
        children: [
          const SectionHeader(title: 'CONNESSIONE'),
          WfmCard(
            child: Column(children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: Icon(online ? Icons.wifi : Icons.wifi_off,
                    color: online ? AppColors.accentGreen : AppColors.accentOrange),
                title: const Text('Modalità online'),
                subtitle: Text(online
                    ? 'Connesso al middleware'
                    : 'Offline — i dati restano locali'),
                value: online,
                onChanged: (_) =>
                    ref.read(connectivityStatusProvider.notifier).toggle(),
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.sync),
                title: const Text('Coda di sincronizzazione'),
                trailing: Badge(
                  isLabelVisible: pending > 0,
                  label: Text('$pending'),
                  child: const Icon(Icons.chevron_right),
                ),
                onTap: () => context.push(AppRoutes.syncQueue),
              ),
            ]),
          ),
          const SectionHeader(title: 'PREFERENZE'),
          WfmCard(
            child: Column(children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.timer_outlined),
                title: const Text('Frequenza sincronizzazione'),
                trailing: DropdownButton<int>(
                  value: settings.syncIntervalMinutes,
                  underline: const SizedBox.shrink(),
                  items: const [5, 15, 30, 60]
                      .map((m) =>
                          DropdownMenuItem(value: m, child: Text('$m min')))
                      .toList(),
                  onChanged: (v) => ctrl.setSyncInterval(v ?? 15),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.photo_size_select_large_outlined),
                title: const Text('Qualità foto'),
                trailing: DropdownButton<String>(
                  value: settings.photoQuality,
                  underline: const SizedBox.shrink(),
                  items: const ['alta', 'media', 'bassa']
                      .map((q) => DropdownMenuItem(value: q, child: Text(q)))
                      .toList(),
                  onChanged: (v) => ctrl.setPhotoQuality(v ?? 'media'),
                ),
              ),
              const Divider(height: 1),
              _ScaleTile(
                icon: Icons.format_size,
                title: 'Dimensione testo',
                scale: settings.textScale,
                onDecrease: ctrl.decreaseTextScale,
                onIncrease: ctrl.increaseTextScale,
                onReset: ctrl.resetTextScale,
              ),
              const Divider(height: 1),
              _ScaleTile(
                icon: Icons.image_aspect_ratio_outlined,
                title: 'Dimensione icone',
                scale: settings.iconScale,
                onDecrease: ctrl.decreaseIconScale,
                onIncrease: ctrl.increaseIconScale,
                onReset: ctrl.resetIconScale,
              ),
            ]),
          ),
          const SectionHeader(title: 'VOCE DI LETTURA'),
          WfmCard(child: _VoceLettura(settings: settings, ctrl: ctrl)),
          const SectionHeader(title: 'STRUTTURA ORGANIZZATIVA'),
          WfmCard(
            child: Column(children: [
              _info('Centro di Lavoro', user?.workCenter.isNotEmpty == true ? user!.workCenter : '—'),
              _info('Squadra', user?.squadra ?? '—'),
              _info('Tecnico', user?.tecnicoVV ?? '—'),
            ]),
          ),
          const SectionHeader(title: 'DATI (TEST)'),
          WfmCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.table_view_outlined,
                  color: AppColors.primary),
              title: const Text('Esporta database (Excel)'),
              subtitle: const Text(
                  'Salva OdL, avvisi e preventivi in un file .xlsx per verifica'),
              trailing: const Icon(Icons.download_rounded),
              onTap: () => _exportExcel(context, ref),
            ),
          ),
          const SectionHeader(title: 'SESSIONE'),
          WfmCard(
            child: Column(children: [
              _info('Utente', user?.fullName ?? '—'),
              _info('CID', user?.cid ?? '—'),
              _info('Ruolo', user?.role.label ?? '—'),
              _info('Ultima sincr.', Fmt.dateTime(DateTime.now())),
            ]),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => showSapToast(context, 'Cache locale cancellata'),
            icon: const Icon(Icons.delete_sweep_outlined),
            label: const Text('Cancella cache'),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentRed),
            onPressed: () async {
              await ref.read(authControllerProvider.notifier).logout();
              if (context.mounted) context.go(AppRoutes.login);
            },
            icon: const Icon(Icons.logout),
            label: const Text('Esci'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _exportExcel(BuildContext context, WidgetRef ref) async {
    showSapToast(context, 'Esportazione in corso…');
    try {
      final woRes = await ref
          .read(workOrderRepositoryProvider)
          .getWorkOrders(filter: const WorkOrderFilter());
      final avRes =
          await ref.read(notificationRepositoryProvider).getAvvisi();
      final extRepo = ref.read(avvisoExtensionRepositoryProvider);
      final keys = await extRepo.savedAvvisi();
      final exts = <AvvisoExtension>[];
      for (final k in keys) {
        exts.add(await extRepo.get(k));
      }
      final dest = await ExcelExportService.instance.exportDatabase(
        ordini: woRes.valueOrNull ?? const [],
        avvisi: avRes.valueOrNull ?? const [],
        extensions: exts,
      );
      if (!context.mounted) return;
      showSapToast(context, 'Database esportato: $dest');
    } catch (e) {
      if (!context.mounted) return;
      showSapToast(context, 'Errore export: $e', isError: true);
    }
  }

  Widget _info(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Text(label, style: AppTextStyles.bodyMedium),
          const Spacer(),
          Text(value,
              style: AppTextStyles.bodyLarge
                  .copyWith(fontWeight: FontWeight.w600)),
        ]),
      );
}

/// Controllo generico per aumentare/diminuire un fattore di scala (testo/icone).
class _ScaleTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final double scale;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final VoidCallback onReset;
  const _ScaleTile({
    required this.icon,
    required this.title,
    required this.scale,
    required this.onDecrease,
    required this.onIncrease,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final atMin = scale <= AppSettings.minScale + 0.001;
    final atMax = scale >= AppSettings.maxScale - 0.001;
    final isDefault = (scale - 1.0).abs() < 0.001;
    final percent = '${(scale * 100).round()}%';

    // Layout su due righe: l'etichetta occupa tutta la larghezza (niente più
    // testo spezzato lettera per lettera), i controlli stanno sotto.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: AppTextStyles.bodyLarge),
                    Text(
                      isDefault
                          ? 'Predefinita ($percent)'
                          : 'Personalizzata ($percent)',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              IconButton(
                tooltip: 'Diminuisci',
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: atMin ? null : onDecrease,
              ),
              Expanded(
                child: Text(
                  percent,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                  style: AppTextStyles.bodyLarge
                      .copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: 'Aumenta',
                icon: const Icon(Icons.add_circle_outline),
                onPressed: atMax ? null : onIncrease,
              ),
              IconButton(
                tooltip: 'Ripristina',
                icon: const Icon(Icons.restart_alt),
                onPressed: isDefault ? null : onReset,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Voce dell'altoparlante ("Leggi a voce alta") dei campi di testo: quale voce
/// italiana del tablet, più grave o più acuta, più lenta o più veloce.
class _VoceLettura extends StatefulWidget {
  final AppSettings settings;
  final SettingsController ctrl;
  const _VoceLettura({required this.settings, required this.ctrl});

  @override
  State<_VoceLettura> createState() => _VoceLetturaState();
}

class _VoceLetturaState extends State<_VoceLettura> {
  late final Future<List<VoceDisponibile>> _voci =
      LetturaVocale.instance.vociItaliane();

  Future<void> _prova() async {
    final s = widget.settings;
    final tts = LetturaVocale.instance;
    await tts.ferma();
    await tts.applica(
        voce: s.voceLettura, tono: s.vocePitch, velocita: s.voceVelocita);
    try {
      await tts.parla(LetturaVocale.fraseProva);
    } catch (_) {/* nessun motore vocale: niente da fare */}
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    final ctrl = widget.ctrl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FutureBuilder<List<VoceDisponibile>>(
          future: _voci,
          builder: (context, snap) {
            final voci = snap.data ?? const <VoceDisponibile>[];
            // Una voce salvata ma non più installata: si torna alla predefinita.
            final scelta = voci.any((v) => v.nome == s.voceLettura)
                ? s.voceLettura
                : '';
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.record_voice_over_outlined),
              title: const Text('Voce'),
              subtitle: Text(
                snap.connectionState != ConnectionState.done
                    ? 'Ricerca delle voci installate…'
                    : voci.isEmpty
                        ? 'Nessuna voce italiana trovata sul dispositivo'
                        : '${voci.length} voci italiane installate',
              ),
              trailing: voci.isEmpty
                  ? null
                  : DropdownButton<String>(
                      value: scelta,
                      underline: const SizedBox.shrink(),
                      items: [
                        const DropdownMenuItem(
                            value: '', child: Text('Predefinita')),
                        for (var i = 0; i < voci.length; i++)
                          DropdownMenuItem(
                              value: voci[i].nome,
                              child: Text('Voce ${i + 1} · ${voci[i].nome}',
                                  overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (v) => ctrl.setVoceLettura(v ?? ''),
                    ),
            );
          },
        ),
        const Divider(height: 1),
        _Regolatore(
          icon: Icons.graphic_eq,
          titolo: 'Tono',
          minEtichetta: 'Grave',
          maxEtichetta: 'Acuto',
          valore: s.vocePitch,
          min: AppSettings.minPitch,
          max: AppSettings.maxPitch,
          onChanged: ctrl.setVocePitch,
        ),
        _Regolatore(
          icon: Icons.speed,
          titolo: 'Velocità',
          minEtichetta: 'Lenta',
          maxEtichetta: 'Veloce',
          valore: s.voceVelocita,
          min: AppSettings.minVelocita,
          max: AppSettings.maxVelocita,
          onChanged: ctrl.setVoceVelocita,
        ),
        const SizedBox(height: 4),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _prova,
              icon: const Icon(Icons.volume_up_outlined),
              label: const Text('Prova la voce'),
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: ctrl.ripristinaVoce,
            child: const Text('Ripristina'),
          ),
        ]),
      ],
    );
  }
}

class _Regolatore extends StatelessWidget {
  final IconData icon;
  final String titolo;
  final String minEtichetta;
  final String maxEtichetta;
  final double valore;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  const _Regolatore({
    required this.icon,
    required this.titolo,
    required this.minEtichetta,
    required this.maxEtichetta,
    required this.valore,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon),
            const SizedBox(width: 16),
            Text(titolo, style: AppTextStyles.bodyLarge),
          ]),
          Row(children: [
            Text(minEtichetta, style: AppTextStyles.bodyMedium),
            Expanded(
              child: Slider(
                value: valore.clamp(min, max).toDouble(),
                min: min,
                max: max,
                divisions: 10,
                semanticFormatterCallback: (v) => '$titolo ${v.toStringAsFixed(1)}',
                onChanged: onChanged,
              ),
            ),
            Text(maxEtichetta, style: AppTextStyles.bodyMedium),
          ]),
        ]),
      );
}
