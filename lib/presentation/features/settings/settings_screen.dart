// Impostazioni locali.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
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
    final config = ref.watch(appConfigProvider);

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
            ]),
          ),
          const SectionHeader(title: 'STRUTTURA ORGANIZZATIVA'),
          WfmCard(
            child: Column(children: [
              _info('Centro di Lavoro', user?.workCenter.isNotEmpty == true ? user!.workCenter : '—'),
              _info('Squadra', user?.squadra ?? '—'),
              _info('Tecnico VV', user?.tecnicoVV ?? '—'),
            ]),
          ),
          const SectionHeader(title: 'SESSIONE'),
          WfmCard(
            child: Column(children: [
              _info('Utente', user?.fullName ?? '—'),
              _info('CID', user?.cid ?? '—'),
              _info('Ruolo', user?.role.label ?? '—'),
              _info('Ambiente', config.flavor.name.toUpperCase()),
              _info('Sorgente dati', config.useMockData ? 'Mock' : 'Middleware'),
              _info('Versione', 'WFM Mobile v1.0.0'),
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
