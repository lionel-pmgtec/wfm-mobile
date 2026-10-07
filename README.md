# WFM Mobile — Viva Servizi

Applicazione **Flutter per tablet** per la gestione sul campo di **Ordini di Lavoro
(OdL)** e **Avvisi** di manutenzione della rete idrica. Il tecnico vede e lavora
**solo gli oggetti assegnati a lui**; l'app funziona anche senza rete (offline-first)
e si sincronizza con il **backend del cruscotto**, che a sua volta dialoga con SAP.

```
┌──────────────┐   REST/JSON /api/v1 + SSE /api/stream   ┌──────────────────────┐   SOAP/XML   ┌─────────┐
│ App Flutter  │ ◄─────────────────────────────────────► │ Backend WFM (Node)   │ ◄──────────► │   SAP   │
│   (tablet)   │  login, ordini, avvisi, esiti, anagrafi │ store su file, SSE   │              │   DG1   │
└──────────────┘  che, assegnazioni, realtime            └──────────────────────┘              └─────────┘
```

Il **backend** e il **cruscotto** del pianificatore (web) sono repository separati e non
fanno parte di questo progetto. L'app si limita a consumarne il contratto (vedi
[Contratto con il backend](#contratto-con-il-backend)).

## Indice

1. [Funzionalità](#funzionalità)
2. [Architettura](#architettura)
3. [Requisiti e avvio](#requisiti-e-avvio)
4. [Configurazione](#configurazione)
5. [Contratto con il backend](#contratto-con-il-backend)
6. [Dati e strumenti di supporto](#dati-e-strumenti-di-supporto)
7. [Test](#test)
8. [Limiti noti](#limiti-noti)
9. [Struttura del repository](#struttura-del-repository)

---

## Funzionalità

### Home
Riepilogo degli OdL per stato (Assegnato, In esecuzione, In pausa, Sospeso, Chiuso), banner dei **Pronto Intervento** (OdL e avvisi urgenti) e accessi rapidi:
**Crea OdL**, **Crea avviso**, **Standalone**. Sincronizzazione e impostazioni sono
nella barra laterale (con il contatore degli elementi da inviare).

### Ordini di lavoro
- **Elenco** con ricerca e filtri per stato (*Tutti, Assegnato, In esecuzione, In pausa,
  Sospeso*). Un OdL sospeso **resta sul tablet** per poterlo riprendere.
- **Dettaglio** a schede: *Dettaglio · Operazioni · Materiali · Allegati · Chiusura*.
- **Ciclo di vita**: Avvia → Pausa/Riprendi → Sospendi → Concludi. La *pausa* è uno
  stato solo locale (per il backend l'OdL resta in esecuzione).
- **Operazioni**: ogni OdL ha le tre operazioni standard (0010 Trasferimento, 0040 Lavori
  Idraulici, 0200 Automezzi, uguali a quelle del backend) quando il backend non ne manda
  di proprie. Le ore si registrano per operazione; *Automezzi* è la somma delle altre.
- **Assegnazione a un collega**, dal dettaglio o già in fase di creazione.
- **Chiusura**: esito (*Riuscito / Rinviato / Impossibile*), motivo e soluzione
  **facoltativi**, materiali, oggetti del lavoro, esito appuntamento, commenti e firma del
  cliente. L'invio dell'esito chiude l'OdL.

### Appuntamenti
"Data e ora appuntamento" è **l'appuntamento preso con il cliente**, non la data di
esecuzione. Compare solo se il cliente ne ha uno (ricavato dal record SAP); altrimenti
l'elenco è vuoto e il pulsante **Nuovo** permette di fissarne uno. Un OdL senza
appuntamento è datato e ordinato per **data di inizio** (giorno dell'assegnazione), con
l'etichetta esplicita *Appuntamento / Inizio / Esecuzione / Creato*. L'inizio
dell'intervento in chiusura è l'ora in cui il tecnico preme *Avvia*.

### Avvisi
Elenco con filtri per tipo, dettaglio (*Info · Lavoro · Allegati*), flusso
Preventivo → Firma → PDF per le richieste di preventivo, sospensioni, permessi.
Se un OdL è stato generato dall'avviso, la scheda *Lavoro* mostra **«OdL …» / Apri OdL**
invece di *Genera OdL*.

### Creazione dal campo (local-first)
Si creano **OdL**, **Avvisi** e **OdL da un avviso**. Per gli OdL sono selezionabili
**SOST** e **ZA02**; gli altri tipi del catalogo restano visibili ma disattivati. Per gli
avvisi i tipi proposti sono **IS** e **ZI**. L'oggetto nasce con un numero provvisorio
`TMP-…`, resta sul tablet (sopravvive al riavvio), è marcato *Da sincronizzare* e viene
inviato dal **Centro di sincronizzazione**. Data e ora di appuntamento si inviano **solo se
scelte**: l'app non ne inventa.

### Mappa
- Fondo **ArcGIS (Esri)** pubblico: chiaro, stradale, topografico, satellite.
- OdL e avvisi come segnaposto colorati per stato (stessa legenda del cruscotto), raggruppati
  quando vicini; ricerca di indirizzi, posizione del tecnico, **Naviga**, elenco ordinato per distanza.
- **Rete idrica Viva Servizi** (zona Ancona 60128): condotte di adduzione e distribuzione,
  allacci, contatori e riduttori di pressione. Da un contatore o da un riduttore si crea un
  **OdL** (SOST / ZA02) o un **avviso** già con indirizzo e posizione.
- **Tenendo premuto** su un punto qualsiasi si ottiene l'indirizzo reale (geocodifica inversa
  Esri) e si crea un OdL o un avviso lì.
- I contatori mostrati sono quelli che il backend manda sugli OdL/avvisi del tecnico.

### Materiali e magazzini
*Aggiungi componenti* è un elenco a tendina con caselle. Per ogni materiale spuntato si
vedono i **magazzini in cui è disponibile**, con i pezzi rimanenti di ciascuno, e si sceglie
da quale prelevare. La giacenza è **separata per magazzino**: prelevare dal Magazzino 1 non
tocca il Magazzino 2, e le quantità mostrate scendono in tempo reale. Lo stesso materiale
nello stesso magazzino si somma nella stessa riga; un materiale preso sul tablet si può
eliminare e la quantità torna al suo magazzino.

### Eliminazione e chiusura
Ciò che il tecnico **elimina sul tablet vale solo per il tablet** (il backend non cancella né
ordini né avvisi). L'app ricorda gli oggetti eliminati e non li mostra più, in elenco, mappa e
contatori, anche dopo un aggiornamento o un riavvio. La **chiusura** di un OdL (invio
dell'esito) lo toglie dal tablet insieme all'**avviso associato**; se un altro OdL aperto usa
lo stesso avviso, l'avviso resta.

### Impostazioni
Tutte le impostazioni sono **persistenti**: tema, frequenza di sincronizzazione, qualità foto,
dimensione di testo e icone. **Voce di lettura**: scelta fra le voci italiane installate sul
tablet, tono e velocità, con prova dell'ascolto. Dettatura vocale e lettura a voce alta sono
disponibili nei campi di testo.

### Altro
Scanner barcode/QR nei campi matricola e materiale, modulo *Standalone* (equipaggiamenti,
squadra, template), notifiche locali, esportazione Excel.

---

## Architettura

Clean Architecture su tre strati — `domain` / `data` / `presentation` — con l'iniezione
delle dipendenze centralizzata in
[`core_providers.dart`](lib/presentation/providers/core_providers.dart).

| Aspetto | Scelta |
|---|---|
| Stato | Riverpod |
| Navigazione | go_router, guscio persistente ([`AppShell`](lib/presentation/features/shell/app_shell.dart)): barra laterale su tablet, `NavigationBar` su smartphone |
| Rete | Dio con interceptor (token Bearer, retry); sorgente dati [`HttpRemoteDataSource`](lib/data/datasources/remote/http_remote_data_source.dart) |
| Modelli | mapper manuali in [`mappers.dart`](lib/data/models/mappers.dart), nessun codegen |
| Offline-first | cache locale (Hive) + coda di sincronizzazione persistente + retry in background (Workmanager) |
| Realtime | SSE (`GET /api/stream`): le liste si aggiornano quando il pianificatore assegna o cambia stato |
| Mappa | flutter_map + tessere Esri, `flutter_map_marker_cluster` |
| Voce | `speech_to_text` (dettatura), `flutter_tts` (lettura) |

**Archivi locali** (box Hive di stringhe, con copia in memoria): oggetti creati sul campo,
impostazioni, OdL e avvisi eliminati, giacenze prelevate per magazzino, arrivi sul tablet,
bozze di esito. Un record illeggibile viene saltato senza compromettere gli altri.

---

## Requisiti e avvio

- Flutter SDK ≥ 3 (Dart `>=3.0.0 <4.0.0`)
- Un backend WFM raggiungibile dal dispositivo
- Android: abilitare il traffico in chiaro verso il backend di sviluppo (già nel manifest)

```bash
flutter pub get
flutter run
```

Emulatore Android (il PC è raggiungibile come `10.0.2.2`):

```bash
flutter run -d emulator-5554 --dart-define=WFM_BASE_URL=http://10.0.2.2:4000/api/v1
```

---

## Configurazione

### Indirizzo del backend
All'avvio l'app prova in parallelo i server elencati in
[`assets/backend_servers.json`](assets/backend_servers.json), interrogando `GET /api/health`,
e usa il **primo che risponde 200**. Se nessuno risponde usa `WFM_BASE_URL`
(`--dart-define`), con il valore predefinito di [`app_config.dart`](lib/core/config/app_config.dart).
Per aggiungere un server basta aggiungerlo all'elenco.

### Rete Viva Servizi su ArcGIS (facoltativo)
I livelli ArcGIS del servizio `VIVA_SERVIZI_Ambito_Intervento_WFL1` sono **protetti** e non
fanno parte dei dati pubblici. Se si dispone di una chiave:

```bash
flutter run --dart-define=ARCGIS_TOKEN=<chiave>
```

(opzionale `--dart-define=ARCGIS_RETE_URL=<FeatureServer>`). Senza chiave la mappa non mostra
né livelli né interruttori e non fa chiamate. Il token **non va mai nel codice**.
Richieste di esempio per provare i servizi in Postman: [`GUIDA_POSTMAN_ARCGIS.md`](GUIDA_POSTMAN_ARCGIS.md).

### Login
Il backend accetta solo i CID presenti nella sua anagrafica tecnici (`TEC001` … `TEC005`);
la password non è verificata in sviluppo.

---

## Contratto con il backend

Regole che l'app applica ai dati del backend, da conoscere per modificare o diagnosticare:

| Tema | Regola |
|---|---|
| **Appuntamento** | Il backend manda `appointmentDate` a cascata (giorno pianificato, poi appuntamento SAP); l'app legge l'appuntamento **reale** da `datiSap.APPUNTAMENTO`. Se manca, nessun appuntamento. |
| **Inizio cardine** | `testata.date.inizioCardine` = giorno dell'assegnazione per gli oggetti nati sul tablet o sul cruscotto. Serve a datare e ordinare un OdL senza appuntamento. |
| **Date SAP vuote** | `0000-00-00`, `00000000`, `000000`: scartate (anno < 1900 e ora vuota non sono date). |
| **Cliente** | Mostrato solo se SAP manda `CLIENTE.NOME/COGNOME`. Il nome sull'indirizzo (`INDIRIZZO.NOME/NOME2`) è il **nome dell'edificio** (*Nome edificio*), non un cliente. Il *referente* si mostra solo se diverso. |
| **Indirizzi** | `address` è l'indirizzo di intervento; *oggetto* e *intervento* si mostrano solo se diversi. |
| **Avviso ↔ OdL** | Per gli OdL nati sul tablet il legame sta sull'OdL (`avvisoOrigine`), non sull'avviso. |
| **Operazioni** | Quelle del backend se presenti; altrimenti le tre standard. |
| **Giacenze** | `stockPerMagazzino` se presente; altrimenti lo stock unico nel magazzino predefinito, completato da un file di supporto (vedi sotto). |
| **Eliminazione** | `DELETE` su ordini e avvisi risponde `501`: l'app non lo chiama. |
| **Coordinate GIS** | Il tablet manda latitudine/longitudine dell'indirizzo; X/Y (EPSG:7792) le calcola il backend. |

---

## Dati e strumenti di supporto

| File / strumento | Scopo |
|---|---|
| `assets/rete_viva/rete_viva_ancona.geojson` | Rete idrica disegnata sulla mappa. Rigenerabile con `python tools/rete_viva/genera_rete_viva.py` (vie ed edifici da OpenStreetMap, indirizzi da OSM/Esri; per un'altra zona cambiare `BBOX`). Dati © OpenStreetMap contributors (ODbL). |
| `assets/anagrafica/giacenze_magazzini.json` | Giacenze dei materiali per magazzino, **solo finché il backend non manda `stockPerMagazzino`**. Generato da `anagrafiche.json` con `python tools/anagrafica/genera_giacenze.py`: nel magazzino predefinito resta lo stock vero, negli altri il 70% e il 40%. |
| `assets/backend_servers.json` | Candidati per la scoperta del backend. |

---

## Test

```bash
flutter analyze
flutter test
```

La suite copre mapper, regole di dominio, provider e schermate (unit e widget). Alcuni test
verificano il comportamento con la **forma esatta dei payload reali** del backend.

Stato noto: i due test di `test/widget_test.dart` (schermata di *Login*) non sono allineati
alla schermata attuale e falliscono; non dipendono dalle funzionalità sopra descritte.

---

## Limiti noti

- **Invio diretto a SAP**: non esiste; ogni oggetto viaggia tramite il cruscotto.
- **Esito → SAP**: l'esito si ferma nel backend (Cruscotto).
- **Giacenze**: il backend non le scala all'arrivo dell'esito; il tablet tiene il conto dei
  prelievi **solo localmente**. Le quantità negli altri magazzini vengono dal file di supporto.
- **Rete Viva**: i livelli ArcGIS richiedono una chiave; la rete disegnata è una ricostruzione
  sulle strade reali (OpenStreetMap), non il tracciato effettivo delle tubazioni.
- **Firma e allegati**: acquisizione sul dispositivo; l'upload dipende dal backend.
- **Numero definitivo**: un oggetto inviato conserva l'id `TMP-…` finché SAP non assegna il
  numero reale; non è un errore.
- **Eliminazioni locali**: un oggetto eliminato non torna sul tablet finché non si cancellano
  i dati dell'app; non esiste una schermata per ripristinarlo.
- **Voce di lettura**: Android non indica se una voce è maschile o femminile; l'elenco
  dipende dalle voci installate sul tablet.
- **Push FCM** non attive: aggiornamento via SSE e polling.
- **Sessioni in memoria** sul backend: al suo riavvio il tablet rifà il login.

---

## Struttura del repository

```
.
├── lib/
│   ├── core/            # config, rete, router, servizi, tema, widget condivisi
│   ├── data/            # sorgenti dati, repository, mapper, archivi locali
│   ├── domain/          # entità e interfacce dei repository
│   └── presentation/    # provider Riverpod e schermate (features/…)
├── assets/              # immagini, icone, rete Viva, giacenze, server backend
├── tools/               # generatori dei dati di supporto (Python)
├── test/                # unit e widget test
├── android/ ios/ web/ windows/ linux/ macos/
├── GUIDA_POSTMAN_ARCGIS.md
└── pubspec.yaml
```
