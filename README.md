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


## Stack

- **Mobile** — Flutter 3 (Dart ≥ 3), Riverpod, go_router, Dio, Hive,
  mobile_scanner, flutter_map, Firebase Messaging, Workmanager, pdf/printing.
- **Backend** — `Backend-WFM-VIVA/` (Node/TS, Express, porta 4000): riceve i dati
  SAP (push SOAP o pull `selezione`), li normalizza in JSON e li distribuisce a
  **cruscotto** e **tablet** via REST + **SSE**. Store su file (non è un DB).
  *Sviluppato dal collega: non va modificato dall'app.*

## Struttura del repo

```
.
├── lib/                  # App Flutter (core / data / domain / presentation)
├── assets/               # Immagini e icone (logo Viva Servizi incluso)
├── android/ ios/ web/ test/
├── Backend-WFM-VIVA/     # Backend unico del cruscotto (Node) — solo lettura per noi
└── pubspec.yaml
```

## Ambito funzionale

L'app copre i moduli **M1–M14** del capitolato:

| | Modulo | | Modulo |
|---|---|---|---|
| M1 | Autenticazione (CID + token) | M8 | Allegati (foto/documenti/firme) |
| M2 | Elenco OdL | M9 | Avvisi (+ preventivo/firma/PDF) |
| M3 | Dettaglio OdL (schede) | M10 | Creazione OdL sul campo |
| M4 | Ciclo di vita OdL | M11 | Modalità offline + coda sync |
| M5 | Esito | M12 | Geolocalizzazione |
| M6 | Contatori | M13 | Notifiche push |
| M7 | Componenti e materiali | M14 | Impostazioni locali |

> Alcune azioni (creazione OdL/avviso dal campo, upload allegati, genera-OdL-da-avviso)
> oggi il backend le rifiuta con **`501`**: gli oggetti nascono in SAP. L'app le
> mostra come "non disponibili".

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

## Integrazione col backend

L'app parla con ** backend** (`:4000`). In
[`app_config.dart`](lib/core/config/app_config.dart) si imposta **una sola riga**,
`backendBaseUrl` (solo l'origine host:porta); da lì derivano i due percorsi dello
**stesso** server:

| Getter | Path | Uso |
|--------|------|-----|
| `apiBaseUrl` | `<backend>/api/v1` | dati, login, esiti, stato, anagrafiche (contratto tablet) |
| `streamBaseUrl` | `<backend>/api` | realtime SSE (`GET /api/stream`) |

`backendBaseUrl` per target di esecuzione:

| Target | Valore |
|--------|--------|
| Tablet fisico (Wi-Fi) | `http://<IP-LAN-del-PC>:4000` (NON `localhost`) |
| Web / Desktop (stesso PC) | `http://localhost:4000` |
| Emulatore Android (AVD) | `http://10.0.2.2:4000` |

> Cleartext HTTP: gli IP di sviluppo vanno elencati in
> [`network_security_config.xml`](android/app/src/main/res/xml/network_security_config.xml).

### Modello ad assegnazioni (importante)

Il tablet mostra **solo gli oggetti assegnati** al CID del token. Perché un OdL
compaia servono, lato **cruscotto/pianificatore**:

1. `POST /api/refresh` — carica i dati SAP nel backend (richiede VPN).
2. `POST /api/assegnazioni` — assegna l'oggetto a un tecnico (CID).

Senza assegnazioni la lista è **vuota**: è corretto, non è un bug. Passi e comandi
pronti in **[GUIDA_OPERATIVA.md](GUIDA_OPERATIVA.md)**.

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