// "Naviga": apre l'app di navigazione del tablet con il percorso verso il
// punto dell'intervento.
//
// Si usa il link universale di Google Maps (`/maps/dir/?api=1`): su Android e
// iOS apre l'app Mappe installata, altrimenti il browser. Destinazione:
// le coordinate se l'oggetto le ha, altrimenti l'indirizzo in chiaro (lo
// risolve l'app di navigazione).

import 'package:url_launcher/url_launcher.dart';

import '../../domain/entities/value_objects.dart';

class NavigazioneService {
  NavigazioneService._();

  /// Link del percorso verso la destinazione. Null se non c'è né una
  /// posizione né un indirizzo utilizzabile.
  static Uri? uriPercorso({double? lat, double? lng, String? indirizzo}) {
    final String destinazione;
    if (lat != null && lng != null) {
      destinazione = '$lat,$lng';
    } else if ((indirizzo ?? '').trim().isNotEmpty) {
      destinazione = indirizzo!.trim();
    } else {
      return null;
    }
    return Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': destinazione,
      'travelmode': 'driving',
    });
  }

  /// Destinazione da un indirizzo: le coordinate se ci sono, altrimenti il
  /// testo dell'indirizzo.
  static Uri? uriPercorsoIndirizzo(Address a) => a.hasCoordinates
      ? uriPercorso(lat: a.latitude, lng: a.longitude)
      : uriPercorso(indirizzo: a.full);

  /// Apre la navigazione. Ritorna false se non c'è destinazione o se nessuna
  /// app ha potuto aprire il link.
  static Future<bool> apri(Uri? uri) async {
    if (uri == null) return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
