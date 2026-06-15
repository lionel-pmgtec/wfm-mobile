// Page Carte — affiche les ODL géolocalisés avec marqueurs colorés par statut.

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/services/geolocation_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';
import '../../providers/work_orders_provider.dart';

// ─── Couleurs des marqueurs par statut ───────────────────────────────────────

Color _markerColor(WorkOrderStatus s) => switch (s) {
      WorkOrderStatus.ricevuto => AppColors.statusReceived,
      WorkOrderStatus.inEsecuzione => AppColors.statusInProgress,
      WorkOrderStatus.inPausa => AppColors.accentOrange,
      WorkOrderStatus.sospeso => AppColors.statusSuspended,
      WorkOrderStatus.completato => AppColors.statusDone,
      WorkOrderStatus.annullato => AppColors.textHint,
      WorkOrderStatus.inviatoSAP => const Color(0xFF00897B),
    };

IconData _markerIcon(WorkOrderStatus s) => switch (s) {
      WorkOrderStatus.ricevuto => Icons.inbox_rounded,
      WorkOrderStatus.inEsecuzione => Icons.play_circle_filled,
      WorkOrderStatus.inPausa => Icons.pause_circle_filled,
      WorkOrderStatus.sospeso => Icons.stop_circle,
      WorkOrderStatus.completato => Icons.check_circle,
      WorkOrderStatus.annullato => Icons.cancel,
      WorkOrderStatus.inviatoSAP => Icons.send_rounded,
    };

// ─── Screen ──────────────────────────────────────────────────────────────────

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _mapController = MapController();
  WorkOrder? _selected;
  WorkOrderStatus? _filterStatus;

  // Centro par défaut — Ancona (zone des ODL de démo)
  static const _defaultCenter = LatLng(43.615, 13.519);

  Future<void> _centerOnMyLocation() async {
    final pos = await GeolocationService.instance.getCurrentPosition();
    if (!mounted) return;
    if (pos != null) {
      _mapController.move(LatLng(pos.latitude, pos.longitude), 16);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Posizione non disponibile (GPS off o permesso negato)'),
      ));
      _mapController.move(_defaultCenter, 13);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(workOrdersProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundPage,
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Mappa OdL'),
        actions: [
          IconButton(
            tooltip: 'Centra sulla mia posizione',
            icon: const Icon(Icons.my_location_rounded),
            onPressed: _centerOnMyLocation,
          ),
        ],
      ),
      body: Column(
        children: [
          // Légende + filtre statut
          _StatusLegendBar(
            selected: _filterStatus,
            onSelect: (s) => setState(() {
              _filterStatus = _filterStatus == s ? null : s;
              _selected = null;
            }),
          ),
          Expanded(
            child: ordersAsync.when(
              loading: () => const WfmLoading(message: 'Caricamento OdL…'),
              error: (e, _) => WfmErrorState(
                message: e.toString(),
                onRetry: () => ref.invalidate(workOrdersProvider),
              ),
              data: (orders) {
                final geo = orders
                    .where((o) =>
                        o.address.hasCoordinates &&
                        (_filterStatus == null || o.status == _filterStatus))
                    .toList();

                return Stack(
                  children: [
                    // ── Carte ────────────────────────────────────────────────
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _defaultCenter,
                        initialZoom: 13,
                        onTap: (_, __) => setState(() => _selected = null),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.syclo.wfm_mobile',
                        ),
                        MarkerLayer(
                          markers: geo.map((o) => _buildMarker(o)).toList(),
                        ),
                      ],
                    ),

                    // ── Compteur ODL visibles ────────────────────────────────
                    Positioned(
                      top: 12,
                      right: 12,
                      child: _CountBubble(count: geo.length),
                    ),

                    // ── Fiche détail OdL sélectionné ─────────────────────────
                    if (_selected != null)
                      Positioned(
                        bottom: 16,
                        left: 12,
                        right: 12,
                        child: _OdlBottomCard(
                          order: _selected!,
                          onClose: () => setState(() => _selected = null),
                          onOpen: () => context.push(
                            AppRoutes.workOrderDetailPath(
                                _selected!.externalCode),
                          ),
                        ),
                      ),

                    // ── Message aucun OdL géolocalisé ────────────────────────
                    if (geo.isEmpty)
                      Center(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 32),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 12,
                              )
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.map_outlined,
                                  size: 48, color: AppColors.textHint),
                              const SizedBox(height: 12),
                              const Text('Nessun OdL geolocalizzato',
                                  style: AppTextStyles.headingSmall),
                              const SizedBox(height: 4),
                              Text(
                                _filterStatus != null
                                    ? 'Nessun OdL "${_filterStatus!.label}" con coordinate.'
                                    : 'Gli OdL senza coordinate non vengono visualizzati.',
                                style: AppTextStyles.bodyMedium,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Marker _buildMarker(WorkOrder order) {
    final color = _markerColor(order.status);
    final icon = _markerIcon(order.status);
    final isSelected = _selected?.externalCode == order.externalCode;

    return Marker(
      point: LatLng(order.address.latitude!, order.address.longitude!),
      width: isSelected ? 52 : 44,
      height: isSelected ? 52 : 44,
      child: GestureDetector(
        onTap: () => setState(() => _selected = order),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? Colors.white : color.withValues(alpha: 0.3),
              width: isSelected ? 3 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: isSelected ? 0.5 : 0.3),
                blurRadius: isSelected ? 14 : 6,
                spreadRadius: isSelected ? 2 : 0,
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: isSelected ? 26 : 22),
        ),
      ),
    );
  }
}

