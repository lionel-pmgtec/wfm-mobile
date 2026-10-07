# WFM Mobile — Viva Servizi

Applicazione **Flutter per tablet** per la gestione sul campo di **Ordini di
Lavoro (OdL)** e **Avvisi** di manutenzione, connessa a SAP tramite il **backend
unico del cruscotto** (Node/TypeScript). Il tecnico vede e lavora **solo gli
oggetti a lui assegnati**.

```
[App Flutter]  ◄── REST/JSON (/api/v1) + SSE (/api/stream) ──►  [Backend-WFM (Node, :4000)]  ◄── SOAP/XML ──►  [SAP DG1]
   tablet            (login, ordini, avvisi, esiti,                 store su file:                     ZWFMT_SERVIZIO_PM
                      stato, anagrafiche, realtime)                 state / assignments / tecnici
```


>  **Documentazione completa** — funzionalità per il tecnico + API del backend

## Struttura del repo

```
.
├── lib/                  # App Flutter (core / data / domain / presentation)
├── assets/               # Immagini e icone (logo Viva Servizi incluso)
├── android/ ios/ web/ test/
├── Backend-WFM-VIVA/     # Backend unico (Node): API tablet, assegnazioni, SSE
├── Cruscotto-WFM/        # Frontend web del pianificatore (React/Vite)
└── pubspec.yaml
```

## Cosa fa l'app sul campo

Funzionalità **verificate sul dispositivo**, oltre a elenchi/dettaglio, ciclo di
vita dell'intervento e realtime:

### Creazione dal campo (local-first)

Il tecnico crea **Ordini**, **Avvisi** e **OdL a partire da un Avviso**. L'oggetto
nasce con un numero provvisorio `TMP-…`, resta **sul tablet** (persistito, sopravvive
al riavvio) ed è marcato **DA SINCRONIZZARE** finché non viene inviato.

### Centro di sincronizzazione

Schermata **«Da sincronizzare»** ([`sync_center_screen.dart`](lib/presentation/features/sync/sync_center_screen.dart))
con due schede — *Ordini* e *Avvisi* — e, per ogni elemento, la scelta della
destinazione:

- **Cruscotto** → funzionante: il backend registra l'oggetto, **crea l'assegnazione
  al CID** e pubblica l'evento SSE, quindi il pianificatore lo vede subito;
- **SAP (diretto)** → dichiarato **non configurato**: il pulsante c'è, ma non
  simula nulla (vedi *Limiti noti*).

L'azione è raggiungibile ovunque serva — sidebar con contatore, AppBar delle liste
e dei dettagli, banner sull'oggetto non ancora inviato, e proposta immediata subito
dopo la creazione.

### Tendine alimentate dal cruscotto

Nessun catalogo è più scritto nel codice dell'app: tipi OdL, campi specifici per
tipo, motivi di sospensione, stati e priorità degli avvisi, attività PM arrivano da
`GET /anagrafica/wo-types`, `/anagrafica/wo-fields?type=`, `/anagrafica/lookups/:kind`.
Se il cruscotto non serve un catalogo, la tendina lo dichiara invece di inventare valori.

### Mappa degli interventi

OdL **e** Avvisi sulla stessa mappa, posizionati sull'**indirizzo di intervento**
(`INDIRIZZO_LAVORO`). Poiché SAP non trasmette le coordinate, l'indirizzo viene
convertito da [`GeocodingService`](lib/core/services/geocoding_service.dart)
(Nominatim/OpenStreetMap) con **cache persistente** e un massimo di una richiesta
al secondo. Se un giorno SAP valorizzerà latitudine/longitudine, quelle avranno la
precedenza senza modifiche all'app. Un contatore indica quanti oggetti **non sono
localizzabili** (indirizzo assente o non trovato), invece di farli sparire.

Fondo **ArcGIS (Esri)** pubblico — chiaro, stradale, topografico, satellite — con
i colori di stato del cruscotto, ricerca di indirizzi (geocodificatore Esri),
raggruppamento dei segnaposto, pulsante **Naviga** e elenco ordinato per distanza.

