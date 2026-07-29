# CONCLUSIONE — Backend unico Cruscotto + procedura d'integrazione app mobile

**Data:** 2026-07-28
**Analizzati:**
- Backend aggiornato del collega: [`Backend-WFM-VIVA/`](Backend-WFM-VIVA) (Node/TS, porta 4000)
- Documento funzioni backend: `DOC_ALE/10-BACKEND-FUNZIONI.md`
- Il mio frontend Flutter (stato attuale, con le modifiche "ibride" delle scorse sessioni)
- Il vecchio middleware Java → **eliminato** (confermato: cartella `middleware/` assente)

---

## 0. Conclusione in tre righe

1. **Il backend del collega ora fa TUTTO**: dati SAP (letture), assegnazioni, e il
   **contratto tablet `/api/v1` identico al mio vecchio middleware**. Il middleware Java
   non serve più. ✅
2. Il collega ha scritto il mapper del tablet ([`toMobile.ts`](Backend-WFM-VIVA/src/mapping/toMobile.ts))
   **su misura dei miei mapper Dart** (`mappers.dart`): il JSON combacia campo per campo,
   compresi i campi nuovi (cliente, indirizzo, appuntamento, contatore, guasto, codifica).
3. **Per l'app cambia pochissimo**: puntare a `http://<host>:4000/api/v1` e **annullare
   l'esperimento ibrido** (doppio backend + mapper SAP-shaped) che avevo fatto quando il
   `/api/v1` non esisteva ancora. Novità di comportamento: **il tablet vede solo gli
   ordini/avvisi ASSEGNATI** al tecnico.

---

## 1. Cosa è cambiato: da due backend a UNO

Nelle sessioni scorse il `/api/v1` non c'era, quindi avevo fatto un **ibrido**: letture
dal cruscotto (`/api/odl`, SAP-shaped) + scritture sul mio middleware Java. Ora il collega
ha aggiunto al SUO backend il contratto tablet completo → **un solo backend per tutto**.

```
                 SAP (push SOAP / pull selezione)
                          │
                          ▼
        ┌─────────────────────────────────────────┐
        │        BACKEND-WFM (Node, :4000)         │
        │                                          │
        │  /api            → dati SAP + SSE (cruscotto)
        │  /api/assegnazioni → ordine↔tecnico (cruscotto)
        │  /api/v1         → TABLET (contratto vecchio middleware)
        └─────────────────────────────────────────┘
              ▲                         ▲
         Cruscotto (React)         Tablet (Flutter)  ← la mia app
```

---

## 2. Architettura del backend (3 gruppi di API)

Un solo processo, porta 4000. Store su file in `Backend-WFM-VIVA/data/`
(`state.json` = ordini/avvisi SAP, `assignments.json` = assegnazioni,
`tecnici.json` = anagrafica CID, `anagrafiche.json` = materiali/cause/…).

| Gruppo | Base | Chi | Cosa |
|--------|------|-----|------|
| Dati SAP | `/api` | Cruscotto | `POST /api/refresh` (ricarica da SAP), `GET /api/odl`, `/api/avvisi`, `GET /api/stream` (SSE), `/api/health`, `/api/ingest-log` |
| Assegnazioni | `/api/assegnazioni` | Cruscotto | `GET`/`POST`/`POST bulk`/`PATCH :tipo/:id/stato`/`DELETE :tipo/:id` |
| **Tablet** | **`/api/v1`** | **La mia app** | `POST /auth/login`, `GET /work-orders`, `/work-orders/:id`, `PATCH /work-orders/:id/status`, `PATCH /work-orders/:id`, `POST /esiti`, `GET /notifications(/:id)`, `GET /anagrafica/*`, `POST /devices` |

Ingestione da SAP: `POST /soap/pm` (SAP fa da client SOAP) **oppure** `POST /api/refresh`
(il backend fa il pull in modalità `selezione` — richiede VPN).

