// Menu modulo Standalone : 4 voci principali.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';

class StandaloneMenuScreen extends StatelessWidget {
  const StandaloneMenuScreen({super.key});

  static const _items = [
    _MenuItem(
      icon: Icons.precision_manufacturing_outlined,
      label: 'Dettaglio Equipment',
      subtitle: 'Ricerca e dettaglio di un equipment per barcode/matricola',
      route: AppRoutes.standaloneEquipment,
      color: AppColors.primary,
    ),
    _MenuItem(
      icon: Icons.qr_code_2_rounded,
      label: 'Sostituzione Barcode',
      subtitle: 'Sostituisci il barcode di un equipment esistente',
      route: AppRoutes.standaloneSostBarcode,
      color: Color(0xFF6A1B9A),
    ),
    _MenuItem(
      icon: Icons.directions_car_filled_outlined,
      label: 'Gestione Squadra / Magazzino',
      subtitle: 'Targhe veicoli, stock di squadra e membri',
      route: AppRoutes.standaloneSquadra,
      color: AppColors.accentGreen,
    ),
    _MenuItem(
      icon: Icons.copy_all_outlined,
      label: 'Template Work Order',
      subtitle: 'Modelli di OdL riutilizzabili',
      route: AppRoutes.standaloneTemplates,
      color: AppColors.accentOrange,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Standalone')),
      body: ListView.separated(
        padding: kPagePadding,
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final it = _items[i];
          return WfmCard(
            onTap: () => context.push(it.route),
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: it.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(it.icon, color: it.color, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(it.label, style: AppTextStyles.headingSmall),
                    const SizedBox(height: 2),
                    Text(it.subtitle,
                        style: AppTextStyles.bodyMedium, maxLines: 2),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textHint),
            ]),
          );
        },
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String label;
  final String subtitle;
  final String route;
  final Color color;
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.route,
    required this.color,
  });
}
