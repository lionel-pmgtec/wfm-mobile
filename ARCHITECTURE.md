# Architettura — WFM App (diagrammi)

Applicazione **Work Force Management** per tablet (tecnici sul campo): Avvisi e
Ordini di Lavoro (OdL) SAP PM, offline-first, sincronizzazione via middleware.

> **Come importare i diagrammi in draw.io**: copiare il contenuto di un blocco
> ` ```mermaid ` e in draw.io usare **Arrange → Insert → Advanced → Mermaid…**
> (oppure `+` → Mermaid), incollare, **Insert**. draw.io genera il diagramma
> modificabile. Questi diagrammi servono come riferimento per avanzare nel codice.

---

## 1. Vista d'insieme del sistema

```mermaid
flowchart TB
    subgraph TABLET["APP FLUTTER (tablet tecnico)"]
        UI["presentation<br/>UI + Riverpod"]
        DOM["domain<br/>entità + contratti repository"]
        DATA["data<br/>repository impl + datasources"]
        HIVE[("Hive<br/>AvvisoExtension / OdlExtension")]
        CACHE[("Cache locale<br/>+ coda di sync")]
        UI --> DOM
        DATA --> DOM
        DATA --> HIVE
        DATA --> CACHE
    end

    subgraph MW["MIDDLEWARE SPRING BOOT — :8080/api/v1"]
        CTRL["Controller REST<br/>auth / work-orders / notifications<br/>esiti / anagrafica / workflow / devices"]
        STORE["ExcelStore<br/>(Apache POI)"]
        PUSH["PushService<br/>(Firebase Admin)"]
        XLSX[("data/wfm-database.xlsx")]
        ATT[("data/attachments/")]
        CTRL --> STORE
        CTRL --> PUSH
        STORE --> XLSX
        CTRL --> ATT
    end

    CRUSCOTTO["Cruscotto / Postman"]
    FCM["Firebase Cloud Messaging"]
    SAP["SAP PM<br/>(futuro — SOAP)"]

    DATA -- "REST/JSON (Dio)" --> CTRL
    CRUSCOTTO -- "REST/JSON" --> CTRL
    PUSH --> FCM
    FCM -- "notifica push" --> TABLET
    MW -. "futuro REST↔SOAP" .-> SAP
```

Principio chiave: **l'app non parla mai direttamente con SAP**. Il middleware
persiste oggi su Excel (demo pilotata da Postman/Cruscotto) e domani tradurrà
REST ↔ SOAP (parametri già in `application.yml`, sezione `sap.soap`).

---

## 2. Clean Architecture Flutter — layer e dipendenze

```mermaid
flowchart LR
    subgraph PRES["lib/presentation"]
        SCREENS["features/*<br/>screens + widgets"]
        PROV["providers/*<br/>Riverpod (stato)"]
        COREPROV["core_providers.dart<br/>(DI: punto unico)"]
        SCREENS --> PROV
        PROV --> COREPROV
    end

    subgraph DOMAIN["lib/domain"]
        ENT["entities/*<br/>WorkOrder, Esito, Avviso…"]
        REPOI["repositories/*<br/>interfacce (contratti)"]
    end

    subgraph DATAL["lib/data"]
        REPOIMPL["repositories/*_impl.dart"]
        REMOTE["HttpRemoteDataSource<br/>(Dio → middleware)"]
        LOCAL["WfmLocalDataSource<br/>(cache + coda sync)"]
        MAPPERS["models/mappers.dart<br/>JSON ↔ entità"]
        REPOIMPL --> REMOTE
        REPOIMPL --> LOCAL
        REMOTE --> MAPPERS
    end

    subgraph CORE["lib/core"]
        CFG["AppConfig<br/>(flavor dev/qa/prod)"]
        DIO["DioClient"]
        CONN["ConnectivityService"]
        ROUTER["go_router<br/>app_router / app_routes"]
        SVC["services/*<br/>SyncProcessor, FCM, PDF, Geo…"]
    end

    COREPROV --> REPOI
    REPOIMPL -- "implementa" --> REPOI
    REPOIMPL --> ENT
    PROV --> ENT
    REMOTE --> DIO
    DIO --> CFG
    REPOIMPL --> CONN
    SCREENS --> ROUTER
    PROV --> SVC
