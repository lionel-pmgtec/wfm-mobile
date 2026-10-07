// Mappa — ordini e avvisi del tecnico su fondo ArcGIS (Esri).
//
// Fondo: i servizi pubblici di mappa di base Esri (services.arcgisonline.com):
// chiaro, stradale, topografico o satellitare. Colori, forme e legenda sono
// quelli della mappa del cruscotto: colore = stato, cerchio = ordine, quadrato
// = avviso, bordo tratteggiato = posizione ricavata dall'indirizzo.
//
// Interfaccia: mappa a tutto schermo, ricerca di indirizzi/interventi in alto,
// filtro per stato, comandi flottanti (fondo, posizione, inquadra tutto,
// zoom), segnaposto vicini raggruppati, scala, elenco degli interventi in un
// pannello che si trascina dal basso.
//
// Rete Viva Servizi (contatori, riduttori): livelli ArcGIS protetti, attivi
// solo se l'app è compilata con --dart-define=ARCGIS_TOKEN=... Senza token
// restano spenti nel pannello "Fondo mappa" e non si mostra nessun punto.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../../../core/config/rete_arcgis_config.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/services/geolocation_service.dart';
import '../../../core/services/navigazione_service.dart';
import '../../../core/services/rete_arcgis_service.dart';
import '../../../core/services/rete_viva_service.dart';
import '../../../core/services/ricerca_indirizzi_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/entities/entities.dart';
import '../../providers/map_provider.dart';

// ─── Fondo mappa ArcGIS ──────────────────────────────────────────────────────

/// Mappe di base Esri (pubbliche, Web Mercator come flutter_map).
enum FondoMappa {
  chiaro('Chiaro', Icons.layers_clear_outlined),
  stradale('Stradale', Icons.map_outlined),
  topografico('Topografico', Icons.terrain_outlined),
  satellite('Satellite', Icons.satellite_alt_outlined);

  final String label;
  final IconData icona;
  const FondoMappa(this.label, this.icona);
}

const _arcgis = 'https://services.arcgisonline.com/ArcGIS/rest/services';

/// URL delle tessere: nei servizi ArcGIS l'ordine è {z}/{y}/{x}.
String urlTessere(String servizio) =>
    '$_arcgis/$servizio/MapServer/tile/{z}/{y}/{x}';

TileLayer _tessere(String servizio, {int maxNativeZoom = 19}) => TileLayer(
      urlTemplate: urlTessere(servizio),
      userAgentPackageName: 'com.syclo.wfm_mobile',
      // Oltre questo livello Esri non ha dati: si ingrandisce l'ultimo.
      maxNativeZoom: maxNativeZoom,
    );

List<Widget> _strati(FondoMappa fondo) => switch (fondo) {
      // Grigio chiaro: i segnaposto colorati risaltano. Dati fino al 16.
      FondoMappa.chiaro => [
          _tessere('Canvas/World_Light_Gray_Base', maxNativeZoom: 16),
          _tessere('Canvas/World_Light_Gray_Reference', maxNativeZoom: 16),
        ],
      FondoMappa.stradale => [_tessere('World_Street_Map')],
      FondoMappa.topografico => [_tessere('World_Topo_Map')],
      // Satellite + vie e nomi in trasparenza, altrimenti non ci si orienta.
      FondoMappa.satellite => [
          _tessere('World_Imagery'),
          _tessere('Reference/World_Transportation'),
          _tessere('Reference/World_Boundaries_and_Places'),
        ],
    };

// ─── Icone dei segnaposto ────────────────────────────────────────────────────

IconData _icona(MapPoint p) {
  if (p.isAvviso) return Icons.notifications_rounded;
  return switch (p.stato) {
    WorkOrderStatus.inPausa => Icons.pause_rounded,
    WorkOrderStatus.inEsecuzione => Icons.play_arrow_rounded,
    WorkOrderStatus.sospeso => Icons.stop_rounded,
    WorkOrderStatus.completato => Icons.check_rounded,
    _ => Icons.assignment_outlined,
  };
}

const _distanza = Distance();

String _fmtDistanza(double metri) => metri < 1000
    ? '${metri.round()} m'
    : '${(metri / 1000).toStringAsFixed(metri < 10000 ? 1 : 0)} km';

