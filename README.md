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


>  **Documentazione completa** — funzionalità per il tecnico + API del backend:
> **[DOCUMENTAZIONE.md](DOCUMENTAZIONE.md)**.


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

### Chiusura intervento

La **firma del cliente** si raccoglie direttamente nella pagina di esito
([`signature_pad.dart`](lib/presentation/widgets/signature_pad.dart)): si firma col
dito o con la penna, si può cancellare e rifare. Prima era un semplice interruttore
e nessuna firma veniva tracciata.

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