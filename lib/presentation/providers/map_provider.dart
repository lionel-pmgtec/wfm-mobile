// Punti da mostrare sulla mappa: ordini e avvisi assegnati al tecnico.
//
// La posizione è quella dell'INDIRIZZO DI INTERVENTO. SAP lo trasmette
// (INDIRIZZO_LAVORO) ma senza coordinate, quindi l'indirizzo viene convertito
// in latitudine/longitudine dal servizio di geocodifica, che tiene una cache:
// la conversione avviene una sola volta per indirizzo.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/geocoding_service.dart';
import '../../domain/entities/entities.dart';
import 'avvisi_provider.dart';
import 'work_orders_provider.dart';

/// Un oggetto posizionato sulla mappa.
class MapPoint {
  final String id; // codice OdL o numero avviso
  final String titolo;
  final bool isAvviso;

  /// Stato dell'ordine (assente per gli avvisi).
  final WorkOrderStatus? stato;

  final double latitude;
  final double longitude;

  /// Indirizzo usato per posizionarlo, mostrato nella scheda.
  final String indirizzo;

  const MapPoint({
    required this.id,
    required this.titolo,
    required this.isAvviso,
    required this.latitude,
    required this.longitude,
    required this.indirizzo,
    this.stato,
  });
}

/// Indirizzo su cui posizionare un ordine: quello di intervento, con ripiego
/// sull'indirizzo principale e poi su quello dell'oggetto tecnico.
Address indirizzoInterventoOrdine(WorkOrder o) {
  final candidati = [o.indirizzoIntervento, o.address, o.indirizzoOggetto];
  for (final a in candidati) {
    if (a != null && (a.hasCoordinates || GeocodingService.isGeocodable(a))) {
      return a;
    }
  }
  return o.address;
}

/// Idem per un avviso: SAP non porta un indirizzo di lavoro separato.
Address indirizzoInterventoAvviso(NotificationAvviso a) {
  final candidati = [a.indirizzoLavoro, a.address, a.indirizzoOggetto];
  for (final x in candidati) {
    if (x != null && (x.hasCoordinates || GeocodingService.isGeocodable(x))) {
      return x;
    }
  }
  return a.address;
}

/// Tutti i punti da disegnare: ordini + avvisi, già geolocalizzati.
final mapPointsProvider = FutureProvider<List<MapPoint>>((ref) async {
  final geo = GeocodingService.instance;
  final punti = <MapPoint>[];

  // Ordini
  List<WorkOrder> ordini = const [];
  try {
    ordini = await ref.watch(workOrdersProvider.future);
  } catch (_) {
    ordini = const [];
  }
  for (final o in ordini) {
    final addr = indirizzoInterventoOrdine(o);
    final p = await geo.resolve(addr);
    if (p == null) continue;
    punti.add(MapPoint(
      id: o.externalCode,
      titolo: o.displayName,
      isAvviso: false,
      stato: o.status,
      latitude: p.latitude,
      longitude: p.longitude,
      indirizzo: addr.full,
    ));
  }

  // Avvisi
  List<NotificationAvviso> avvisi = const [];
  try {
    avvisi = await ref.watch(avvisiProvider.future);
  } catch (_) {
    avvisi = const [];
  }
  for (final a in avvisi) {
    final addr = indirizzoInterventoAvviso(a);
    final p = await geo.resolve(addr);
    if (p == null) continue;
    punti.add(MapPoint(
      id: a.numeroAvviso,
      titolo: a.descrizione.isEmpty ? 'Avviso ${a.numeroAvviso}' : a.descrizione,
      isAvviso: true,
      latitude: p.latitude,
      longitude: p.longitude,
      indirizzo: addr.full,
    ));
  }

  return punti;
});

/// Quanti oggetti restano senza posizione (indirizzo assente o non trovato):
/// serve a spiegarlo in mappa invece di farli sparire in silenzio.
final mapMissingCountProvider = FutureProvider<int>((ref) async {
  final punti = await ref.watch(mapPointsProvider.future);
  var totale = 0;
  try {
    totale += (await ref.watch(workOrdersProvider.future)).length;
  } catch (_) {/* elenco non disponibile */}
  try {
    totale += (await ref.watch(avvisiProvider.future)).length;
  } catch (_) {/* elenco non disponibile */}
  final mancanti = totale - punti.length;
  return mancanti < 0 ? 0 : mancanti;
});