// ─── Screen ──────────────────────────────────────────────────────────────────

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _mapController = MapController();
  MapPoint? _selected;
  StatoMappa? _filtro;
  FondoMappa _fondo = FondoMappa.chiaro;
  LatLng? _miaPosizione;
  bool _legendaAperta = false;

  // Contatori degli interventi (dal backend), visibili da vicino.
  bool _mostraContatori = true;
  bool _vicino = false;

  // Rete Viva Servizi (condotte, allacci, contatori, riduttori).
  bool _mostraReteViva = true;
  bool _vicinoRete = false; // zoom >= 16: si disegna la rete
  bool _etichette = false; // zoom >= 17: materiali e codici
  ContatoreMappa? _contatoreSel;

  // Punto scelto (pressione prolungata o ricerca) e il suo indirizzo.
  LatLng? _puntoScelto;
  IndirizzoPunto? _indirizzoPunto;
  bool _cercaIndirizzo = false;

  // Rete Viva Servizi (ArcGIS): accesa di default solo se c'è il token.
  late Set<StratoRete> _stratiRete =
      ref.read(reteArcgisProvider).attivo ? StratoRete.values.toSet() : {};
  List<ElementoRete> _rete = const [];
  ElementoRete? _elementoSel;
  String? _erroreRete;
  bool _reteTroppoLontana = false;
  bool _caricamentoRete = false;
  Timer? _attesaRete;
  int _richiestaRete = 0;

  @override
  void dispose() {
    _attesaRete?.cancel();
    super.dispose();
  }

  /// Ricarica la rete sulla zona visibile quando la mappa si ferma.
  void _pianificaRete() {
    if (!ref.read(reteArcgisProvider).attivo) return;
    _attesaRete?.cancel();
    _attesaRete = Timer(const Duration(milliseconds: 500), _caricaRete);
  }

  Future<void> _caricaRete() async {
    if (!mounted) return;
    final servizio = ref.read(reteArcgisProvider);
    if (!servizio.attivo || _stratiRete.isEmpty) {
      setState(() {
        _rete = const [];
        _erroreRete = null;
        _reteTroppoLontana = false;
        _caricamentoRete = false;
      });
      return;
    }
    final MapCamera camera;
    try {
      camera = _mapController.camera;
    } catch (_) {
      return; // mappa non ancora pronta
    }
    if (camera.zoom < ReteArcgisConfig.zoomMinimo) {
      setState(() {
        _rete = const [];
        _reteTroppoLontana = true;
        _caricamentoRete = false;
      });
      return;
    }
    final b = camera.visibleBounds;
    final richiesta = ++_richiestaRete;
    setState(() {
      _reteTroppoLontana = false;
      _caricamentoRete = true;
    });
    try {
      final risultati = await Future.wait([
        for (final s in _stratiRete)
          servizio.nellaZona(s,
              sud: b.south, ovest: b.west, nord: b.north, est: b.east),
      ]);
      if (!mounted || richiesta != _richiestaRete) return;
      setState(() {
        _rete = [for (final r in risultati) ...r];
        _erroreRete = null;
        _caricamentoRete = false;
      });
    } catch (e) {
      if (!mounted || richiesta != _richiestaRete) return;
      setState(() {
        _rete = const [];
        _erroreRete = e is ReteNonAccessibile
            ? e.messaggio
            : 'Rete Viva Servizi non raggiungibile.';
        _caricamentoRete = false;
      });
    }
  }

  /// Crea OdL o avviso dal punto della rete, con posizione (e matricola, se
  /// il livello la porta) già compilate.
  void _creaDaRete(ElementoRete e, {required bool avviso}) {
    final i = indirizzoElemento(e);
    final ind = i == null
        ? null
        : IndirizzoMappa(
            // Riduttore all'incrocio "Via A / Via B": si usa la prima via.
            via: i.via.split(' / ').first,
            civico: i.civico,
            comune: i.comune,
            cap: i.cap);
    final String path;
    if (avviso) {
      path = AppRoutes.createAvvisoDaMappaPath(
          matricola: e.matricola, lat: e.lat, lng: e.lng, indirizzo: ind);
    } else if (e.strato == StratoRete.riduttori) {
      // Riduttore di pressione: ZA02 col ciclo CONRID1 (catalogo del backend).
      path = AppRoutes.createOrderDaMappaPath(
          woType: 'ZA02',
          lat: e.lat,
          lng: e.lng,
          ciclo: 'CONRID1',
          indirizzo: ind);
    } else {
      // Contatore: la sostituzione (SOST) è l'OdL legato alla matricola.
      path = AppRoutes.createOrderDaMappaPath(
          woType: 'SOST',
          matricola: e.matricola,
          lat: e.lat,
          lng: e.lng,
          indirizzo: ind);
    }
    context.push(path);
  }

  /// Crea dal contatore di un intervento: SOST con la matricola (la "casetta"
  /// del modulo completa contatore, cliente e sede dal backend) o avviso.
  void _creaDaContatore(ContatoreMappa c, {required bool avviso}) {
    final ind = _indirizzoDa(c.address);
    context.push(avviso
        ? AppRoutes.createAvvisoDaMappaPath(
            matricola: c.matricola,
            lat: c.latitude,
            lng: c.longitude,
            indirizzo: ind)
        : AppRoutes.createOrderDaMappaPath(
            woType: 'SOST',
            matricola: c.matricola,
            lat: c.latitude,
            lng: c.longitude,
            indirizzo: ind));
  }

  /// Crea dal punto scelto: posizione e indirizzo del punto, tipo da scegliere.
  void _creaDaPunto({required bool avviso}) {
    final p = _puntoScelto!;
    final ind = _indirizzoPunto?.indirizzo;
    context.push(avviso
        ? AppRoutes.createAvvisoDaMappaPath(
            lat: p.latitude, lng: p.longitude, indirizzo: ind)
        : AppRoutes.createOrderDaMappaPath(
            lat: p.latitude, lng: p.longitude, indirizzo: ind));
  }

  static IndirizzoMappa? _indirizzoDa(Address? a) {
    if (a == null) return null;
    final i = IndirizzoMappa(
        via: a.street,
        civico: a.streetNumber,
        comune: a.city.isNotEmpty ? a.city : a.localita,
        cap: a.cap);
    return i.isEmpty ? null : i;
  }

  /// Pressione prolungata (o risultato di ricerca): il punto diventa la base
  /// per un OdL o un avviso, con l'indirizzo reale del punto (Esri).
  Future<void> _scegliPunto(LatLng p) async {
    setState(() {
      _puntoScelto = p;
      _indirizzoPunto = null;
      _cercaIndirizzo = true;
      _selected = null;
      _elementoSel = null;
      _contatoreSel = null;
      _legendaAperta = false;
    });
    final ind =
        await ref.read(ricercaIndirizziProvider).indirizzoDi(p.latitude, p.longitude);
    if (!mounted || _puntoScelto != p) return;
    setState(() {
      _indirizzoPunto = ind;
      _cercaIndirizzo = false;
    });
  }

  /// Porta la mappa sulla rete Viva (centro dei suoi contatori), altrimenti
  /// sul primo intervento, abbastanza vicino da vederla.
  void _vaiAllaRete(ReteViva rete, List<MapPoint> interventi) {
    if (!rete.isEmpty && rete.contatori.isNotEmpty) {
      final n = rete.contatori.length;
      final lat = rete.contatori.fold<double>(0, (s, c) => s + c.lat) / n;
      final lng = rete.contatori.fold<double>(0, (s, c) => s + c.lng) / n;
      _vai(LatLng(lat, lng), zoom: 17);
    } else if (interventi.isNotEmpty) {
      _vai(LatLng(interventi.first.latitude, interventi.first.longitude));
    }
  }

  void _chiudiSchede() => setState(() {
        _selected = null;
        _elementoSel = null;
        _contatoreSel = null;
        _puntoScelto = null;
        _indirizzoPunto = null;
        _legendaAperta = false;
      });

  void _suSpostamento() {
    double zoom;
    try {
      zoom = _mapController.camera.zoom;
    } catch (_) {
      return;
    }
    final vicino = zoom >= _zoomContatori;
    final vicinoRete = zoom >= 16;
    final etichette = zoom >= 17;
    if (vicino != _vicino ||
        vicinoRete != _vicinoRete ||
        etichette != _etichette) {
      setState(() {
        _vicino = vicino;
        _vicinoRete = vicinoRete;
        _etichette = etichette;
      });
    }
    _pianificaRete();
  }

  /// Da questo zoom in su i contatori si vedono (come la rete sul GIS).
  static const double _zoomContatori = 15;

  Future<void> _navigaVerso(double lat, double lng) async {
    final ok = await NavigazioneService.apri(
        NavigazioneService.uriPercorso(lat: lat, lng: lng));
    if (!ok && mounted) {
      showSapToast(context, 'Nessuna app di navigazione disponibile',
          isError: true);
    }
  }

  // Centro di default — Ancona (zona degli OdL).
  static const _defaultCenter = LatLng(43.615, 13.519);

  void _vai(LatLng p, {double zoom = 17}) {
    try {
      _mapController.move(p, zoom);
    } catch (_) {
      // Mappa non ancora pronta: nessuno spostamento.
    }
  }

  Future<void> _centerOnMyLocation() async {
    final pos = await GeolocationService.instance.getCurrentPosition();
    if (!mounted) return;
    if (pos != null) {
      final p = LatLng(pos.latitude, pos.longitude);
      setState(() => _miaPosizione = p);
      _vai(p, zoom: 16);
    } else {
      showSapToast(
          context, 'Posizione non disponibile (GPS off o permesso negato)',
          isError: true);
    }
  }

  void _inquadraTutti(List<MapPoint> punti) {
    if (punti.isEmpty) return;
    final coords = [for (final p in punti) LatLng(p.latitude, p.longitude)];
    if (coords.length == 1) {
      _vai(coords.first, zoom: 16);
      return;
    }
    try {
      _mapController.fitCamera(CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(coords),
        padding: const EdgeInsets.fromLTRB(60, 140, 80, 160),
      ));
    } catch (_) {}
  }

  void _zoom(double delta) {
    try {
      final c = _mapController.camera;
      _mapController.move(c.center, (c.zoom + delta).clamp(3, 20).toDouble());
    } catch (_) {}
  }

  void _seleziona(MapPoint p) {
    setState(() {
      _selected = p;
      _elementoSel = null;
      _contatoreSel = null;
      _puntoScelto = null;
    });
    _vai(LatLng(p.latitude, p.longitude), zoom: 17);
  }

  Future<void> _naviga(MapPoint p) => _navigaVerso(p.latitude, p.longitude);

  Future<void> _scegliFondo() async {
    final scelto = await showModalBottomSheet<FondoMappa>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _SceltaFondo(
        attuale: _fondo,
        reteAttiva: ref.read(reteArcgisProvider).attivo,
        contatori: _mostraContatori,
        reteViva: _mostraReteViva,
        onReteViva: (v) => setState(() {
          _mostraReteViva = v;
          if (!v && _elementoSel != null && !ref.read(reteArcgisProvider).attivo) {
            _elementoSel = null;
          }
        }),
        onContatori: (v) => setState(() {
          _mostraContatori = v;
          if (!v) _contatoreSel = null;
        }),
        strati: _stratiRete,
        onStrati: (nuovi) {
          setState(() {
            _stratiRete = nuovi;
            if (_elementoSel != null &&
                !nuovi.contains(_elementoSel!.strato)) {
              _elementoSel = null;
            }
          });
          _caricaRete();
        },
      ),
    );
    if (scelto != null && mounted) setState(() => _fondo = scelto);
  }

  @override
  Widget build(BuildContext context) {
    final pointsAsync = ref.watch(mapPointsProvider);
    final senzaPosizione = ref.watch(mapMissingCountProvider).valueOrNull ?? 0;
    final punti = pointsAsync.valueOrNull ?? const <MapPoint>[];
    // Il filtro vale per ordini e avvisi, come sul cruscotto.
    final geo = punti
        .where((p) => _filtro == null || p.statoMappa == _filtro)
        .toList();
    final contatori = _mostraContatori
        ? ref.watch(contatoriMappaProvider).valueOrNull ??
            const <ContatoreMappa>[]
        : const <ContatoreMappa>[];
    final contatoriLontani = contatori.isNotEmpty && !_vicino;
    final reteViva = _mostraReteViva
        ? ref.watch(reteVivaProvider).valueOrNull ?? ReteViva.vuota
        : ReteViva.vuota;
    final reteVivaLontana = !reteViva.isEmpty && !_vicinoRete;
    final disegnaRete = !reteViva.isEmpty && _vicinoRete;

    return Scaffold(
      backgroundColor: AppColors.backgroundPage,
      appBar: AppBar(title: const Text('Mappa interventi')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _defaultCenter,
              initialZoom: 13,
              maxZoom: 20,
              onMapReady: _suSpostamento,
              onPositionChanged: (_, __) => _suSpostamento(),
              onTap: (_, __) => _chiudiSchede(),
              // Tieni premuto: OdL o avviso in quel punto.
              onLongPress: (_, p) => _scegliPunto(p),
            ),
            children: [
              ..._strati(_fondo),
              if (_puntoScelto != null)
                MarkerLayer(markers: [
                  Marker(
                    point: _puntoScelto!,
                    width: 40,
                    height: 40,
                    alignment: Alignment.topCenter,
                    child: const Icon(Icons.location_on_rounded,
                        size: 40, color: AppColors.primary),
                  ),
                ]),
              // Rete sotto gli interventi: i segnaposto restano in primo piano.
              if (_rete.isNotEmpty)
                MarkerLayer(markers: [
                  for (final e in _rete)
                    Marker(
                      key: ValueKey('rete-${e.id}'),
                      point: LatLng(e.lat, e.lng),
                      width: 40,
                      height: 40,
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _elementoSel = e;
                          _selected = null;
                          _contatoreSel = null;
                          _puntoScelto = null;
                        }),
                        child: PuntoRete(
                            strato: e.strato,
                            selezionato: _elementoSel?.id == e.id),
                      ),
                    ),
                ]),
              if (disegnaRete) ...[
                // Allacci: tratteggio rosa dal contatore alla condotta.
                PolylineLayer(polylines: [
                  for (final a in reteViva.allacci)
                    Polyline(
                      points: a,
                      strokeWidth: 1.2,
                      color: _coloreAllaccio,
                      pattern: StrokePattern.dashed(segments: const [5, 4]),
                    ),
                ]),
                PolylineLayer(polylines: [
                  for (final c in reteViva.condotte)
                    Polyline(
                      points: c.punti,
                      strokeWidth: c.adduzione ? 2.6 : 2.2,
                      color: c.adduzione ? _coloreAdduzione : _coloreDistribuzione,
                    ),
                ]),
                if (_etichette)
                  MarkerLayer(markers: [
                    for (final c in reteViva.condotte)
                      if (c.materiale.isNotEmpty)
                        Marker(
                          point: c.etichetta,
                          width: 120,
                          height: 16,
                          child: IgnorePointer(
                            child: Transform.rotate(
                              angle: c.angolo,
                              child: _EtichettaRete(
                                  testo: c.materiale,
                                  colore: c.adduzione
                                      ? const Color(0xFF1A237E)
                                      : const Color(0xFF1B5E20)),
                            ),
                          ),
                        ),
                    for (final r in reteViva.riduttori)
                      Marker(
                        point: LatLng(r.lat, r.lng),
                        width: 60,
                        height: 16,
                        alignment: const Alignment(0, -1.6),
                        child: IgnorePointer(
                          child: _EtichettaRete(
                              testo: '${r.attributi['Codice'] ?? ''}',
                              colore: Colors.black87),
                        ),
                      ),
                  ]),
                MarkerLayer(markers: [
                  for (final e in [...reteViva.contatori, ...reteViva.riduttori])
                    Marker(
                      key: ValueKey('viva-${e.id}'),
                      point: LatLng(e.lat, e.lng),
                      width: 40,
                      height: 40,
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _elementoSel = e;
                          _selected = null;
                          _contatoreSel = null;
                          _puntoScelto = null;
                        }),
                        child: PuntoRete(
                            strato: e.strato,
                            selezionato: _elementoSel?.id == e.id),
                      ),
                    ),
                ]),
              ],
              // Contatori degli interventi: stessa posizione dell'intervento,
              // disegnati accanto al suo segnaposto (le coordinate non cambiano).
              if (_vicino && contatori.isNotEmpty)
                MarkerLayer(markers: [
                  for (final c in contatori)
                    Marker(
                      key: ValueKey('contatore-${c.matricola}'),
                      point: LatLng(c.latitude, c.longitude),
                      width: 22,
                      height: 22,
                      alignment: const Alignment(2.4, 2.4),
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _contatoreSel = c;
                          _selected = null;
                          _elementoSel = null;
                          _puntoScelto = null;
                        }),
                        child: SimboloContatore(
                            selezionato:
                                _contatoreSel?.matricola == c.matricola),
                      ),
                    ),
                ]),
              if (_miaPosizione != null)
                MarkerLayer(markers: [
                  Marker(
                    point: _miaPosizione!,
                    width: 26,
                    height: 26,
                    child: const _MiaPosizione(),
                  ),
                ]),
              MarkerClusterLayerWidget(
                options: MarkerClusterLayerOptions(
                  markers: geo.map(_buildMarker).toList(),
                  maxClusterRadius: 45,
                  size: const Size(44, 44),
                  // Da vicino i segnaposto si vedono tutti.
                  disableClusteringAtZoom: 17,
                  // Il tocco lo gestisce il segnaposto stesso.
                  markerChildBehavior: true,
                  zoomToBoundsOnClick: true,
                  builder: (_, markers) => _Grappolo(count: markers.length),
                ),
              ),
              const Scalebar(
                alignment: Alignment.bottomLeft,
                padding: EdgeInsets.fromLTRB(12, 0, 0, 96),
                textStyle: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
                lineColor: AppColors.textSecondary,
              ),
              // Attribuzione obbligatoria per i servizi Esri.
              const SimpleAttributionWidget(
                source: Text('Esri, © OpenStreetMap contributors'),
                alignment: Alignment.bottomRight,
              ),
            ],
          ),

          // ── In alto: ricerca + filtro per stato ─────────────────────────
          Positioned(
            top: 12,
            left: 12,
            right: 76,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _BarraRicerca(
                  punti: punti,
                  vicinoA: _miaPosizione,
                  onIntervento: (p) {
                    FocusScope.of(context).unfocus();
                    _seleziona(p);
                  },
                  onLuogo: (l) {
                    FocusScope.of(context).unfocus();
                    final p = LatLng(l.lat, l.lng);
                    _scegliPunto(p);
                    _vai(p);
                  },
                ),
                const SizedBox(height: 8),
                _FiltroStati(
                  selezionato: _filtro,
                  onSelect: (s) => setState(() {
                    _filtro = _filtro == s ? null : s;
                    _selected = null;
                  }),
                ),
                if (pointsAsync.isLoading) ...[
                  const SizedBox(height: 8),
                  const _Avviso(
                      testo: 'Localizzazione degli indirizzi di intervento…',
                      caricamento: true),
                ] else if (pointsAsync.hasError) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => ref.invalidate(mapPointsProvider),
                    child: const _Avviso(
                        testo: 'Interventi non caricati. Tocca per riprovare.'),
                  ),
                ],
                if (_erroreRete != null) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _caricaRete,
                    child: _Avviso(testo: _erroreRete!),
                  ),
                ] else if (_reteTroppoLontana ||
                    contatoriLontani ||
                    reteVivaLontana) ...[
                  const SizedBox(height: 8),
                  // Toccandolo si va sulla rete (o sull'intervento più vicino).
                  GestureDetector(
                    onTap: () => _vaiAllaRete(reteViva, geo),
                    child: const _Avviso(
                        testo: 'Avvicinati per vedere la rete e i contatori'),
                  ),
                ] else if (_caricamentoRete) ...[
                  const SizedBox(height: 8),
                  const _Avviso(
                      testo: 'Caricamento della rete…', caricamento: true),
                ],
                if (_legendaAperta) ...[
                  const SizedBox(height: 8),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: _Legenda(),
                  ),
                ],
              ],
            ),
          ),

          // ── A destra: comandi flottanti ──────────────────────────────────
          Positioned(
            top: 12,
            right: 12,
            child: Column(
              children: [
                _Comando(
                    icona: Icons.layers_outlined,
                    tooltip: 'Fondo mappa',
                    onTap: _scegliFondo),
                _Comando(
                    icona: Icons.info_outline_rounded,
                    tooltip: 'Legenda',
                    attivo: _legendaAperta,
                    onTap: () =>
                        setState(() => _legendaAperta = !_legendaAperta)),
                const SizedBox(height: 10),
                _Comando(
                    icona: Icons.my_location_rounded,
                    tooltip: 'Centra sulla mia posizione',
                    onTap: _centerOnMyLocation),
                _Comando(
                    icona: Icons.fit_screen_rounded,
                    tooltip: 'Inquadra tutti gli interventi',
                    onTap: () => _inquadraTutti(geo)),
                const SizedBox(height: 10),
                _Comando(
                    icona: Icons.add_rounded,
                    tooltip: 'Avvicina',
                    onTap: () => _zoom(1)),
                _Comando(
                    icona: Icons.remove_rounded,
                    tooltip: 'Allontana',
                    onTap: () => _zoom(-1)),
              ],
            ),
          ),

          // ── In basso: scheda dell'oggetto scelto, oppure l'elenco ─────────
          if (_selected != null)
            Positioned(
              bottom: 16,
              left: 12,
              right: 12,
              child: _PointBottomCard(
                point: _selected!,
                distanza: _miaPosizione == null
                    ? null
                    : _distanza.as(
                        LengthUnit.Meter,
                        _miaPosizione!,
                        LatLng(_selected!.latitude, _selected!.longitude)),
                onClose: () => setState(() => _selected = null),
                onNaviga: () => _naviga(_selected!),
                onOpen: () => context.push(
                  _selected!.isAvviso
                      ? AppRoutes.avvisoDetailPath(_selected!.id)
                      : AppRoutes.workOrderDetailPath(_selected!.id),
                ),
              ),
            )
          else if (_contatoreSel != null)
            Positioned(
              bottom: 16,
              left: 12,
              right: 12,
              child: SchedaRete(
                etichetta: 'CONTATORE',
                colore: SimboloContatore.colore,
                titolo: _contatoreSel!.matricola,
                righe: [
                  if (_contatoreSel!.marca.isNotEmpty)
                    ('Marca', _contatoreSel!.marca),
                  if (_contatoreSel!.calibro.isNotEmpty)
                    ('Calibro', _contatoreSel!.calibro),
                  ('Indirizzo', _contatoreSel!.indirizzo),
                  ('Interventi', _contatoreSel!.interventi.join(', ')),
                ],
                nota: _contatoreSel!.approssimativa
                    ? "Posizione dell'intervento, ricavata dall'indirizzo."
                    : null,
                distanza: _miaPosizione == null
                    ? null
                    : _distanza.as(
                        LengthUnit.Meter,
                        _miaPosizione!,
                        LatLng(_contatoreSel!.latitude,
                            _contatoreSel!.longitude)),
                onClose: () => setState(() => _contatoreSel = null),
                onNaviga: () => _navigaVerso(
                    _contatoreSel!.latitude, _contatoreSel!.longitude),
                onCreaOdl: () =>
                    _creaDaContatore(_contatoreSel!, avviso: false),
                onCreaAvviso: () =>
                    _creaDaContatore(_contatoreSel!, avviso: true),
                creaOdlLabel: 'Crea OdL SOST',
              ),
            )
          else if (_puntoScelto != null)
            Positioned(
              bottom: 16,
              left: 12,
              right: 12,
              child: SchedaRete(
                etichetta: 'PUNTO SCELTO',
                colore: AppColors.primary,
                titolo: _cercaIndirizzo
                    ? "Ricerca dell'indirizzo…"
                    : _indirizzoPunto?.etichetta ??
                        'Nessun indirizzo in questo punto',
                righe: [
                  (
                    'Coordinate',
                    '${_puntoScelto!.latitude.toStringAsFixed(6)}, '
                        '${_puntoScelto!.longitude.toStringAsFixed(6)}'
                  ),
                ],
                nota: "L'OdL o l'avviso nasce con questo indirizzo e questa "
                    'posizione; il resto si compila nel modulo.',
                distanza: _miaPosizione == null
                    ? null
                    : _distanza.as(
                        LengthUnit.Meter, _miaPosizione!, _puntoScelto!),
                onClose: () => setState(() {
                  _puntoScelto = null;
                  _indirizzoPunto = null;
                }),
                onNaviga: () => _navigaVerso(
                    _puntoScelto!.latitude, _puntoScelto!.longitude),
                onCreaOdl: () => _creaDaPunto(avviso: false),
                onCreaAvviso: () => _creaDaPunto(avviso: true),
              ),
            )
          else if (_elementoSel != null)
            Positioned(
              bottom: 16,
              left: 12,
              right: 12,
              child: ElementoReteCard(
                elemento: _elementoSel!,
                distanza: _miaPosizione == null
                    ? null
                    : _distanza.as(LengthUnit.Meter, _miaPosizione!,
                        LatLng(_elementoSel!.lat, _elementoSel!.lng)),
                onClose: () => setState(() => _elementoSel = null),
                onNaviga: () =>
                    _navigaVerso(_elementoSel!.lat, _elementoSel!.lng),
                onCreaOdl: () => _creaDaRete(_elementoSel!, avviso: false),
                onCreaAvviso: () => _creaDaRete(_elementoSel!, avviso: true),
              ),
            )
          else
            _ElencoInterventi(
              punti: geo,
              senzaPosizione: senzaPosizione,
              filtro: _filtro,
              vicinoA: _miaPosizione,
              onTap: _seleziona,
            ),
        ],
      ),
    );
  }

  Marker _buildMarker(MapPoint point) {
    final isSelected = _selected?.id == point.id;
    final lato = isSelected ? 44.0 : 36.0;
    return Marker(
      key: ValueKey('segnaposto-${point.id}'),
      point: LatLng(point.latitude, point.longitude),
      width: lato,
      height: lato,
      child: GestureDetector(
        onTap: () => setState(() => _selected = point),
        child: Segnaposto(
          colore: point.statoMappa.colore,
          avviso: point.isAvviso,
          approssimativa: point.approssimativa,
          selezionato: isSelected,
          icona: _icona(point),
        ),
      ),
    );
  }
}