```

Regola: `domain` non dipende da niente; `data` e `presentation` dipendono da
`domain`; `core` è infrastruttura trasversale.

---

## 3. Dependency Injection (core_providers.dart)

```mermaid
flowchart TB
    appConfig["appConfigProvider<br/>(AppConfig dev/qa/prod)"]
    authToken["authTokenProvider<br/>(token sessione)"]
    dio["dioClientProvider<br/>(DioClient)"]
    connectivity["connectivityProvider<br/>(ConnectivityService)"]
    remote["remoteDataSourceProvider<br/>(HttpRemoteDataSource)"]
    localDS["localDataSourceProvider<br/>(InMemoryLocalDataSource)"]

    authRepo["authRepositoryProvider"]
    syncRepo["syncRepositoryProvider"]
    woRepo["workOrderRepositoryProvider"]
    esitoRepo["esitoRepositoryProvider"]
    attRepo["attachmentRepositoryProvider"]
    notifRepo["notificationRepositoryProvider"]
    anagRepo["anagraficaRepositoryProvider"]
    avvExtRepo["avvisoExtensionRepositoryProvider<br/>(Hive)"]
    odlExtRepo["odlExtensionRepositoryProvider<br/>(Hive)"]

    appConfig --> dio
    authToken --> dio
    dio --> remote
    remote --> authRepo
    authRepo -- "aggiorna token" --> authToken
    localDS --> syncRepo
    remote --> woRepo
    localDS --> woRepo
    connectivity --> woRepo
    syncRepo --> woRepo
    remote --> esitoRepo
    localDS --> esitoRepo
    connectivity --> esitoRepo
    syncRepo --> esitoRepo
    remote --> attRepo
    localDS --> attRepo
    connectivity --> attRepo
    remote --> notifRepo
    remote --> anagRepo
```

---

## 4. Flusso offline-first (sequenza)

```mermaid
sequenceDiagram
    autonumber
    participant UI as Screen (UI)
    participant Repo as WorkOrderRepositoryImpl
    participant Conn as ConnectivityService
    participant Remote as HttpRemoteDataSource
    participant Local as WfmLocalDataSource
    participant Queue as SyncRepository (coda)
    participant Proc as SyncProcessor
    participant MW as Middleware

    UI->>Repo: salva modifica OdL
    Repo->>Conn: online?
    alt Online
        Repo->>Remote: PATCH /work-orders/{id}
        Remote->>MW: HTTP
        MW-->>Remote: 200 OK
        Repo->>Local: aggiorna cache
    else Offline
        Repo->>Local: aggiorna cache (ottimistico)
        Repo->>Queue: enqueue SyncOperation
    end
    Note over Proc: trigger: avvio app, ritorno rete,<br/>ogni 15 min, retry manuale
    Proc->>Queue: getQueue()
    loop per ogni operazione pronta
        Proc->>Remote: rigioca operazione
        Remote->>MW: HTTP
        alt Successo
            Proc->>Queue: rimuovi operazione
        else Errore
            Proc->>Queue: stato=failed + backoff esponenziale
        end
    end
```

---

## 5. Flusso push (creazione Avviso/OdL → tablet)

```mermaid
sequenceDiagram
    autonumber
    participant PM as Cruscotto / Postman
    participant WC as WorkflowController
    participant ES as ExcelStore
    participant WN as WorkOrderNotifier
    participant DR as DeviceRegistry
    participant PS as PushService
    participant FCM as Firebase Cloud Messaging
    participant APP as App Flutter

    APP->>DR: POST /devices (token FCM al login)
    PM->>WC: POST /workflow/avviso-with-odl
    WC->>ES: persisti Avviso + OdL (xlsx)
    WC->>WN: notifica creazione
    WN->>DR: token dei tablet destinatari
    WN->>PS: invia push
    PS->>FCM: messaggio
    FCM-->>APP: notifica push
    APP->>APP: PushNotificationService → mostra notifica
    APP->>WC: GET /work-orders (refresh liste)
    Note over APP: fallback senza push:<br/>NewItemsPollService (polling)
```

---

## 6. Middleware — componenti

```mermaid
flowchart LR
    subgraph CONTROLLERS["controller/"]
        AUTH["AuthController<br/>/auth/login /auth/logout"]
        WO["WorkOrderController<br/>/work-orders CRUD + status + attachments"]
        NOTIF["NotificationController<br/>/notifications + generate-work-order"]
        ESITI["EsitoController<br/>/esiti + upload multipart"]
        ANAG["AnagraficaController<br/>/anagrafica/* (8 lookup)"]
        WF["WorkflowController<br/>/workflow/avviso-with-odl"]
        DEV["DeviceController<br/>/devices (token FCM)"]
    end

    subgraph SERVICES["service/"]
        NOTIFIER["WorkOrderNotifier"]
        PUSHSVC["PushService<br/>(Firebase Admin)"]
        REGISTRY["DeviceRegistry"]
    end

    STORE["store/ExcelStore<br/>cache RAM + riscrittura workbook"]
    DTO["dto/Dto<br/>record JSON condivisi"]
    CORS["config/CorsConfig"]
    XLSX[("wfm-database.xlsx<br/>schede: Avvisi, ODL, Esiti, Allegati,<br/>Materiali, Magazzini, Marche, TAM,<br/>Cause, Soluzioni, Equipment, Tecnici")]
    FILES[("data/attachments/")]
    FIREBASE["FCM"]

    AUTH --> STORE
    WO --> STORE
    NOTIF --> STORE
    ESITI --> STORE
    ANAG --> STORE
    WF --> STORE
    WO --> FILES
    ESITI --> FILES
    NOTIF --> NOTIFIER
    WF --> NOTIFIER
    NOTIFIER --> REGISTRY
    NOTIFIER --> PUSHSVC
    DEV --> REGISTRY
    PUSHSVC --> FIREBASE
    STORE --> XLSX