// ─── Barre légende / filtre statut ───────────────────────────────────────────

class _StatusLegendBar extends StatelessWidget {
  final WorkOrderStatus? selected;
  final ValueChanged<WorkOrderStatus> onSelect;

  const _StatusLegendBar({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final statuses = [
      WorkOrderStatus.ricevuto,
      WorkOrderStatus.inEsecuzione,
      WorkOrderStatus.sospeso,
      WorkOrderStatus.completato,
      WorkOrderStatus.annullato,
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.filter_list_rounded,
              size: 22, color: AppColors.textHint),
          const SizedBox(width: 10),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: statuses.map((s) {
                  final color = _markerColor(s);
                  final isSelected = selected == s;
                  return GestureDetector(
                    onTap: () => onSelect(s),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color.withValues(alpha: 0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isSelected ? color : AppColors.border,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                                color: color, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            s.label,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: isSelected ? color : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Bulle compteur ───────────────────────────────────────────────────────────

class _CountBubble extends StatelessWidget {
  final int count;
  const _CountBubble({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: Text(
        '$count OdL',
        style: const TextStyle(
            color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ─── Fiche OdL en bas de carte ────────────────────────────────────────────────

class _OdlBottomCard extends StatelessWidget {
  final WorkOrder order;
  final VoidCallback onClose;
  final VoidCallback onOpen;

  const _OdlBottomCard(
      {required this.order, required this.onClose, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final color = _markerColor(order.status);

    return Material(
      elevation: 12,
      borderRadius: BorderRadius.circular(20),
      shadowColor: Colors.black26,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border(left: BorderSide(color: color, width: 4)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    order.status.label,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: color),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  order.externalCode,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary),
                ),
                const Spacer(),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  color: AppColors.textHint,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              order.woTypeDescription.isNotEmpty
                  ? order.woTypeDescription
                  : order.woType,
              style: AppTextStyles.headingSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.place_outlined,
                    size: 14, color: AppColors.textHint),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    order.address.full,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium,
                  ),
                ),
              ],
            ),
            if (order.customer.fullName.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.person_outline_rounded,
                      size: 14, color: AppColors.textHint),
                  const SizedBox(width: 4),
                  Text(order.customer.fullName,
                      style: AppTextStyles.bodyMedium),
                ],
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('Apri dettaglio'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