// ─── Segnaposto ──────────────────────────────────────────────────────────────

/// Colore = stato; cerchio = ordine, quadrato smussato = avviso; bordo
/// tratteggiato e un po' trasparente = posizione approssimativa (dall'indirizzo).
class Segnaposto extends StatelessWidget {
  final Color colore;
  final bool avviso;
  final bool approssimativa;
  final bool selezionato;
  final IconData icona;

  const Segnaposto({
    super.key,
    required this.colore,
    required this.avviso,
    required this.approssimativa,
    required this.icona,
    this.selezionato = false,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: approssimativa && !selezionato ? 0.85 : 1,
      child: CustomPaint(
        foregroundPainter: _BordoPainter(
          avviso: avviso,
          tratteggiato: approssimativa,
          spessore: selezionato ? 3.5 : 2.5,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: colore,
            shape: avviso ? BoxShape.rectangle : BoxShape.circle,
            borderRadius: avviso ? BorderRadius.circular(8) : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: selezionato ? 0.45 : 0.3),
                blurRadius: selezionato ? 12 : 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Icon(icona, color: Colors.white, size: selezionato ? 24 : 19),
        ),
      ),
    );
  }
}

class _BordoPainter extends CustomPainter {
  final bool avviso;
  final bool tratteggiato;
  final double spessore;