**Rete idrica Viva Servizi (zona Ancona 60128).** Da zoom 16 la mappa disegna la rete
come sulla mappa Viva: condotte di adduzione (rosse) e di distribuzione (verdi) lungo le
vie con materiale e diametro, allacci tratteggiati rosa, contatori (pallini verdi) e
riduttori di pressione (quadrati rossi, codice AN..). Ogni contatore ha un indirizzo
reale (via, civico, CAP): toccandolo si apre la scheda con **Crea OdL** (SOST, la
matricola la inserisce il tecnico), **Crea avviso** e **Naviga**; dal riduttore si crea
uno ZA02 col ciclo CONRID1. Toccando "Avvicinati per vedere la rete" la mappa va sulla
zona. Il file `assets/rete_viva/rete_viva_ancona.geojson` si rigenera con
`python tools/rete_viva/genera_rete_viva.py` (vie ed edifici da OpenStreetMap, indirizzi
da OSM o da Esri); per un'altra zona basta cambiare `BBOX` nello script.

**Creare OdL e avvisi dalla mappa (senza chiave).**

- *Contatori degli interventi*: il backend non ha un'anagrafica dei contatori, ogni
  contatore arriva sull'OdL/avviso che lo riguarda. La mappa li mostra da vicino
  (zoom ≥ 15) come pallini verdi accanto all'intervento, uno per matricola. La scheda
  (matricola, marca, calibro, interventi) offre **Crea OdL SOST** (la "casetta" del
  modulo completa i dati dal backend), **Crea avviso** e **Naviga**.
- *Punto scelto*: **tenendo premuto** su un punto qualsiasi (o scegliendo un indirizzo
  cercato) si ottiene l'indirizzo reale del punto (`reverseGeocode` Esri) e si crea
  l'OdL o l'avviso già con via, civico, comune, CAP e posizione.

Nessun punto inventato: contatori dal backend, indirizzi da Esri.

**Rete Viva Servizi (contatori, riduttori di pressione).** I livelli del servizio
`VIVA_SERVIZI_Ambito_Intervento_WFL1` sono **protetti** (499 *Token Required*):
senza chiave la mappa non mostra né punti né interruttori (niente dati
inventati); la sezione compare nel pannello *Fondo mappa* solo con la chiave. Con una chiave di accesso ArcGIS fornita da Viva
Servizi si attivano in compilazione, senza toccare il codice:

```bash
flutter run --dart-define=ARCGIS_TOKEN=<chiave>
```

(opzionale `--dart-define=ARCGIS_RETE_URL=<FeatureServer>` se cambia il servizio).
Da zoom 16 in su si caricano i punti della zona visibile; toccandone uno si apre la
scheda con gli attributi del livello e le azioni **Naviga**, **Crea avviso**
(matricola e posizione precompilate) e **Crea OdL** (contatore → SOST con la
matricola; riduttore → ZA02 col ciclo CONRID1). La matricola si riconosce dal nome
del campo ArcGIS: va verificata sul servizio reale appena c'è la chiave.



### Chiusura dell'OdL e avviso associato

L'invio dell'esito **chiude l'OdL** e lo toglie dal tablet; insieme all'OdL si toglie anche
l'**avviso associato** (`avvisoOrigine`). Il backend non permette di eliminare un avviso
(`DELETE /notifications/:id` risponde 501) e continua a elencarlo in `GET /notifications`:
il tablet quindi ricorda gli avvisi rimossi ([`AvvisiRimossiStore`](lib/core/services/avvisi_rimossi_store.dart),
su disco) e non li mostra più, nemmeno dopo un aggiornamento o un riavvio. Un avviso nato sul
tablet e non ancora inviato si elimina dall'archivio locale. Vale anche con l'esito in coda
offline. Se un altro OdL aperto è ancora associato allo stesso avviso, l'avviso resta.
Lo stesso vale se l'OdL viene eliminato dall'app.

**Eliminare sul tablet vale solo per il tablet.** Eliminare un OdL (glissata in lista o
"Elimina Ordine") o un avviso non chiama il backend, che non cancella né ordini né avvisi
(501): il tablet ricorda cosa è stato eliminato ([`OdlRimossiStore`](lib/core/services/odl_rimossi_store.dart),
[`AvvisiRimossiStore`](lib/core/services/avvisi_rimossi_store.dart), su disco) e non lo mostra più,
né in elenco, né in mappa, né nei contatori, anche dopo un aggiornamento o un riavvio. Sul
cruscotto e per gli altri tecnici l'oggetto resta. Un oggetto nato sul tablet e non ancora
inviato si elimina dall'archivio locale. Eliminando un OdL si elimina anche il suo avviso.

### Materiali e magazzini

