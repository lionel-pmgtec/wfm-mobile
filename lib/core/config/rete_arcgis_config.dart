// Livelli della rete idrica Viva Servizi su ArcGIS (contatori, riduttori…).
//
// Il servizio è quello della mappa "VIVA SERVIZI_Ambito Intervento"
// (ArcGIS Online, pubblica), i cui livelli però sono protetti: senza token
// rispondono 499 "Token Required". Il token NON sta nel codice: si passa in
// compilazione, come l'URL del backend:
//
//   flutter run --dart-define=ARCGIS_TOKEN=<token>
//
// Senza token i livelli restano visibili nelle impostazioni della mappa ma
// spenti, e non si mostra nessun punto (niente dati inventati).

class ReteArcgisConfig {
  ReteArcgisConfig._();

  static const String token = String.fromEnvironment('ARCGIS_TOKEN');

  static const String servizio = String.fromEnvironment(
    'ARCGIS_RETE_URL',
    defaultValue:
        'https://services3.arcgis.com/fe7KUl6dZdY0Os4o/arcgis/rest/services/VIVA_SERVIZI_Ambito_Intervento_WFL1/FeatureServer',
  );

  /// Vero se è stato fornito un token: solo allora i livelli si interrogano.
  static bool get attivo => token.isNotEmpty;

  /// Sotto questo zoom la rete non si carica: sarebbero troppi punti.
  static const double zoomMinimo = 16;
}

/// Livelli della rete che la mappa sa mostrare. `layerId` = numero del livello
/// nel FeatureServer (dalla mappa pubblica: 12 Misuratori, 5 Riduttori).
enum StratoRete {
  misuratori(12, 'Contatori', 'Misuratori'),
  riduttori(5, 'Riduttori di pressione', 'Riduttori_di_pressione');

  final int layerId;
  final String label;

  /// Nome del livello nel servizio ArcGIS.
  final String nomeArcgis;
  const StratoRete(this.layerId, this.label, this.nomeArcgis);
}