  _BordoPainter(
      {required this.avviso, required this.tratteggiato, required this.spessore});

  @override
  void paint(Canvas canvas, Size size) {
    final interno = (Offset.zero & size).deflate(spessore / 2);
    final path = Path();
    if (avviso) {
      path.addRRect(RRect.fromRectAndRadius(interno, const Radius.circular(8)));
    } else {
      path.addOval(interno);
    }
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = spessore;
    if (!tratteggiato) {
      canvas.drawPath(path, paint);
      return;
    }
    const tratto = 4.0, vuoto = 3.0;
    for (final metrica in path.computeMetrics()) {
      var d = 0.0;
      while (d < metrica.length) {
        canvas.drawPath(metrica.extractPath(d, d + tratto), paint);
        d += tratto + vuoto;
      }
    }
  }

  @override
  bool shouldRepaint(_BordoPainter old) =>
      old.avviso != avviso ||
      old.tratteggiato != tratteggiato ||
      old.spessore != spessore;
}

/// Gruppo di segnaposto vicini: il numero, toccandolo si avvicina.
class _Grappolo extends StatelessWidget {
  final int count;
  const _Grappolo({required this.count});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.35),
                blurRadius: 10,
                spreadRadius: 2),
          ],
        ),
        alignment: Alignment.center,
        child: FittedBox(
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Text('$count',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14)),
          ),
        ),
      );
}