```

---

## 7. Navigazione (go_router)

```mermaid
flowchart TB
    LOGIN["/login"]
    SHELL["AppShell (navigation shell tablet)"]
    HOME["/home"]
    WOL["/work-orders"]
    WOD["/work-orders/:id"]
    AVL["/avvisi"]
    AVD["/avvisi/:id"]
    PREV["/preventivo/:key"]
    FIRMA["/preventivo/:key/firma"]
    PDF["/preventivo/:key/pdf"]
    STAND["/standalone"]
    OTHER["/map · /scanner · /signature<br/>/settings · /notifications<br/>/sync-queue · /create-order"]

    LOGIN --> SHELL
    SHELL --> HOME
    SHELL --> WOL
    SHELL --> AVL
    SHELL --> STAND
    SHELL --> OTHER
    WOL --> WOD
    WOD --> WOSUB["sub-screens OdL:<br/>/esito · /meter · /appointments<br/>/gen-ore · /copia · /cambio-cid<br/>/aggiungi-componente · /sospensioni<br/>/storico-appuntamenti · /esito-appuntamento"]
    AVL --> AVD
    AVD --> GENODL["/avvisi/:id/genera-ordine"]
    AVD --> PREV
    WOD --> PREV
    PREV --> FIRMA
    FIRMA --> PDF
    STAND --> STSUB["/equipment · /sostituzione-barcode<br/>/squadra · /templates"]
```

Nota: `/preventivo/:key` accetta come chiave sia il numero Avviso sia il codice
OdL — il flusso Preventivo → Firma → PDF è raggiungibile da entrambi.

---

## 8. Modello di dominio (entità principali)

```mermaid
classDiagram
    class WorkOrder {
        +id
        +stato lifecycle
        +operations
        +materials
    }
    class NotificationAvviso {
        +id
        +categoria
        +dati anagrafici
    }
    class Esito {
        +causa soluzione
        +ore lavorate
        +materiali usati
    }
    class Appointment
    class Meter
    class Equipment
    class Material
    class Suspension
    class Attachment
    class AvvisoExtension {
        +preventivo
        +permessi
        +lavoriCliente
        +documenti
        +note
    }
    class OdlExtension {
        +attivita
        +appuntamenti
        +firme
        +chiusura
        +note
    }
    class Preventivo
    class FirmaCliente
    class SyncOperation {
        +tipo
        +payload
        +status
        +backoff
    }
    class AuthSession {
        +token
        +scadenza 8h
    }

    NotificationAvviso "1" --> "0..1" WorkOrder : genera OdL
    WorkOrder "1" --> "0..*" Esito
    WorkOrder "1" --> "0..*" Appointment
    WorkOrder "1" --> "0..*" Suspension
    WorkOrder "1" --> "0..*" Attachment
    WorkOrder "1" --> "0..1" Meter
    WorkOrder "1" --> "0..1" Equipment
    Esito "1" --> "0..*" Material
    NotificationAvviso "1" --> "0..1" AvvisoExtension : Hive locale
    WorkOrder "1" --> "0..1" OdlExtension : Hive locale
    AvvisoExtension "1" --> "0..1" Preventivo
    Preventivo "1" --> "0..1" FirmaCliente
```

---

## 9. Decisioni architetturali

1. **Middleware obbligatorio** — l'app è SAP-agnostica; REST ↔ SOAP e
   credenziali SAP vivono solo lato server.
2. **Excel come DB temporaneo** — demo/collaudo via Postman senza
   infrastruttura DB; il contratto REST resta invariato passando a SAP/DB reale.
3. **Estensioni locali Hive** — i dati che SAP non conosce (preventivo, firma,
   note) restano sul tablet, separati dai dati master del backend.
4. **DI centralizzata** in `core_providers.dart` — cambiare un'implementazione
   non impatta la UI.
5. **workmanager rimosso** temporaneamente (embedding Android v1); sync in
   background gestita da `BackgroundSyncService`.
