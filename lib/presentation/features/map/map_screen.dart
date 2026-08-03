// Mappa — visualizza gli OdL geolocalizzati con marker colorati in base allo stato.

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
import '../../providers/map_provider.dart';

// ─── Colori dei marker ────────────────────────────────────────

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
  MapPoint? _selected;
  WorkOrderStatus? _filterStatus;

  // Centro di default — Ancona (zone des ODL de démo)
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
    final pointsAsync = ref.watch(mapPointsProvider);
    final senzaPosizione = ref.watch(mapMissingCountProvider).valueOrNull ?? 0;

    return Scaffold(
      backgroundColor: AppColors.backgroundPage,
      appBar: AppBar(
        title: const Text('Mappa interventi'),
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
          // Legenda + filtro stato
          _StatusLegendBar(
            selected: _filterStatus,
            onSelect: (s) => setState(() {
              _filterStatus = _filterStatus == s ? null : s;
              _selected = null;
            }),
          ),
          Expanded(
            child: pointsAsync.when(
              loading: () => const WfmLoading(
                  message: 'Localizzazione degli indirizzi di intervento…'),
              error: (e, _) => WfmErrorState(
                message: e.toString(),
                onRetry: () => ref.invalidate(mapPointsProvider),
              ),
              data: (points) {
                // Il filtro per stato riguarda gli ordini; con un filtro
                // attivo gli avvisi (che non hanno stato OdL) restano fuori.
                final geo = points
                    .where((p) =>
                        _filterStatus == null ||
                        (!p.isAvviso && p.stato == _filterStatus))
                    .toList();

                return Stack(
                  children: [
                    // ── Mappa ────────────────────────────────────────────────
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

                    // ── Contatore oggetti visibili ─────────────────────────
                    Positioned(
                      top: 12,
                      right: 12,
                      child: _CountBubble(
                          count: geo.length, senzaPosizione: senzaPosizione),
                    ),

                    // Dettaglio dell'oggetto selezionato.
                    if (_selected != null)
                      Positioned(
                        bottom: 16,
                        left: 12,
                        right: 12,
                        child: _PointBottomCard(
                          point: _selected!,
                          onClose: () => setState(() => _selected = null),
                          onOpen: () => context.push(
                            _selected!.isAvviso
                                ? AppRoutes.avvisoDetailPath(_selected!.id)
                                : AppRoutes.workOrderDetailPath(_selected!.id),
                          ),
                        ),
                      ),

                    // ── Messaggio nessun OdL geolocalizzato ────────────────────────
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
                              const Text('Nessun intervento sulla mappa',
                                  style: AppTextStyles.headingSmall),
                              const SizedBox(height: 4),
                              Text(
                                _filterStatus != null
                                    ? 'Nessun OdL "${_filterStatus!.label}" con un indirizzo localizzabile.'
                                    : 'Gli oggetti senza indirizzo di intervento non possono essere posizionati.',
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

  Marker _buildMarker(MapPoint point) {
    // Gli avvisi hanno un colore proprio: sulla mappa si distinguono subito
    // dagli ordini, che restano colorati per stato.
    final color = point.isAvviso
        ? AppColors.accentOrange
        : _markerColor(point.stato ?? WorkOrderStatus.ricevuto);
    final icon = point.isAvviso
        ? Icons.notifications_rounded
        : _markerIcon(point.stato ?? WorkOrderStatus.ricevuto);
    final isSelected = _selected?.id == point.id;

    return Marker(
      point: LatLng(point.latitude, point.longitude),
      width: isSelected ? 52 : 44,
      height: isSelected ? 52 : 44,
      child: GestureDetector(
        onTap: () => setState(() => _selected = point),
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

// ─── Barra legenda / filtro stato ───────────────────────────────────────────

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

// contatore OdL

class _CountBubble extends StatelessWidget {
  final int count;

  /// Oggetti che non è stato possibile posizionare: dichiararlo evita di far
  /// credere che sulla mappa ci sia tutto.
  final int senzaPosizione;

  const _CountBubble({required this.count, this.senzaPosizione = 0});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
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
            '$count sulla mappa',
            style: const TextStyle(
                color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        if (senzaPosizione > 0) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              '$senzaPosizione senza indirizzo',
              style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ],
    );
  }
}

// ODL carta base

class _PointBottomCard extends StatelessWidget {
  final MapPoint point;
  final VoidCallback onClose;
  final VoidCallback onOpen;

  const _PointBottomCard(
      {required this.point, required this.onClose, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final color = point.isAvviso
        ? AppColors.accentOrange
        : _markerColor(point.stato ?? WorkOrderStatus.ricevuto);

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
                    point.isAvviso
                        ? 'AVVISO'
                        : (point.stato?.label ?? 'ORDINE'),
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: color),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  point.id,
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
              point.titolo,
              style: AppTextStyles.headingSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            // Indirizzo di intervento: è quello su cui il marker è posizionato.
            Row(
              children: [
                const Icon(Icons.place_outlined,
                    size: 14, color: AppColors.textHint),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    point.indirizzo,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium,
                  ),
                ),
              ],
            ),
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
