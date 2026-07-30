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
├── Backend-WFM-VIVA/     # Backend unico del cruscotto (Node) — solo lettura per noi
└── pubspec.yaml
```

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
(la password **non** è verificata : qualsiasi password ). Formato:

```json
[
  { "cid": "MROSSI", "nome": "Mario", "cognome": "Rossi", "workCenter": "SP1", "squadra": "Squadra A", "email": "mario.rossi@vivaservizi.local" }
]
```

```json
[
  { "cid": "LBIANCHI", "nome": "Luca", "cognome": "Bianchi", "workCenter": "SP1", "squadra": "Squadra B", "email": "luca.bianchi@vivaservizi.local" }
]
```

## Test

```bash
flutter test        # unit + widget (verdi)
```

## Limiti noti (dichiarati dal backend)

- L'**esito** si ferma nel backend: manca la scrittura verso SAP (`submitEsito` SOAP).
- **Allegati / creazione dal campo** → `501` (gli oggetti nascono in SAP).
- **Push FCM** non attive: aggiornamento via SSE / polling.
- **Sessioni in memoria**: al riavvio del backend i tablet rifanno login.