class _MiaPosizione extends StatelessWidget {
  const _MiaPosizione();

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E88E5).withValues(alpha: 0.2),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: const Color(0xFF1E88E5),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
          ),
        ),
      );
}

// ─── Ricerca ─────────────────────────────────────────────────────────────────

/// "Cerca indirizzo o intervento": prima gli interventi sulla mappa che
/// corrispondono (codice, titolo, indirizzo), poi gli indirizzi del
/// geocodificatore Esri.
class _BarraRicerca extends ConsumerStatefulWidget {
  final List<MapPoint> punti;
  final LatLng? vicinoA;
  final ValueChanged<MapPoint> onIntervento;
  final ValueChanged<LuogoTrovato> onLuogo;

  const _BarraRicerca({
    required this.punti,
    required this.vicinoA,
    required this.onIntervento,
    required this.onLuogo,
  });

  @override
  ConsumerState<_BarraRicerca> createState() => _BarraRicercaState();
}

class _BarraRicercaState extends ConsumerState<_BarraRicerca> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  Timer? _attesa;
  List<SuggerimentoIndirizzo> _suggerimenti = const [];
  bool _cercando = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _attesa?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  List<MapPoint> get _interventi {
    final q = _ctrl.text.trim().toLowerCase();
    if (q.length < 2) return const [];
    return widget.punti
        .where((p) =>
            p.id.toLowerCase().contains(q) ||
            p.titolo.toLowerCase().contains(q) ||
            p.indirizzo.toLowerCase().contains(q))
        .take(4)
        .toList();
  }

  void _onChanged(String _) {
    setState(() {});
    _attesa?.cancel();
    _attesa = Timer(const Duration(milliseconds: 350), () async {
      final testo = _ctrl.text;
      setState(() => _cercando = true);
      final s = await ref.read(ricercaIndirizziProvider).suggerisci(testo,
          lat: widget.vicinoA?.latitude ?? 43.615,
          lng: widget.vicinoA?.longitude ?? 13.519);
      if (!mounted || testo != _ctrl.text) return;
      setState(() {
        _suggerimenti = s;
        _cercando = false;
      });
    });
  }

  void _pulisci() {
    _attesa?.cancel();
    _ctrl.clear();
    setState(() => _suggerimenti = const []);
  }

  Future<void> _scegliLuogo(SuggerimentoIndirizzo s) async {
    final luogo = await ref.read(ricercaIndirizziProvider).localizza(s);
    if (!mounted) return;
    if (luogo == null) {
      showSapToast(context, 'Posizione non trovata', isError: true);
      return;
    }
    _ctrl.text = luogo.indirizzo;
    setState(() => _suggerimenti = const []);
    widget.onLuogo(luogo);
  }

  @override
  Widget build(BuildContext context) {
    final interventi = _interventi;
    final mostraRisultati = _focus.hasFocus &&
        _ctrl.text.trim().length >= 2 &&
        (interventi.isNotEmpty || _suggerimenti.isNotEmpty || _cercando);

    return Material(
      elevation: 4,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(14),
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _ctrl,
            focusNode: _focus,
            onChanged: _onChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Cerca indirizzo, luogo o intervento',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _ctrl.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Cancella',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: _pulisci),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          if (mostraRisultati) ...[
            const Divider(height: 1),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                shrinkWrap: true,
                children: [
                  if (interventi.isNotEmpty) const _TitoloGruppo('Interventi'),
                  for (final p in interventi)
                    ListTile(
                      dense: true,
                      leading: SizedBox(
                        width: 26,
                        height: 26,
                        child: Segnaposto(
                          colore: p.statoMappa.colore,
                          avviso: p.isAvviso,
                          approssimativa: false,
                          icona: _icona(p),
                        ),
                      ),
                      title: Text(p.titolo,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${p.id} · ${p.indirizzo}',
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () => widget.onIntervento(p),
                    ),
                  if (_suggerimenti.isNotEmpty) const _TitoloGruppo('Indirizzi'),
                  for (final s in _suggerimenti)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.place_outlined,
                          color: AppColors.textSecondary),
                      title: Text(s.testo,
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      onTap: () => _scegliLuogo(s),
                    ),
                  if (_cercando && _suggerimenti.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(
                          child: SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2))),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TitoloGruppo extends StatelessWidget {
  final String testo;
  const _TitoloGruppo(this.testo);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
        child: Text(testo.toUpperCase(),
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: AppColors.textHint)),
      );
}