"Aggiungi componenti": un elenco a tendina con caselle da spuntare. Per ogni materiale spuntato
compaiono i **magazzini in cui è disponibile**, con la quantità rimanente di ciascuno
(*Magazzino 1 (rimanenti: 30)*), e il tecnico sceglie da quale prelevare. La giacenza è
**separata per magazzino**: prelevare 2 pezzi dal Magazzino 1 porta 30 → 28 e lascia il Magazzino 2
a 20; poi 1 dal Magazzino 2 porta 20 → 19.

Dati: i magazzini sono quelli di `/anagrafica/warehouses`. Le giacenze per magazzino sono
`stockPerMagazzino` del backend se lo manda (lista `[{warehouseCode, quantity}]` o mappa
`{W01: 30}`). Oggi il backend manda UN solo stock per materiale, nel suo magazzino predefinito
(`defaultWarehouseCode`): per far trovare ogni materiale in più magazzini, il file
`assets/anagrafica/giacenze_magazzini.json` completa gli altri, generato dai dati di
`anagrafiche.json` con `python tools/anagrafica/genera_giacenze.py` (nel magazzino predefinito
resta lo stock vero del backend; negli altri due il 70% e il 40% di quello stock). Non appena il
backend manda `stockPerMagazzino`, quello ha la precedenza e il file non serve più.
Il backend non scala le giacenze quando arriva l'esito: il tablet tiene il conto dei prelievi per
magazzino ([`StockImpegnatoStore`](lib/core/services/stock_impegnato_store.dart), su disco) e
li sottrae dalla giacenza del backend; tolto un materiale o eliminato l'OdL, la quantità torna
al suo magazzino. 
### Impostazioni e voce di lettura

Le **impostazioni si salvano sul tablet** ([`ImpostazioniStore`](lib/core/services/impostazioni_store.dart))
e tornano dopo il riavvio: tema, frequenza di sincronizzazione, qualità foto, dimensione
di testo e icone, voce di lettura.

**Voce di lettura** (Impostazioni → *Voce di lettura*): è la voce dell'altoparlante
"Leggi a voce alta" dei campi di testo (la dettatura col microfono scrive soltanto, non ha
una voce). Si sceglie fra le **voci italiane installate sul tablet**, si regolano **tono**
(grave/acuto) e **velocità**, e "Prova la voce" la fa sentire. Android non indica se una
voce è maschile o femminile: se serve una voce più maschile si prova una delle altre voci
e si abbassa il tono; altre voci si installano da Impostazioni Android → Sintesi vocale.

### Chiusura intervento

La **firma del cliente** si raccoglie direttamente nella pagina di esito
([`signature_pad.dart`](lib/presentation/widgets/signature_pad.dart)): si firma col
dito o con la penna, si può cancellare e rifare.

### Materiali

I materiali impegnati sul campo sono **persistiti sul tablet** (in `OdlExtension`)
e compaiono nella scheda *Materiali* insieme a quelli dell'ordine. Se la quantità
richiesta **supera la disponibilità di magazzino l'impegno è rifiutato**, con
l'elenco delle righe fuori stock: non è più un avviso ignorabile.

## Architettura dell'app

Clean Architecture su tre strati (`domain` / `data` / `presentation`), con
inversione delle dipendenze centralizzata in
[`core_providers.dart`](lib/presentation/providers/core_providers.dart).

- **Navigazione** — guscio persistente
  ([`AppShell`](lib/presentation/features/shell/app_shell.dart)) con
  `StatefulShellRoute`: sidebar su tablet, `NavigationBar` su smartphone; quattro
  destinazioni (Home, Ordini, Avvisi, Mappa). Dettagli e sotto-flussi a schermo intero.
- **Offline-first** — cache locale + coda di sincronizzazione persistente, retry
  in background (Workmanager).
- **Realtime** — [`SseService`](lib/core/network/sse_service.dart) consuma
  `GET /api/stream`: quando il pianificatore assegna/cambia stato dal cruscotto,
  le liste del tablet si aggiornano da sole (evento `assegnazioni`).
- **Sorgente dati remota** — **nessun mock**: unica implementazione
  [`HttpRemoteDataSource`](lib/data/datasources/remote/http_remote_data_source.dart)
  (Dio con interceptor Bearer + retry). Mapper manuali in
  [`mappers.dart`](lib/data/models/mappers.dart), **nessun codegen** (`.g.dart`).
