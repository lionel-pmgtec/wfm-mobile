// Punti da mostrare sulla mappa: ordini e avvisi assegnati al tecnico.
//
// La posizione è quella dell'INDIRIZZO DI INTERVENTO. SAP lo trasmette
// (INDIRIZZO_LAVORO) ma senza coordinate, quindi l'indirizzo viene convertito
// in latitudine/longitudine dal servizio di geocodifica, che tiene una cache:
// la conversione avviene una sola volta per indirizzo.

import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/geocoding_service.dart';
import '../../core/services/rete_arcgis_service.dart';
import '../../core/services/rete_viva_service.dart';
import '../../core/services/ricerca_indirizzi_service.dart';
import '../../domain/entities/entities.dart';
import 'avvisi_provider.dart';
import 'work_orders_provider.dart';

/// Stato mostrato sulla mappa, comune a ordini e avvisi: gli stessi stati e
/// colori della mappa del cruscotto (MapPage.tsx), così tablet e cruscotto si
/// leggono allo stesso modo. "Da assegnare" non compare: sul tablet c'è solo
/// il lavoro già assegnato al tecnico.
enum StatoMappa {
  assegnato('Assegnato', Color(0xFFFF9800)),
  inEsecuzione('In esecuzione', Color(0xFFE53935)),
  sospeso('Sospeso', Color(0xFF9C27B0)),
  completato('Completato', Color(0xFF4CAF50));

  final String label;
  final Color colore;
  const StatoMappa(this.label, this.colore);

  /// Null = non va sulla mappa (annullato, inviato a SAP: il ciclo è chiuso,
  /// come sul cruscotto).
  static StatoMappa? daOrdine(WorkOrderStatus s) => switch (s) {
        WorkOrderStatus.ricevuto => StatoMappa.assegnato,
        // La pausa è solo del tablet: per il backend l'OdL è in esecuzione.
        WorkOrderStatus.inEsecuzione ||
        WorkOrderStatus.inPausa =>
          StatoMappa.inEsecuzione,
        WorkOrderStatus.sospeso => StatoMappa.sospeso,
        WorkOrderStatus.completato => StatoMappa.completato,
        WorkOrderStatus.annullato || WorkOrderStatus.inviatoSAP => null,
      };

  static StatoMappa daAvviso(AvvisoStato s) => switch (s) {
        AvvisoStato.creato || AvvisoStato.presoInCarico => StatoMappa.assegnato,
        AvvisoStato.inLavorazione => StatoMappa.inEsecuzione,
        AvvisoStato.sospeso => StatoMappa.sospeso,
        AvvisoStato.chiuso => StatoMappa.completato,
      };
}

/// Un oggetto posizionato sulla mappa.
class MapPoint {
  final String id; // codice OdL o numero avviso
  final String titolo;
  final bool isAvviso;

  /// Stato dell'ordine (assente per gli avvisi).
  final WorkOrderStatus? stato;

  /// Stato per colore e filtro, comune a ordini e avvisi.
  final StatoMappa statoMappa;

  /// Etichetta dello stato reale (dell'OdL o dell'avviso).
  final String statoLabel;

  /// Tipo d'ordine o d'avviso (SOST, ZA02, ZH…).
  final String tipo;
  final String priorita;

  final double latitude;
  final double longitude;

  /// Vero se la posizione viene dall'indirizzo convertito dal servizio di
  /// geocodifica, e non da coordinate mandate dal backend.
  final bool approssimativa;

  /// Indirizzo usato per posizionarlo, mostrato nella scheda.
  final String indirizzo;

  /// Indirizzo strutturato (via, civico, comune…) per precompilare i moduli.
  final Address? address;

  /// Contatore dell'oggetto, così come lo manda il backend (null = nessuno).
  final String? matricola;
  final String marcaContatore;
  final String calibroContatore;

  const MapPoint({
    required this.id,
    required this.titolo,
    required this.isAvviso,
    required this.latitude,
    required this.longitude,
    required this.indirizzo,
    required this.statoMappa,
    this.statoLabel = '',
    this.tipo = '',
    this.priorita = '',
    this.approssimativa = false,
    this.stato,
    this.address,
    this.matricola,
    this.marcaContatore = '',
    this.calibroContatore = '',
  });
}

/// Un contatore sulla mappa. Il backend non ha un'anagrafica dei contatori:
/// ogni contatore arriva sull'OdL o sull'avviso che lo riguarda (vedi
/// `dominio/contatori.ts` del backend). Quindi i contatori della mappa sono
/// quelli degli interventi del tecnico, nella stessa posizione dell'intervento.
class ContatoreMappa {
  final String matricola;
  final String marca;
  final String calibro;
  final double latitude;
  final double longitude;
  final String indirizzo;
  final Address? address;
  final bool approssimativa;