// ─── Filtro per stato ────────────────────────────────────────────────────────

class _FiltroStati extends StatelessWidget {
  final StatoMappa? selezionato;
  final ValueChanged<StatoMappa> onSelect;

  const _FiltroStati({required this.selezionato, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: StatoMappa.values.map((s) {
          final attivo = selezionato == s;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: attivo ? s.colore : Colors.white,
              elevation: 2,
              shadowColor: Colors.black26,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => onSelect(s),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: attivo ? Colors.white : s.colore,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(s.label,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: attivo
                                ? Colors.white
                                : AppColors.textPrimary)),
                  ]),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Legenda ─────────────────────────────────────────────────────────────────

class _Legenda extends StatelessWidget {
  const _Legenda();

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(14),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 18, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('LEGENDA',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: AppColors.textHint)),
            const SizedBox(height: 8),
            for (final s in StatoMappa.values)
              _VoceLegenda(
                simbolo: Container(
                  width: 14,
                  height: 14,
                  decoration:
                      BoxDecoration(color: s.colore, shape: BoxShape.circle),
                ),
                testo: s.label,
              ),
            const Divider(height: 14),
            const _VoceLegenda(
                simbolo: _MiniForma(avviso: false, approssimativa: false),
                testo: 'Ordine'),
            const _VoceLegenda(
                simbolo: _MiniForma(avviso: true, approssimativa: false),
                testo: 'Avviso'),
            const _VoceLegenda(
                simbolo: _MiniForma(avviso: false, approssimativa: true),
                testo: 'Posizione da indirizzo (approssimativa)'),
            const _VoceLegenda(
                simbolo: SizedBox(
                    width: 16, height: 16, child: _Grappolo(count: 3)),
                testo: 'Più interventi vicini'),
            const _VoceLegenda(
                simbolo: SizedBox(
                    width: 14, height: 14, child: SimboloContatore()),
                testo: 'Contatore di un intervento'),
            const Divider(height: 14),
            const Text('RETE VIVA SERVIZI',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: AppColors.textHint)),
            const SizedBox(height: 6),
            const _VoceLegenda(
                simbolo: _Tratto(colore: _coloreAdduzione),
                testo: 'Condotta di adduzione'),
            const _VoceLegenda(
                simbolo: _Tratto(colore: _coloreDistribuzione),
                testo: 'Condotta di distribuzione'),
            const _VoceLegenda(
                simbolo: _Tratto(colore: _coloreAllaccio, tratteggio: true),
                testo: 'Allaccio'),
            const _VoceLegenda(
                simbolo: SizedBox(
                    width: 14,
                    height: 14,
                    child: PuntoRete(strato: StratoRete.misuratori)),
                testo: 'Contatore'),
            const _VoceLegenda(
                simbolo: SizedBox(
                    width: 14,
                    height: 14,
                    child: PuntoRete(strato: StratoRete.riduttori)),
                testo: 'Riduttore di pressione'),
            const Divider(height: 14),
            const _VoceLegenda(
                simbolo: Icon(Icons.touch_app_outlined,
                    size: 16, color: AppColors.primary),
                testo: 'Tieni premuto sulla mappa: OdL o avviso in quel punto'),
          ],
        ),
      ),
    );
  }
}

class _VoceLegenda extends StatelessWidget {
  final Widget simbolo;
  final String testo;
  const _VoceLegenda({required this.simbolo, required this.testo});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: 18, child: Center(child: simbolo)),
          const SizedBox(width: 8),
          Text(testo,
              style: const TextStyle(
                  fontSize: 12.5, color: AppColors.textSecondary)),
        ]),
      );
}

class _MiniForma extends StatelessWidget {
  final bool avviso;
  final bool approssimativa;
  const _MiniForma({required this.avviso, required this.approssimativa});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 16,
        height: 16,
        child: Segnaposto(
          colore: AppColors.textSecondary,
          avviso: avviso,
          approssimativa: approssimativa,
          icona: Icons.circle,
        ),
      );
}

// ─── Comandi flottanti ───────────────────────────────────────────────────────

class _Comando extends StatelessWidget {
  final IconData icona;
  final String tooltip;
  final VoidCallback onTap;
  final bool attivo;

  const _Comando({
    required this.icona,
    required this.tooltip,
    required this.onTap,
    this.attivo = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Tooltip(
          message: tooltip,
          child: Material(
            color: attivo ? AppColors.primary : Colors.white,
            elevation: 3,
            shadowColor: Colors.black26,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(
                width: 48,
                height: 48,
                child: Icon(icona,
                    color: attivo ? Colors.white : AppColors.primary),
              ),
            ),
          ),
        ),
      );
}

class _Avviso extends StatelessWidget {
  final String testo;
  final bool caricamento;
  const _Avviso({required this.testo, this.caricamento = false});

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Material(
          elevation: 2,
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (caricamento) ...[
                const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 8),
              ],
              Text(testo,
                  style: const TextStyle(
                      fontSize: 12.5, color: AppColors.textSecondary)),
            ]),
          ),
        ),
      );
}

// ─── Scelta del fondo ────────────────────────────────────────────────────────

class _SceltaFondo extends StatefulWidget {
  final FondoMappa attuale;

  /// Vero se l'app ha il token ArcGIS: solo allora i livelli si accendono.
  final bool reteAttiva;
  final Set<StratoRete> strati;
  final ValueChanged<Set<StratoRete>> onStrati;

  /// Contatori degli interventi (dal backend) accesi/spenti.
  final bool contatori;
  final ValueChanged<bool> onContatori;

  /// Rete Viva Servizi disegnata (condotte, contatori…) accesa/spenta.
  final bool reteViva;
  final ValueChanged<bool> onReteViva;

  const _SceltaFondo({
    required this.attuale,
    required this.reteAttiva,
    required this.strati,
    required this.onStrati,
    required this.contatori,
    required this.onContatori,
    required this.reteViva,
    required this.onReteViva,
  });

  @override
  State<_SceltaFondo> createState() => _SceltaFondoState();
}

class _SceltaFondoState extends State<_SceltaFondo> {
  late Set<StratoRete> _strati = {...widget.strati};
  late bool _contatori = widget.contatori;
  late bool _reteViva = widget.reteViva;

  void _cambia(StratoRete s, bool acceso) {
    setState(() {
      _strati = {..._strati};
      acceso ? _strati.add(s) : _strati.remove(s);
    });
    widget.onStrati(_strati);
  }