- **Dati creati sul campo** — [`LocalCreationStore`](lib/data/local/local_creation_store.dart)
  (box Hive) conserva OdL e avvisi creati finché non partono;
  [`creation_provider.dart`](lib/presentation/providers/creation_provider.dart)
  li fonde in cima agli elenchi e gestisce l'invio, per elemento o in blocco.
  Un record illeggibile viene saltato senza compromettere la lista.


## Avviare l'app

```bash
flutter pub get
flutter run
```

Poi imposta `backendBaseUrl` in [`app_config.dart`](lib/core/config/app_config.dart)
secondo il target (tabella sopra). Non esiste più nessun flag `useMockData`: l'unica
sorgente è il backend.

## Avviare il backend

```bash
cd Backend-WFM-VIVA
npm install
npm run dev        # sviluppo con reload (tsx)
```

- **API tablet** : `http://localhost:4000/api/v1`
- **Realtime SSE** : `http://localhost:4000/api/stream`
- **Health** : `http://localhost:4000/api/health`

Prerequisiti: **VPN Vivaservizi** attiva (per `POST /api/refresh` verso SAP),
`data/tecnici.json` con i CID di login.

## Anagrafica tecnici e login

Il login accetta **solo CID presenti** in `Backend-WFM-VIVA/data/tecnici.json`
(la password **non** è verificata: va bene qualsiasi). I CID sono allineati a quelli
del cruscotto — `TEC001` … `TEC005`:

```json
[
  { "cid": "TEC001", "nome": "Marco", "cognome": "Bianchi", "workCenter": "WC01", "squadra": "Squadra A", "email": "marco.bianchi@vivaservizi.local" },
  { "cid": "TEC002", "nome": "Luca",  "cognome": "Rossi",   "workCenter": "WC01", "squadra": "Squadra A", "email": "luca.rossi@vivaservizi.local" }
]
```

Il file viene letto **all'avvio**: dopo averlo modificato riavviare il backend.

> Il cruscotto web, al contrario, **non verifica nulla** al login (store locale):
> qualsiasi utente vi entra. È normale che un CID accettato lì venga rifiutato dal
> tablet se non è in `tecnici.json`.

## Cataloghi (anagrafiche)

`Backend-WFM-VIVA/data/anagrafiche.json` alimenta tutte le tendine del tablet:
tipi OdL, campi per tipo, lookup, cause/soluzioni, materiali (con `stockDisponibile`),
magazzini, marche contatori. I valori sono **allineati al cruscotto**
(`Cruscotto-WFM/src/types` e `src/mocks`), così i due strumenti usano gli stessi codici.

Anche questo file è letto **all'avvio**: dopo una modifica, riavviare il backend.

## Test

```bash
flutter test        # unit + widget (verdi)
```

## Limiti noti

Dichiarati apposta, per non far credere che il flusso sia completo:

- **Invio diretto a SAP**: non configurato sul backend. Nel centro di
  sincronizzazione il pulsante *SAP* risponde con un messaggio esplicito e **non
  effettua alcuna chiamata**. Oggi la strada valida è *Cruscotto*.
- **Esito → SAP**: l'esito si ferma nel backend, manca la scrittura SOAP
  (`submitEsito`).
- **Materiali → cruscotto**: sono salvati e mostrati sul tablet, ma l'entità
  `Esito` dell'app non ha ancora un campo materiali, quindi `POST /esiti` li invia
  vuoti anche se il backend saprebbe riceverli (`materialiUsati`).
- **Firma**: viene tracciata e determina `customerSigned`, ma **non è archiviata**:
  servirebbe l'upload allegati, che risponde `501`.
- **Allegati (foto/documenti)**: acquisizione sul dispositivo sì, upload `501`.
- **Numero definitivo**: un oggetto inviato conserva l'id `TMP-…` finché SAP non
  assegna il numero reale. Non è un errore: l'invio è già avvenuto.
- **Geocodifica**: richiede Internet (Nominatim). Gli indirizzi già risolti restano
  in cache; la precisione è quella di OpenStreetMap.
- **Push FCM** non attive: aggiornamento via SSE / polling.
- **Sessioni in memoria**: al riavvio del backend i tablet rifanno login.

### Attenzione operativa

Dopo un `POST /api/refresh` SAP può restituire un lotto diverso di oggetti: le
assegnazioni che puntano a oggetti non più presenti diventano **orfane** e i relativi
OdL/avvisi **non compaiono** né in elenco né in mappa. Si verificano con
`GET /api/assegnazioni` (campo `orfane`).