---

## 3. Il contratto tablet `/api/v1` — **identico al vecchio middleware**

Dal codice [`mobile.ts`](Backend-WFM-VIVA/src/routes/mobile.ts) e
[`toMobile.ts`](Backend-WFM-VIVA/src/mapping/toMobile.ts):

- **Stessi path e forma** del mio middleware: `GET /work-orders` → `{ workOrders: [...] }`,
  `GET /notifications` → `{ notifications: [...] }`, login → `{cid,nome,cognome,email,
  workCenter,squadra,token,expiresAt}`, `POST /esiti` → `{esitoId}`, `GET /anagrafica/*`.
- **`toMobile.ts` è scritto per combaciare con `mappers.dart`** dell'app (lo dichiara in
  testa al file): i campi `num`/`bool` sono già convertiti (niente stringhe grezze che
  fanno crashare `as num?`/`as bool?`), le date `0000-00-00` → `null`.
- **Include i campi nuovi** già nel formato app: `customer`, `address`/`indirizzoOggetto`/
  `indirizzoIntervento`, `appointmentDate/StartTime`, `meter`, `tipoAttivitaCodice/Nome`,
  `contratto`, e sull'avviso `codiceGuasto/Causa`, `dataInizio/FineGuasto`, `descrizioneEstesa`.