  @override
  Widget build(BuildContext context) {
    final attuale = widget.attuale;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Fondo mappa', style: AppTextStyles.headingSmall),
            const SizedBox(height: 4),
            const Text('Mappe di base Esri (ArcGIS)',
                style: TextStyle(fontSize: 12, color: AppColors.textHint)),
            const SizedBox(height: 14),
            Row(
              children: FondoMappa.values.map((f) {
                final scelto = f == attuale;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => Navigator.pop(context, f),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: scelto
                              ? AppColors.primarySurface
                              : AppColors.backgroundPage,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color:
                                  scelto ? AppColors.primary : AppColors.border,
                              width: scelto ? 2 : 1),
                        ),
                        child: Column(children: [
                          Icon(f.icona,
                              color: scelto
                                  ? AppColors.primary
                                  : AppColors.textSecondary),
                          const SizedBox(height: 6),
                          Text(f.label,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: scelto
                                      ? AppColors.primary
                                      : AppColors.textSecondary)),
                        ]),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            const Text('Sulla mappa', style: AppTextStyles.headingSmall),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const SizedBox(
                  width: 22,
                  height: 22,
                  child: PuntoRete(strato: StratoRete.misuratori)),
              title: const Text('Rete idrica Viva Servizi'),
              subtitle: const Text(
                  'Condotte, allacci, contatori e riduttori, da vicino'),
              value: _reteViva,
              onChanged: (v) {
                setState(() => _reteViva = v);
                widget.onReteViva(v);
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const SizedBox(
                  width: 22, height: 22, child: SimboloContatore()),
              title: const Text('Contatori degli interventi'),
              subtitle: const Text(
                  'I contatori di OdL e avvisi (dal backend), da vicino'),
              value: _contatori,
              onChanged: (v) {
                setState(() => _contatori = v);
                widget.onContatori(v);
              },
            ),
            // Rete Viva Servizi: solo con la chiave ArcGIS. Senza, niente da
            // mostrare (né interruttori spenti né spiegazioni).
            if (widget.reteAttiva) ...[
              const SizedBox(height: 20),
              const Text('Rete Viva Servizi',
                  style: AppTextStyles.headingSmall),
              const SizedBox(height: 4),
              const Text('Livelli ArcGIS della rete, visibili da vicino',
                  style: TextStyle(fontSize: 12, color: AppColors.textHint)),
              const SizedBox(height: 6),
              for (final s in StratoRete.values)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: SizedBox(
                      width: 22, height: 22, child: PuntoRete(strato: s)),
                  title: Text(s.label),
                  value: _strati.contains(s),
                  onChanged: (v) => _cambia(s, v),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Rete Viva Servizi ───────────────────────────────────────────────────────

/// Punto della rete: contatore = cerchietto blu, riduttore = rombo verde
/// acqua. Il target ampio rende più semplice selezionarlo sulla mappa.
class PuntoRete extends StatelessWidget {
  final StratoRete strato;
  final bool selezionato;
  const PuntoRete({super.key, required this.strato, this.selezionato = false});

  static Color colore(StratoRete s) => switch (s) {
        StratoRete.misuratori => const Color(0xFF3CC13C),
        StratoRete.riduttori => const Color(0xFFE53935),
      };

  @override
  Widget build(BuildContext context) {
    final lato = selezionato ? 24.0 : 16.0;
    return Center(
      child: Container(
        width: lato,
        height: lato,
        decoration: BoxDecoration(
          color: colore(strato),
          shape: strato == StratoRete.misuratori
              ? BoxShape.circle
              : BoxShape.rectangle,
          border: Border.all(
              color: selezionato ? AppColors.primary : const Color(0xFF1B1B1B),
              width: selezionato ? 3 : 1.2),
        ),
      ),
    );
  }
}

/// Testo sulla rete (materiale della condotta, codice del riduttore).
class _EtichettaRete extends StatelessWidget {
  final String testo;
  final Color colore;
  const _EtichettaRete({required this.testo, required this.colore});

  @override
  Widget build(BuildContext context) => Center(
        child: Text(
          testo,
          maxLines: 1,
          overflow: TextOverflow.visible,
          softWrap: false,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: colore,
            shadows: const [
              Shadow(color: Colors.white, blurRadius: 3),
              Shadow(color: Colors.white, blurRadius: 3),
            ],
          ),
        ),
      );
}

/// Trattino di linea per la legenda.
class _Tratto extends StatelessWidget {
  final Color colore;
  final bool tratteggio;
  const _Tratto({required this.colore, this.tratteggio = false});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 18,
        height: 3,
        child: tratteggio
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 0; i < 3; i++)
                    Container(width: 4, height: 2, color: colore),
                ],
              )
            : Container(color: colore),
      );
}

const _coloreAdduzione = Color(0xFFE53935);
const _coloreDistribuzione = Color(0xFF3CC13C);
const _coloreAllaccio = Color(0xFFE879B9);

/// Scheda di un punto della rete: gli attributi come li manda ArcGIS (con le
/// etichette del livello) e le azioni Naviga / Crea OdL / Crea avviso.
class ElementoReteCard extends ConsumerStatefulWidget {
  final ElementoRete elemento;
  final double? distanza;
  final VoidCallback onClose;
  final VoidCallback onNaviga;
  final VoidCallback onCreaOdl;
  final VoidCallback onCreaAvviso;

  const ElementoReteCard({
    super.key,
    required this.elemento,
    required this.distanza,
    required this.onClose,
    required this.onNaviga,
    required this.onCreaOdl,
    required this.onCreaAvviso,
  });

  @override
  ConsumerState<ElementoReteCard> createState() => _ElementoReteCardState();
}

class _ElementoReteCardState extends ConsumerState<ElementoReteCard> {
  SchemaStrato _schema = const SchemaStrato();

  // Campi tecnici del servizio, non utili al tecnico.
  static const _nascosti = {
    'objectid', 'fid', 'oid', 'globalid', 'shape', 'shape_length',
    'shape_area', 'shape__length', 'shape__area',
  };

  @override
  void initState() {
    super.initState();
    _caricaSchema();
  }

  @override
  void didUpdateWidget(ElementoReteCard old) {
    super.didUpdateWidget(old);
    if (old.elemento.strato != widget.elemento.strato) _caricaSchema();
  }

  Future<void> _caricaSchema() async {
    if (!ref.read(reteArcgisProvider).attivo) return;
    try {
      final s = await ref.read(reteArcgisProvider).schema(widget.elemento.strato);
      if (mounted) setState(() => _schema = s);
    } catch (_) {
      // Senza schema si mostrano i nomi dei campi così come sono.
    }
  }

  String _valore(Object? v) => '${v ?? ''}'.trim();

  @override
  Widget build(BuildContext context) {
    final e = widget.elemento;
    final titoloCampo = _schema.campoTitolo;
    final titolo = e.matricola ??
        (titoloCampo != null ? _valore(e.attributi[titoloCampo]) : '');
    return SchedaRete(
      etichetta: e.strato.label.toUpperCase(),
      colore: PuntoRete.colore(e.strato),
      titolo: titolo.isEmpty ? 'Rete Viva Servizi' : titolo,
      righe: [
        for (final a in e.attributi.entries)
          if (!_nascosti.contains(a.key.toLowerCase()) &&
              _valore(a.value).isNotEmpty)
            (_schema.etichetta(a.key), _valore(a.value)),
      ],
      distanza: widget.distanza,
      onClose: widget.onClose,
      onNaviga: widget.onNaviga,
      onCreaOdl: widget.onCreaOdl,
      onCreaAvviso: widget.onCreaAvviso,
    );
  }
}

/// Contatore sulla mappa: pallino verde col bordo bianco, come i contatori
/// sulla mappa della rete Viva Servizi.
class SimboloContatore extends StatelessWidget {
  final bool selezionato;
  const SimboloContatore({super.key, this.selezionato = false});

  static const colore = Color(0xFF2E9E3E);