  /// OdL/avvisi su cui compare (codici), per ritrovarli dalla scheda.
  final List<String> interventi;

  const ContatoreMappa({
    required this.matricola,
    required this.latitude,
    required this.longitude,
    required this.indirizzo,
    required this.interventi,
    this.marca = '',
    this.calibro = '',
    this.address,
    this.approssimativa = false,
  });
}

/// La stessa matricola con o senza zeri davanti (SAP la manda a 18 cifre).
String _chiaveMatricola(String m) =>
    m.trim().replaceFirst(RegExp(r'^0+'), '').toUpperCase();

/// Contatori da mostrare: uno per matricola, dagli interventi sulla mappa.
List<ContatoreMappa> contatoriDaPunti(List<MapPoint> punti) {
  final perChiave = <String, ContatoreMappa>{};
  for (final p in punti) {
    final m = (p.matricola ?? '').trim();
    final k = _chiaveMatricola(m);
    if (k.isEmpty) continue;
    final gia = perChiave[k];
    if (gia != null) {
      perChiave[k] = ContatoreMappa(
        matricola: gia.matricola,
        marca: gia.marca.isNotEmpty ? gia.marca : p.marcaContatore,
        calibro: gia.calibro.isNotEmpty ? gia.calibro : p.calibroContatore,
        latitude: gia.latitude,
        longitude: gia.longitude,
        indirizzo: gia.indirizzo,
        address: gia.address,
        approssimativa: gia.approssimativa,
        interventi: [...gia.interventi, p.id],
      );
      continue;
    }
    perChiave[k] = ContatoreMappa(
      matricola: m,
      marca: p.marcaContatore,
      calibro: p.calibroContatore,
      latitude: p.latitude,
      longitude: p.longitude,
      indirizzo: p.indirizzo,
      address: p.address,
      approssimativa: p.approssimativa,
      interventi: [p.id],
    );
  }
  return perChiave.values.toList();
}

final contatoriMappaProvider = FutureProvider<List<ContatoreMappa>>(
    (ref) async => contatoriDaPunti(await ref.watch(mapPointsProvider.future)));

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
    final statoMappa = StatoMappa.daOrdine(o.status);
    if (statoMappa == null) continue;
    final addr = indirizzoInterventoOrdine(o);
    final p = await geo.resolve(addr);
    if (p == null) continue;
    punti.add(MapPoint(
      id: o.externalCode,
      titolo: o.displayName,
      isAvviso: false,
      stato: o.status,
      statoMappa: statoMappa,
      statoLabel: o.status.label,
      tipo: o.woType,
      priorita: o.priorita,
      latitude: p.latitude,
      longitude: p.longitude,
      approssimativa: !addr.hasCoordinates,
      indirizzo: addr.full,
      address: addr,
      matricola: o.meter?.matricola ?? o.matricola,
      marcaContatore: o.meter?.brand ?? '',
      calibroContatore: o.meter?.caliber ?? '',
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
      statoMappa: StatoMappa.daAvviso(a.statoTipo),
      statoLabel: a.statoTipo.label,
      tipo: a.tipo,
      priorita: a.priorita,
      latitude: p.latitude,
      longitude: p.longitude,
      approssimativa: !addr.hasCoordinates,
      indirizzo: addr.full,
      address: addr,
      matricola: a.matricola,
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
    // Gli OdL chiusi (annullati, inviati a SAP) non vanno sulla mappa per
    // scelta: non sono "senza indirizzo".
    totale += (await ref.watch(workOrdersProvider.future))
        .where((o) => StatoMappa.daOrdine(o.status) != null)
        .length;
  } catch (_) {/* elenco non disponibile */}
  try {
    totale += (await ref.watch(avvisiProvider.future)).length;
  } catch (_) {/* elenco non disponibile */}
  final mancanti = totale - punti.length;
  return mancanti < 0 ? 0 : mancanti;
});

/// Ricerca di indirizzi e luoghi nella barra della mappa (geocodificatore Esri).
final ricercaIndirizziProvider =
    Provider<RicercaIndirizziService>((ref) => RicercaIndirizziService.instance);

/// Livelli della rete Viva Servizi (ArcGIS): attivi solo con il token.
final reteArcgisProvider =
    Provider<ReteArcgisService>((ref) => ReteArcgisService());

/// Rete Viva Servizi disegnata sulla mappa (condotte, allacci, contatori,
/// riduttori): letta una volta dal file della rete.
final reteVivaProvider = FutureProvider<ReteViva>((ref) async {
  try {
    return await ReteVivaService().carica();
  } catch (_) {
    return ReteViva.vuota;
  }
});