- **Autenticazione**: ogni endpoint (tranne login) richiede `Authorization: Bearer <token>`.
  Il **CID si ricava dal token**, non da un parametro. Login: il CID deve esistere in
  `data/tecnici.json`; la password **non** è verificata (l'auth reale SAP è fuori scopo).
- **Solo gli oggetti ASSEGNATI**: `GET /work-orders` restituisce solo gli ordini assegnati
  al CID del token; il dettaglio dà 404 se non è suo. Lo **stato** che vede il tecnico è
  quello dell'**assegnazione** (RICEVUTO/IN_ESECUZIONE/…), non lo stato SAP grezzo.

> **Conseguenza:** il mio `mappers.dart` originale (`workOrderFromJson`/`avvisoFromJson`)
> funziona così com'è. **Non serve** il mapper SAP-shaped `cruscotto_mappers.dart` che
> avevo scritto per l'ibrido.

---

## 4. Modello ad ASSEGNAZIONI — perché il tablet può risultare vuoto

Il tablet non vede "tutti gli oggetti SAP", vede **il lavoro che il pianificatore gli ha
assegnato**. Perché un ordine compaia sul tablet servono **due passi lato cruscotto**:

1. **Caricare i dati SAP nel backend** → `POST /api/refresh` (o push SOAP da SAP).
2. **Assegnare** l'oggetto al tecnico → `POST /api/assegnazioni {tipo,id,technicianCID}`.

Solo allora il tablet loggato con quel CID lo trova in `GET /api/v1/work-orders`.
Le assegnazioni stanno in un file separato (`assignments.json`): il refresh SAP svuota
ordini/avvisi ma **non** cancella le assegnazioni. Un'assegnazione verso un oggetto non
presente nello store è "orfana" → invisibile al tablet finché l'oggetto non torna.

→ **Il tablet NON deve chiamare `POST /api/refresh`**: è un'azione del pianificatore
(svuota e ricarica lo store condiviso). Il "refresh" del tablet deve solo **ri-leggere**
`GET /work-orders` (per prendere nuove assegnazioni).

---

## 5. Stato attuale del mio frontend e cosa va cambiato

Nelle scorse sessioni, per l'ibrido, avevo introdotto:
- `AppConfig`: due base URL (`middlewareBaseUrl` :8080 **morto**, `cruscottoBaseUrl` :4000/api);
- `DioClient.dioRead` (secondo client);
- letture su `/api/odl`·`/api/avvisi` con **`cruscotto_mappers.dart`** (SAP-shaped);
- SSE + **auto `POST /api/refresh` all'avvio** + pulsante "Aggiorna da SAP".

Con il `/api/v1` questo va **ricondotto a un solo backend**:

| Pezzo ibrido | Azione |
|--------------|--------|
| `middlewareBaseUrl` :8080 (Java, eliminato) | → `http://<host>:4000/api/v1` (tutto il contratto app) |
| Letture su `/api/odl` + `cruscotto_mappers.dart` | **Annullare**: tornare a `/work-orders`·`/notifications` con `workOrderFromJson`/`avvisoFromJson` |
| `cruscotto_mappers.dart` | Eliminare (non più usato) |
| `dioRead` / `cruscottoBaseUrl` | Tenere **solo per l'SSE** (`GET /api/stream` sta su `/api`, non `/api/v1`) |
| Auto `POST /api/refresh` all'avvio + pulsante "Aggiorna da SAP" | **Rimuovere**: il tablet non ricarica SAP. Il refresh diventa un semplice re-GET |
| `getCapabilities` → `allEnabled` | **Tenere** (il backend non ha `/capabilities`; tutte le sezioni restano visibili) |
| SSE realtime | **Tenere**, aggiungendo l'evento `assegnazioni` (quando il pianificatore assegna, la lista si aggiorna) |

---

## 6. Cosa funziona subito / cosa no

**Funziona (contratto pieno):** login, liste e dettagli ordini/avvisi assegnati, cambio
stato (avvia/sospendi/concludi), note, **invio esito** (salvato nel backend), anagrafiche,
registrazione token FCM, realtime SSE.

**Risponde `501` di proposito** (gli oggetti nascono in SAP): creazione ordine/avviso dal
campo, generazione ordine da avviso, upload allegati (foto/firma), eliminazioni.
→ L'app deve **gestire il 501** su queste azioni (disabilitarle o mostrare "non disponibile").

**Non ancora attivo:**
- L'esito **si ferma sul backend**: manca la scrittura verso SAP (`submitEsito` SOAP).
- **Push FCM non attive**: aggiornamento in **polling ~20s** (o via SSE se collegato).
- **Sessioni in memoria**: al riavvio del backend i tablet rifanno login.

---

## 7. PROCEDURA DI INTEGRAZIONE (app mobile ⇄ backend)

> ✅ **APPLICATA il 2026-07-28** (solo app, backend del collega NON toccato).
> `flutter analyze` = 0 errori; test = 39/39. Modifiche: `app_config.dart` (un
> backend :4000, dati `/api/v1`, SSE `/api`), `http_remote_data_source.dart`
> (letture tornate a `/work-orders`·`/notifications` con `workOrderFromJson`/
> `avvisoFromJson`), rimossi `cruscotto_mappers.dart` e `refreshFromCruscotto`,
> `realtime_provider.dart` (niente più auto-`/api/refresh`; evento `assegnazioni`;
> "Aggiorna" = re-GET). Resta da rifinire: gestione grafica del `501` e il pannello
> filtri "estrazione SAP" (dateFrom/dateTo/centro) ora inattivo su `/api/v1`.

### A. Configurazione (una riga)
In [`app_config.dart`](lib/core/config/app_config.dart), per il flavor `dev`:
- backend dati/scritture → **`http://<IP-o-localhost>:4000/api/v1`**
- base SSE → **`http://<IP-o-localhost>:4000/api`** (lo stream sta su `/api/stream`)

> `localhost` se app e backend girano sullo stesso PC (Web/Desktop); l'IP DHCP del PC per
> il tablet fisico sulla stessa Wi-Fi. Aggiornare l'IP quando cambia.

### B. Sorgente dati (annullare l'ibrido)
In [`http_remote_data_source.dart`](lib/data/datasources/remote/http_remote_data_source.dart):
1. `getWorkOrders`/`getWorkOrderDetail` → tornano a `GET /work-orders(/:id)` su `_dio` con
   `workOrderFromJson`, leggendo `{ workOrders }`.
2. `getAvvisi`/`getAvvisoDetail` → tornano a `GET /notifications(/:id)` con `avvisoFromJson`.
3. Rimuovere `refreshFromCruscotto` (o farlo diventare un semplice re-GET, senza `/refresh`).
4. Eliminare l'uso di `cruscotto_mappers.dart` e il file stesso.
5. `getCapabilities` resta `allEnabled`.

### C. Realtime (tenere, corretto)
- L'SSE resta su `dioRead` con base `…/api` → `GET /api/stream`.
- Nel [`realtime_provider.dart`](lib/presentation/providers/realtime_provider.dart):
  togliere l'auto-`refresh`; sugli eventi `assegnazioni`/`ordini`/`avvisi`/`snapshot`/`reset`
  invalidare `workOrdersProvider`, `avvisiProvider`, `dashboardStatsProvider`.
- Il pulsante "Aggiorna" delle liste → invalida i provider (re-GET), **non** chiama `/refresh`.

### D. 501 sulle azioni non supportate
Creazione ODL/avviso, genera-ODL-da-avviso, upload allegati: intercettare `501` e mostrare
"Funzione non disponibile su questo backend" invece di un errore generico.

### E. Prerequisiti lato backend/cruscotto (per vedere dati)
1. Backend avviato (`npm run dev` in `Backend-WFM-VIVA/`), **VPN attiva**.
2. `data/tecnici.json` contiene il **CID** con cui fai login.
3. Pianificatore: `POST /api/refresh` (carica SAP) **poi** `POST /api/assegnazioni`
   (assegna al tuo CID). Solo allora il tablet mostra quell'ordine.

---

## 8. Checklist di test end-to-end

- [ ] Backend attivo su :4000, VPN on; `GET http://localhost:4000/api/health` risponde.
- [ ] `POST /api/refresh` → store popolato (ordini/avvisi > 0).
- [ ] `POST /api/assegnazioni {tipo:"odl", id:"<ORDINE>", technicianCID:"<CID>"}`.
- [ ] App: login con `<CID>` → token ottenuto.
- [ ] App: lista Ordini mostra **solo** l'ordine assegnato; dettaglio apre e mostra i
      campi (tipo attività, contratto, indirizzo/cliente se valorizzati, codice guasto sugli avvisi).
- [ ] App: cambio stato (Avvia/Sospendi/Concludi) → il cruscotto vede la card cambiare
      (SSE) e `GET /api/assegnazioni` riporta il nuovo stato/esito.
- [ ] App: creazione ODL / upload allegato → gestito come "non disponibile" (501).

---

## 9. Punti aperti / domande al collega

1. **Esito → SAP**: quando verrà collegato `submitEsito` SOAP? Oggi l'esito resta nel backend.
2. **Allegati (foto/firma)**: previsti? Ora `501`. Per il campo sono importanti.
3. **Login/password**: oggi la password non è verificata. Quale auth reale in produzione?
4. **Anagrafiche** (`data/anagrafiche.json`): chi le popola? Se vuote, esiti/materiali
   nel tablet restano senza liste.
5. **Realtime tablet**: SSE va bene anche per il tablet, o preferite il polling 20s citato
   nel documento? (l'app è già pronta per l'SSE su `/api/stream`).
6. **Sessioni in memoria**: al riavvio backend il tablet fa 401 → l'app deve ri-loggare
   automaticamente (gestione del 401 → re-login).

---

### Sintesi operativa
Il lavoro grosso è **annullare l'ibrido** e puntare l'app al solo `:4000/api/v1`, tenendo
l'SSE su `:4000/api/stream`. Il resto del contratto (login, liste, stato, esito,
anagrafiche) **combacia già** con i miei mapper: il collega li ha costruiti apposta.
Da capire subito col collega: **assegnazioni** (il tablet è vuoto finché non ti assegnano),
**esito→SAP** e **allegati**.
