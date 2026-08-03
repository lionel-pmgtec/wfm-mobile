# Documentazione — WFM Mobile & Backend Cruscotto (Viva Servizi)

**Sistema di Gestione degli Ordini di Lavoro sul campo (Work Force Management).**
Documento di riferimento: descrive l'applicazione tablet per i tecnici, il backend
del cruscotto e **tutte le funzionalità già operative**.

- **Destinatari:** tecnici sul campo, pianificatori (cruscotto), team tecnico.
- **Documenti collegati:** [README.md](README.md) (avvio rapido),


> 
> - **Cataloghi selezionabili dal cruscotto** — rimossi tutti i valori hardcoded
>   dalle tendine (tipi OdL, campi per tipo, motivi sospensione, stato/priorità
>   avviso). Ora arrivano dal cruscotto; finché i relativi endpoint non esistono,
>   la tendina mostra *"nessun dato dal cruscotto"* (nessun ripiego inventato).
> - **Creazione sul campo local-first** — Crea OdL, Crea Avviso e OdL-da-Avviso
>   creano l'oggetto **sul tablet** con id provvisorio `TMP-…`; resta locale
>   finché l'operatore non preme **Sincronizza** (vedi §4.13).

---

## Indice

1. [Cos'è il sistema](#1-cosè-il-sistema)
2. [Architettura](#2-architettura)
3. [Il modello ad assegnazioni](#3-il-modello-ad-assegnazioni-come-arriva-il-lavoro-al-tecnico)
4. [Guida per il tecnico (funzionalità dell'app)](#4-guida-per-il-tecnico--funzionalità-dellapp)
5. [Backend Cruscotto (funzionalità e API)](#5-backend-cruscotto--funzionalità-e-api)
6. [Stato delle funzionalità](#6-stato-delle-funzionalità)
7. [Glossario](#7-glossario)

---

## 1. Cos'è il sistema

Il sistema permette al **tecnico** di ricevere sul tablet gli **Ordini di Lavoro
(OdL)** e gli **Avvisi** che il **pianificatore** gli assegna dal cruscotto, di
eseguirli sul campo (avviare, sospendere, concludere), di registrare l'**esito**
(letture contatore, materiali usati, ore, firma) e di vedere gli aggiornamenti in
**tempo reale**. I dati provengono da **SAP**.

Tre attori:

| Attore | Strumento | Cosa fa |
|--------|-----------|---------|
| **SAP** | ZWFMT_SERVIZIO_PM | Sorgente degli ordini/avvisi (anagrafica tecnica). |
| **Pianificatore** | Cruscotto web | Carica i dati da SAP e **assegna** il lavoro ai tecnici. |
| **Tecnico** | **App tablet (questa)** | Vede e lavora **solo i propri** OdL/avvisi. |

---

## 2. Architettura

```
                         (assegna il lavoro)
   Cruscotto web  ─────────────────────────────────┐
   (pianificatore)                                 ▼
                                    ┌───────────────────────────────┐
   SAP DG1  ── SOAP/push ─────────► │   BACKEND-WFM (Node, :4000)   │
   ZWFMT_SERVIZIO_PM  ◄─ pull ──────│  • /api        dati + SSE     │
                                    │  • /api/assegnazioni          │
                                    │  • /api/v1   contratto tablet │
                                    └───────────────────────────────┘
                                                     ▲
                          REST/JSON + SSE (realtime) │
                                                     ▼
                                    ┌───────────────────────────────┐
                                    │   APP TABLET (Flutter)        │  ← il tecnico
                                    └───────────────────────────────┘
```

- **App tablet** — Flutter (Riverpod, go_router, Dio). Architettura pulita a tre
  strati (dominio / dati / presentazione). Funziona anche **offline** con coda di
  sincronizzazione.
- **Backend Cruscotto** — Node/TypeScript (Express). Riceve i dati SAP, li
  normalizza in JSON, li distribuisce a cruscotto e tablet via REST + **SSE**
  (aggiornamenti in tempo reale). Persistenza su file.
- **Backend**: l'app usa `/api/v1` (dati) e `/api/stream`
  (realtime) dello stesso server (porta 4000).

---

## 3. Il modello ad assegnazioni (come arriva il lavoro al tecnico)

Regola fondamentale: **il tecnico vede solo ciò che gli è stato assegnato.** Il
suo CID (identificativo) è legato al token ottenuto al login; ogni richiesta è
filtrata su quel CID. *Un tablet = un tecnico.*

Perché un OdL compaia sul tablet servono due passi lato cruscotto:

1. **Caricamento da SAP** — il pianificatore aggiorna i dati (il backend interroga SAP).
2. **Assegnazione** — il pianificatore assegna l'OdL/avviso a un tecnico (CID).

Solo allora l'oggetto appare nella lista del tecnico. Quando il tecnico cambia
stato o chiude l'intervento, il cruscotto lo **vede in tempo reale**. Se non hai
ancora nulla in lista, è normale: non ti è stato ancora assegnato lavoro.

---

## 4. Guida per il tecnico — funzionalità dell'app

### 4.1 Accesso (login)

- Inserisci il tuo **CID** (utente) e la password → **Accedi**.
- Ottieni una **sessione** valida ~8 ore. Alla scadenza (o al riavvio del server)
  va rifatto il login.
- In alto compaiono nome, centro di lavoro e le icone **notifiche** e **esci**.

### 4.2 Home — il tuo cruscotto giornaliero

- **Saluto** personalizzato (in base all'ora) con la sintesi della giornata.
- **Riepilogo di oggi** — sei contatori per stato: *Assegnato, In esecuzione, In
  pausa, Sospeso, Chiuso, Inviato a SAP*. I contatori con valore si **evidenziano**
  col colore dello stato.
- **Accessi rapidi** — scorciatoie: Crea OdL, Scanner, Standalone, Sincronizza,
  Impostazioni.
- **Navigazione** — barra laterale (tablet) / inferiore (telefono): **Home,
  Ordini, Avvisi, Mappa**.

### 4.3 Elenco Ordini di Lavoro

- Mostra **solo i tuoi** OdL. Ogni card riporta: numero, tipo, descrizione,
  **stato** (badge colorato), **sede tecnica / equipment**, data e **priorità**.
- **Filtri per stato** (chip in alto): Tutti / Assegnato / In esecuzione / In
  pausa / Sospeso / Chiuso / Inviato SAP.
- **Ricerca** per numero, descrizione, cliente, città.
- **Filtri avanzati** (icona regolatori): data, squadra, centro, tecnico.
- **Paginazione** — la lista si carica a blocchi ("Carica altri"); "tira giù" per
  aggiornare.
- **Aggiornamento automatico (realtime)** — quando il pianificatore ti assegna o
  cambia qualcosa, la lista si aggiorna **da sola**.
- **Oggetti creati sul tablet** — compaiono in cima con l'etichetta **"DA
  SINCRONIZZARE"** finché non li invii al cruscotto (§4.13).

### 4.4 Dettaglio dell'Ordine

Aperto un OdL, trovi **schede** in alto:

- **Dettaglio** — banner con tipo intervento, e le sezioni:
  - **Dati Ordine** — numero, tipo, **tipo attività**, stato, **stato SAP**,
    priorità, date (creazione, esecuzione, **fine prevista**), avviso d'origine,
    contratto, settore contabile.
  - **Cliente** — codice, ragione sociale/nominativo, referente, telefono
    *(compaiono quando SAP li valorizza)*.
  - **Indirizzi** — cliente / oggetto / intervento, con **coordinate GPS** e
    apertura in **mappa** quando disponibili.
  - **Dati Tecnici** — sede tecnica, equipment, matricola, impianto.
  - **Contatore** — matricola, marca/modello, calibro, ultima lettura *(punto di
    misura SAP)*.
  - **Risorse** — tecnico assegnato, squadra, responsabile, reperibilità.
  - **Ampliamento / Pianificazione / Note**.
- **Operazioni** — elenco delle fasi/operazioni (numero, descrizione, centro di
  lavoro, ore); l'operatore può aggiungere righe.
- **Materiali** — componenti pianificati/usati (previsto/utilizzato, magazzino).
- **Allegati** — foto, documenti, firma *(acquisizione sul dispositivo — vedi §6)*.
- **Chiusura** — porta alla registrazione dell'esito.

### 4.5 Ciclo di vita dell'intervento

Dalla barra azioni del dettaglio il tecnico fa avanzare l'OdL:

| Azione | Da → A |
|--------|--------|
| **Avvia** | Ricevuto/Sospeso → In esecuzione |
| **Metti in pausa** | In esecuzione → In pausa *(locale)* |
| **Riprendi** | In pausa → In esecuzione |
| **Sospendi** (con motivo) | In esecuzione/pausa → Sospeso |
| **Concludi** | In esecuzione/pausa → chiusura/esito |

Ogni cambio di stato viene inviato al backend e il **cruscotto lo vede subito**.
Con la geolocalizzazione attiva, l'avvio/stop registra la posizione (timbratura di
campo).

### 4.6 Chiusura ed Esito

La schermata **Esito** raccoglie tutto ciò che chiude l'intervento:

- **Tempi** (inizio / fine), **Esito** (Riuscito / Rinviato / Impossibile),
- **Causa** e **Soluzione** (codici da anagrafica),
- **Letture contatore**, **materiali usati**, **ore lavorate**,
- **Commenti** e **firma del cliente**.

Alla conferma, l'esito viene registrato e l'OdL passa a **Completato**. *(L'inoltro
dell'esito verso SAP è previsto in una fase successiva — vedi §6.)*

### 4.7 Contatori (letture)

Per gli interventi sul contatore (attivazione, sostituzione, disattivazione): dati
del misuratore e registrazione delle **letture** (con matricola, valore, data).

### 4.8 Avvisi di Servizio

- Elenco dei **tuoi** avvisi, con filtri (Tutti / Miei / Urgenti / In attesa / Con
  preventivo / Da firmare / Chiusi) e ricerca. Card con numero, tipo, descrizione,
  **sede tecnica**, data.
- **Dettaglio** distinto per categoria:
  - **Pronto Intervento** — dati avviso, **codice guasto** (es. `STRC –
    STRUMENTALI CONTATORE`), stato, priorità, date guasto, dati tecnici, gestione
    intervento.
  - **Richiesta Preventivo** — dati preventivo (tipo richiesta, sopralluogo, ODL
    generato), con flusso **preventivo → firma → PDF**.
- Sezione **Elaborazione** (campi che l'operatore può compilare) e le sezioni
  cliente/indirizzi (si popolano quando SAP le valorizza).

### 4.9 Mappa

Visualizzazione su **mappa** degli ordini/indirizzi con coordinate GPS, per
orientarsi tra gli interventi della giornata.

### 4.10 Scanner

Lettura **QR/barcode** (es. matricola contatore/equipment) per trovare o
compilare rapidamente i dati.

### 4.11 Sincronizzazione e modalità offline

- L'app funziona **anche senza rete**: le azioni fatte offline entrano in una
  **coda di sincronizzazione** e partono da sole quando torna la connessione
  (retry automatico in background).
- La schermata **Sincronizza** mostra la coda e lo stato.
- Un indicatore segnala **offline** / operazioni **in attesa**.

### 4.12 Impostazioni

Preferenze locali dell'app (es. dimensione icone, opzioni di visualizzazione).

### 4.13 Creazione sul campo (local-first)

Il tecnico può creare oggetti direttamente dal tablet:

- **Nuovo OdL** — dalla Home / lista Ordini (**Nuovo OdL**): tipo, dati specifici
  del tipo, appuntamento, indirizzo, cliente, note.
- **Nuovo Avviso** — dalla lista Avvisi (**Nuovo Avviso**): tipo, descrizione,
  priorità, indirizzo, cliente, note.
- **OdL da Avviso** — dal dettaglio Avviso (**Genera OdL**): tipo ordine, attività
  PM, ciclo, descrizione.

**Come funziona (local-first):** ciò che crei nasce con un **id provvisorio
`TMP-…`** e **resta sul tablet** (memorizzato in locale, sopravvive al riavvio).
In lista compare in cima con l'etichetta arancione **"DA SINCRONIZZARE"**.

**Invio al cruscotto:** premendo **Sincronizza** gli oggetti creati vengono
inviati al cruscotto; quelli accettati escono dal locale (arriveranno poi dal
cruscotto con il numero reale), quelli non ancora inviabili **restano sul tablet**
per un nuovo tentativo. Finché il cruscotto non espone gli endpoint di creazione,
la sincronizzazione li mantiene in locale segnalandolo.

> I valori selezionabili nei form di creazione (tipo, priorità, attività, ciclo)
> arrivano dal cruscotto; dove non ancora disponibili, il campo resta un testo
> libero così la creazione è comunque possibile.

---

## 5. Backend Cruscotto — funzionalità e API

Backend (Node/TS, porta **4000**), tre gruppi di API sullo stesso processo.
Persistenza su file in `Backend-WFM-VIVA/data/` (`state.json` = ordini/avvisi SAP,
`assignments.json` = assegnazioni, `tecnici.json` = anagrafica CID,
`anagrafiche.json` = materiali/cause/soluzioni).

### 5.1 Ingestione da SAP

- **Push SOAP** — SAP invia i dati al backend (`POST /soap/pm`, WSDL `riceviPM`).
- **Pull** — il backend interroga SAP (`POST /api/refresh`, modalità `selezione`:
  restituisce gli oggetti selezionati nella transazione `ZWFMT_ESPONI_PM`).
  Richiede la **VPN**.

### 5.2 API dati SAP — `/api` (cruscotto)

| Endpoint | Descrizione |
|----------|-------------|
| `POST /api/refresh` | Ricarica gli oggetti da SAP (svuota e riscrive ordini/avvisi). |
| `GET /api/odl` `/:ordine` | Elenco / dettaglio ordini. Filtri: centro, stato, dataDa, dataA, page, pageSize. |
| `GET /api/avvisi` `/:avviso` | Elenco / dettaglio avvisi. |
| `GET /api/stream` | Canale **SSE**: snapshot iniziale + eventi in tempo reale. |
| `GET /api/health` | Stato e conteggi. |
| `GET /api/ingest-log` | Storico delle ricezioni da SAP. |

### 5.3 Assegnazioni — `/api/assegnazioni` (cruscotto)

È qui che nasce il legame **oggetto → tecnico**.

| Endpoint | Descrizione |
|----------|-------------|
| `GET /api/assegnazioni` | Elenco completo (con stato ed esito di ognuna). |
| `POST /api/assegnazioni` | Assegna un OdL/avviso a un tecnico. |
| `POST /api/assegnazioni/bulk` | Assegna più oggetti insieme. |
| `PATCH /api/assegnazioni/:tipo/:id/stato` | Cambia stato dal cruscotto. |
| `DELETE /api/assegnazioni/:tipo/:id` | Disassegna (sparisce dal tablet). |

### 5.4 Contratto tablet — `/api/v1` (app)

Base path **identica** al vecchio middleware: l'app non cambia contratto, solo host.

| Endpoint | Descrizione |
|----------|-------------|
| `POST /auth/login` `/logout` | Sessione (CID → token 8 h). |
| `POST /devices` | Registra il token FCM del tablet. |
| `GET /work-orders` `/:id` | **Solo gli ordini assegnati** al CID del token. Filtri: status, q, date. |
| `PATCH /work-orders/:id/status` | Avvia / sospendi / concludi. |
| `PATCH /work-orders/:id` | Aggiorna le note del tecnico. |
| `POST /esiti` | Chiusura intervento (esito, cause, letture, materiali, ore) → COMPLETATO. |
| `GET /notifications` `/:id` | **Solo gli avvisi assegnati**. |
| `GET /anagrafica/*` | Materiali, magazzini, marche contatori, codici TAM, cause, soluzioni, tecnici. |

**Cataloghi delle tendine — da esporre:** per alimentare le tendine ora prive di
valori hardcoded servono nuovi endpoint (`/anagrafica/wo-types`,
`/anagrafica/wo-fields?type=`, `/anagrafica/lookups/:kind`). 

**Creazione dal campo — non ancora attiva sul cruscotto:** `POST /work-orders`,
`POST /notifications`, `POST /notifications/:id/generate-work-order` rispondono
`501`. L'app crea quindi in **local-first** e riproverà l'invio quando gli
endpoint saranno disponibili.

**Sicurezza:** ogni endpoint (tranne login) richiede `Authorization: Bearer
<token>`; il CID si ricava dal token, non è un parametro manipolabile.

### 5.5 Realtime (SSE)

Il canale `GET /api/stream` invia un **snapshot** alla connessione e poi eventi
(`ordini`, `avvisi`, `assegnazioni`, `snapshot`, `reset`). L'app li ascolta e
ricarica le liste **senza intervento dell'utente**; il cruscotto vede le azioni del
tablet in tempo reale.

---

---

## 6. Glossario

| Termine | Significato |
|---------|-------------|
| **OdL** | Ordine di Lavoro: l'intervento da eseguire. |
| **Avviso** | Segnalazione/richiesta (pronto intervento o preventivo). |
| **CID** | Codice identificativo del tecnico (utente di login). |
| **Sede tecnica** | Ubicazione tecnica SAP dell'oggetto dell'intervento. |
| **Equipment** | Apparecchiatura SAP (es. contatore). |
| **Assegnazione** | Legame tra un OdL/avviso e un tecnico, creato dal cruscotto. |
| **Esito** | Registrazione di chiusura dell'intervento (esito, letture, materiali, ore, firma). |
| **SSE** | Server-Sent Events: canale realtime backend → app. |
| **Cruscotto** | Applicazione web del pianificatore. |
| **VPN** | Rete Vivaservizi necessaria al backend per raggiungere SAP. |
| **Id `TMP-…`** | Numero provvisorio di un OdL/avviso creato sul tablet, in attesa del numero reale SAP. |
| **DA SINCRONIZZARE** | Etichetta di un oggetto creato in locale e non ancora inviato al cruscotto. |
| **Local-first** | L'oggetto creato resta sul tablet finché l'operatore non lo sincronizza. |

-------