  @override
  Widget build(BuildContext context) {
    final lato = selezionato ? 20.0 : 14.0;
    return Center(
      child: Container(
        width: lato,
        height: lato,
        decoration: BoxDecoration(
          color: colore,
          shape: BoxShape.circle,
          border: Border.all(
              color: selezionato ? AppColors.primary : Colors.white,
              width: selezionato ? 3 : 2),
          boxShadow: const [
            BoxShadow(
                color: Colors.black26, blurRadius: 3, offset: Offset(0, 1)),
          ],
        ),
      ),
    );
  }
}

/// Scheda in basso per un elemento della mappa che non è un intervento
/// (contatore, punto della rete, punto scelto): intestazione, righe
/// etichetta/valore e le azioni Naviga / Crea avviso / Crea OdL.
class SchedaRete extends StatelessWidget {
  final String etichetta;
  final Color colore;
  final String titolo;
  final List<(String, String)> righe;
  final String? nota;
  final double? distanza;
  final VoidCallback onClose;
  final VoidCallback onNaviga;
  final VoidCallback onCreaOdl;
  final VoidCallback onCreaAvviso;
  final String creaOdlLabel;

  const SchedaRete({
    super.key,
    required this.etichetta,
    required this.colore,
    required this.titolo,
    required this.righe,
    required this.distanza,
    required this.onClose,
    required this.onNaviga,
    required this.onCreaOdl,
    required this.onCreaAvviso,
    this.nota,
    this.creaOdlLabel = 'Crea OdL',
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 12,
      borderRadius: BorderRadius.circular(20),
      shadowColor: Colors.black26,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border(left: BorderSide(color: colore, width: 4)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              _Etichetta(testo: etichetta, colore: colore),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  titolo,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.headingSmall,
                ),
              ),
              if (distanza != null)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(_fmtDistanza(distanza!),
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary)),
                ),
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                color: AppColors.textHint,
              ),
            ]),
            if (righe.isNotEmpty) ...[
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 150),
                child: SingleChildScrollView(
                  child: Column(children: [
                    for (final (etichetta, valore) in righe)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 150,
                              child: Text(etichetta,
                                  style: const TextStyle(
                                      fontSize: 12.5,
                                      color: AppColors.textHint)),
                            ),
                            Expanded(
                              child: Text(valore,
                                  style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary)),
                            ),
                          ],
                        ),
                      ),
                  ]),
                ),
              ),
            ],
            if (nota != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(nota!,
                    style: const TextStyle(
                        fontSize: 11.5, color: AppColors.textHint)),
              ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onNaviga,
                  icon: const Icon(Icons.directions_rounded, size: 18),
                  label: const Text('Naviga'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCreaAvviso,
                  icon: const Icon(Icons.notification_add_outlined, size: 18),
                  label: const Text('Crea avviso'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onCreaOdl,
                  icon: const Icon(Icons.add_task_rounded, size: 18),
                  label: Text(creaOdlLabel),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ─── Elenco degli interventi (pannello trascinabile) ─────────────────────────

class _ElencoInterventi extends StatelessWidget {
  final List<MapPoint> punti;
  final int senzaPosizione;
  final StatoMappa? filtro;
  final LatLng? vicinoA;
  final ValueChanged<MapPoint> onTap;

  const _ElencoInterventi({
    required this.punti,
    required this.senzaPosizione,
    required this.filtro,
    required this.vicinoA,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Con la posizione del tecnico, il più vicino in cima.
    final ordinati = [...punti];
    if (vicinoA != null) {
      double d(MapPoint p) => _distanza.as(
          LengthUnit.Meter, vicinoA!, LatLng(p.latitude, p.longitude));
      ordinati.sort((a, b) => d(a).compareTo(d(b)));
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.11,
      minChildSize: 0.11,
      maxChildSize: 0.6,
      snap: true,
      builder: (context, scroll) => Material(
        elevation: 10,
        shadowColor: Colors.black38,
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: ListView(
          controller: scroll,
          padding: EdgeInsets.zero,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(top: 8, bottom: 6),
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
              child: Row(children: [
                Text('${punti.length} sulla mappa',
                    style: AppTextStyles.headingSmall),
                if (filtro != null) ...[
                  const SizedBox(width: 8),
                  Text('· ${filtro!.label}',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: filtro!.colore)),
                ],
                const Spacer(),
                if (senzaPosizione > 0)
                  Text('$senzaPosizione senza indirizzo',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textHint)),
              ]),
            ),
            if (punti.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Text(
                  filtro != null
                      ? 'Nessun intervento "${filtro!.label}" con un indirizzo localizzabile.'
                      : 'Gli oggetti senza indirizzo di intervento non possono essere posizionati.',
                  style: AppTextStyles.bodyMedium,
                ),
              ),
            for (final p in ordinati)
              ListTile(
                onTap: () => onTap(p),
                leading: SizedBox(
                  width: 32,
                  height: 32,
                  child: Segnaposto(
                    colore: p.statoMappa.colore,
                    avviso: p.isAvviso,
                    approssimativa: p.approssimativa,
                    icona: _icona(p),
                  ),
                ),
                title: Text(p.titolo,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  '${p.isAvviso ? 'Avviso' : 'OdL'} ${p.id} · ${p.statoLabel.isEmpty ? p.statoMappa.label : p.statoLabel}\n${p.indirizzo}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                isThreeLine: true,
                trailing: vicinoA == null
                    ? const Icon(Icons.chevron_right_rounded)
                    : Text(
                        _fmtDistanza(_distanza.as(LengthUnit.Meter, vicinoA!,
                            LatLng(p.latitude, p.longitude))),
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary)),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ─── Scheda dell'oggetto selezionato ─────────────────────────────────────────

class _PointBottomCard extends StatelessWidget {
  final MapPoint point;
  final double? distanza;
  final VoidCallback onClose;
  final VoidCallback onOpen;
  final VoidCallback onNaviga;

  const _PointBottomCard({
    required this.point,
    required this.distanza,
    required this.onClose,
    required this.onOpen,
    required this.onNaviga,
  });

  @override
  Widget build(BuildContext context) {
    final color = point.statoMappa.colore;
    final tipo = point.tipo.trim();
    final priorita = point.priorita.trim();

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
                _Etichetta(
                    testo: point.isAvviso ? 'AVVISO' : 'ORDINE',
                    colore: AppColors.primary),
                const SizedBox(width: 6),
                _Etichetta(
                    testo: (point.statoLabel.isEmpty
                            ? point.statoMappa.label
                            : point.statoLabel)
                        .toUpperCase(),
                    colore: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    point.id,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary),
                  ),
                ),
                if (distanza != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(_fmtDistanza(distanza!),
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary)),
                  ),
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
            if (tipo.isNotEmpty || priorita.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                [
                  if (tipo.isNotEmpty) 'Tipo $tipo',
                  if (priorita.isNotEmpty) 'Priorità: $priorita',
                ].join('  ·  '),
                style: AppTextStyles.bodySmall,
              ),
            ],
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
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
            if (point.approssimativa)
              const Padding(
                padding: EdgeInsets.only(top: 4, left: 18),
                child: Text(
                  'Posizione ricavata dall\'indirizzo: può essere approssimativa.',
                  style: TextStyle(fontSize: 11.5, color: AppColors.textHint),
                ),
              ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onNaviga,
                  icon: const Icon(Icons.directions_rounded, size: 18),
                  label: const Text('Naviga'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('Apri dettaglio'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _Etichetta extends StatelessWidget {
  final String testo;
  final Color colore;
  const _Etichetta({required this.testo, required this.colore});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: colore.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(testo,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: colore)),
      );
}
