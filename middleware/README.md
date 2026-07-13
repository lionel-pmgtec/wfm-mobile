# Guida completa — Creare Avvisi e OdL lato backend (Cruscotto)

Ce middleware **Spring Boot** est le composant qui s'intercale entre ton app
Flutter et SAP : il reçoit les requêtes REST/JSON de l'app, persiste/expose les
avvisi et ordres de travail (OdL), et (en production) traduit en appels SOAP
vers SAP.

```
[App Flutter] ◄── REST/JSON ──► [Middleware Spring Boot] ◄── SOAP/XML ──► [SAP]
                                        │
                                        ▼
                              data/wfm-database.xlsx  (il "database")
```

Il middleware **fa da Cruscotto** : non esiste un frontend admin, quindi si
creano gli Avvisi e gli OdL **via Postman** (o `curl`). La fase SOAP→SAP è
**stubbata** ; **tutti i dati creati (Avvisi, ODL, Esiti) sono persistiti in un
file Excel** (`data/wfm-database.xlsx`) tramite Apache POI. Riavviando il
server i dati restano. L'obiettivo è **creare un Avviso/OdL da Postman e
vederlo apparire nell'app Flutter in pochi minuti**.

---

## 1. Prerequisiti

- **Java 17+** (`java --version`)
- **Maven 3.9+** (`mvn -v`) — oppure aprire la cartella in IntelliJ (Maven incluso)
- La cartella `middleware/` si trova nella radice del progetto `wfm_app`.

---

## 2. Avviare il server

Dalla cartella `wfm_app/middleware/` :

```bash
mvn spring-boot:run
```

Devi vedere :

```
Started WfmMiddlewareApplication ... on port(s): 8080
```

Il server è in ascolto su :

- **Base API** : `http://localhost:8080/api/v1`
- **Swagger UI** : `http://localhost:8080/api/v1/swagger-ui.html`

### Il "database" Excel

Al **primo avvio** il middleware crea `data/wfm-database.xlsx` con **solo le
anagrafiche di riferimento** (materiali, magazzini, marche, codici TAM,
cause/soluzioni, equipment, tecnici) : **nessun Avviso/OdL preesistente**. Sta
a te crearli via Postman. Ogni creazione/aggiornamento riscrive il file.

Schede del workbook :

| Scheda            | Contenuto                                             |
|-------------------|-------------------------------------------------------|
| `Avvisi`          | Avvisi creati (colonne leggibili + colonna `_json`)   |
| `ODL`             | Ordini di lavoro (colonne leggibili + `_json`)        |
| `Esiti`           | Esiti intervento inviati dall'app                     |
| `Materiali` …     | Anagrafiche di riferimento (lookup)                   |
| `Equipment`       | Equipment ricercabili per matricola/barcode           |
| `Tecnici`         | Tecnici/operatori (Cambio CID, riassegnazione)        |

Il percorso è configurabile in `application.yml` → `wfm.excel.path`. Per
ripartire da zero: fermare il server ed eliminare `data/wfm-database.xlsx`.

---

## 3. Passaggi per creare un OdL lato backend

### Passaggio 3.1 — Capire la struttura di un OdL

Un OdL è definito dai campi del DTO `Dto.WorkOrder`
(`middleware/src/main/java/com/wfm/middleware/dto/Dto.java`). I nomi seguono
esattamente il contratto SOAP della specifica §8.3 *e* i mapper Dart dell'app.

Campi minimi per creare un OdL :

| Campo                   | Obbligatorio | Note                                     |
|-------------------------|--------------|------------------------------------------|
| `externalCode`          | no           | Se vuoto, il middleware ne genera uno    |
| `woType`                | **sì**       | `ATTI`, `SOST`, `DISA`, `ZA02`, `PA`     |
| `woTypeDescription`     | **sì**       | Descrizione visibile lato tecnico        |
| `status`                | no           | `RICEVUTO` di default                    |
| `appointmentDate`       | **sì**       | Formato ISO `yyyy-MM-dd`                 |
| `appointmentStartTime`  | no           | `HH:mm`                                  |
| `address`               | **sì**       | Oggetto `{city, street, streetNumber, …}`|
| `customer`              | secondo tipo | Obbligatorio per ATTI/SOST/DISA          |
| `meter`                 | secondo tipo | Obbligatorio per DISA, SOST, ATTI        |
| `technicianCID`         | **sì**       | CID del tecnico destinatario             |
| `accountingSector`      | consigliato  | Es. `POT - Servizio acqua potabile`      |

### Passaggio 3.2 — Chiamare `POST /work-orders`

Esempio completo per creare un **OdL DISA** (il caso del documento) con `curl` :

```bash
curl -X POST http://localhost:8080/api/v1/work-orders \
  -H 'Content-Type: application/json' \
  -d '{
    "woType": "DISA",
    "woTypeDescription": "Misuratori - Chiusura (sigillo)",
    "tam": "DISA",
    "subTam": "Disattivazione fornitura",
    "status": "RICEVUTO",
    "appointmentDate": "2026-06-10",
    "appointmentStartTime": "09:00",
    "appointmentEndTime": "09:30",
    "address": {
      "city": "ANCONA",
      "street": "VIA TEST",
      "streetNumber": "10",
      "additionalInfo": "Esterno"
    },
    "customer": {
      "nome": "MARIO",
      "cognome": "ROSSI",
      "telefono": "3401234567",
      "codBp": "90099999"
    },
    "meter": {
      "matricola": "20999999",
      "brand": "SENSUS",
      "model": "MIS. ACQUA 015 5 CIF",
      "caliber": "15",
      "lastReading": 125.0,
      "lastReadingDate": "2026-05-15"
    },
    "operations": [
      {"number":"0010","description":"Chiusura fornitura e sigillo","plannedHours":0.5},
      {"number":"0020","description":"Lettura finale contatore","plannedHours":0.25}
    ],
    "accountingSector": "POT - Servizio acqua potabile",
    "technicianCID": "VAIOTTIM"
  }'
```

**Risposta 201 Created** :
```json
{
  "externalCode": "90000001",
  "woType": "DISA",
  "status": "RICEVUTO",
}
```

L'OdL è ora visibile :
- tramite `GET /work-orders` ;
- dall'**app Flutter** una volta collegata (vedere §5).

### Passaggio 3.3 — Notificare il tablet (push)

Per l'MVP, l'app recupera i propri OdL in *pull* (all'avvio e tramite
pull-to-refresh). In produzione, aggiungere un push **Firebase Cloud Messaging
(FCM)** in `WorkOrderController.create(...)` :



L'app può ascoltare questi messaggi per invalidare `workOrdersProvider` e
aggiornare la lista senza intervento dell'utente (spec EF-M13.1).

### Passaggio 3.4 — Il tecnico invia l'esito

Quando il tecnico termina l'intervento (e la lettura finale nel caso DISA),
l'app chiama :

```
POST /api/v1/esiti
```

con il payload serializzato da `esitoToJson` (lib/data/models/mappers.dart) :

```json
{
  "workOrderCode": "50557262",
  "technicianCID": "VAIOTTIM",
  "startDateTime": "2026-06-08T09:05:00+02:00",
  "endDateTime":   "2026-06-08T09:25:00+02:00",
  "result": "SUCCESS",
  "causeCode": "C004",
  "solutionCode": "S004",
  "notes": "Disattivazione confermata, sigillo apposto.",
  "meterReadings": [
    {"matricola":"20114578","readingValue":362,"readingDateTime":"2026-06-08T09:20:00+02:00"}
  ],
  "hoursWorked": [{"technicianCID":"VAIOTTIM","hours":0.33}]
}
```

Il middleware (in produzione) chiama `submitEsito` SOAP lato SAP, che chiude
tecnicamente l'OdL (flusso S13) e registra l'esito (E55).

---

## 4. Tutti gli endpoint esposti

| Metodo  | Percorso                                        | Ruolo                                     |
|---------|-------------------------------------------------|-------------------------------------------|
| POST    | `/auth/login`                                   | Login tecnico                             |
| POST    | `/auth/logout`                                  | Logout                                    |
| GET     | `/work-orders?status=&q=&date=`                 | Lista OdL filtrata                        |
| GET     | `/work-orders/{id}`                             | Dettaglio OdL                             |
| POST    | `/work-orders`                                  | **Creare un OdL** (usato qui)             |
| PATCH   | `/work-orders/{id}`                             | Aggiornamento generico                    |
| PATCH   | `/work-orders/{id}/status`                      | Cambio stato (Avvia/Sospendi/Concludi)    |
| GET     | `/work-orders/{id}/attachments`                 | Allegati                                  |
| GET     | `/notifications`                                | Lista Avvisi                              |
| GET     | `/notifications/{id}`                           | Dettaglio Avviso                          |
| POST    | `/notifications`                                | Creare un Avviso                          |
| POST    | `/notifications/{id}/generate-work-order`       | Generare un OdL da un Avviso              |
| POST    | `/esiti`                                        | Inviare l'esito                           |
| POST    | `/esiti/attachments`                            | Caricare una foto / firma                 |
| GET     | `/anagrafica/materials?q=`                      | Catalogo materiali                        |
| GET     | `/anagrafica/warehouses`                        | Magazzini                                 |
| GET     | `/anagrafica/meter-brands`                      | Marche di contatori                       |
| GET     | `/anagrafica/tam-codes`                         | Codici TAM (incluso `DISA`)               |
| GET     | `/anagrafica/causes`                            | Codici causa (dropdown Esito)             |
| GET     | `/anagrafica/solutions`                         | Codici soluzione (dropdown Esito)         |
| GET     | `/anagrafica/equipment?matricola=&barcode=`     | Ricerca equipment (Standalone)            |
| GET     | `/anagrafica/tecnici?q=`                         | Ricerca tecnici (Cambio CID)              |
| GET     | `/anagrafica/operatori`                          | Lista operatori (riassegnazione OdL)      |

Swagger UI fornisce la documentazione interattiva di tutti questi endpoint.

### Collezione Postman pronta all'uso

In `middleware/postman/` trovi :

- `WFM.postman_collection.json` — tutte le richieste (login, crea OdL, crea
  Avviso, workflow Avviso+ODL, aggiorna stato, invia esito, anagrafiche) con
  body d'esempio già compilati e test-script che salvano `lastWorkOrderCode` /
  `lastAvvisoNumber` nell'environment ;
- `WFM.postman_environment.json` — environment con `{{baseUrl}}` =
  `http://localhost:8080/api/v1`.

Importa entrambi in Postman, seleziona l'environment, poi esegui **Login →
Create work-order** (o **Workflow → Create Avviso + ODL**) e verifica il file
Excel.

---

## 5. Collegare l'app Flutter a questo middleware

L'app **non ha più dati mock** : parla sempre col middleware via
`HttpRemoteDataSource`. Basta impostare l'URL corretto in
`lib/core/config/app_config.dart` :

```dart
// Per sviluppo locale
static const AppConfig dev = AppConfig(
  flavor: AppFlavor.dev,
  // Emulatore Android Studio -> host = 10.0.2.2
  // Simulatore iOS / Web     -> host = localhost
  // Dispositivo fisico       -> IP della tua macchina sulla rete Wi-Fi
  middlewareBaseUrl: 'http://10.0.2.2:8080/api/v1',
);
```

Il flag `useMockData` **non esiste più** : l'unica sorgente dati è il middleware
(gestione in `presentation/providers/core_providers.dart`).

Per dispositivo iOS/Android senza HTTPS durante i test :
- **Android** : aggiungere `android:usesCleartextTraffic="true"` in
  `AndroidManifest.xml`.
- **iOS** : `NSAppTransportSecurity → NSAllowsArbitraryLoads = YES` in
  `Info.plist`.

(da rimuovere in produzione : tutto deve passare in HTTPS, spec §11.3).

---

## 6. Prossimi passi per la produzione

| Passo                                 | Cosa fare                                                                   |
|---------------------------------------|-----------------------------------------------------------------------------|
| Sostituire `ExcelStore`               | PostgreSQL tramite Spring Data JPA + entità `WorkOrderEntity` ecc.          |
| Collegare SAP in SOAP                 | Apache CXF, generare gli stub dai WSDL forniti dal team SAP                 |
| Autenticazione reale                  | JWT (o OAuth2), filtro Spring Security, WS-Security UsernameToken verso SAP |
| Push FCM                              | `firebase-admin-java`, inviare un push alla creazione/modifica di OdL       |
| Coda di messaggi                      | RabbitMQ o Kafka per l'asincrono con SAP (spec §7.2.2)                      |
| Cache anagrafiche                     | Redis con TTL 24 h (spec tabella §12 anagrafiche)                           |
| Osservabilità                         | Micrometer + Prometheus + Grafana (latenza, tasso d'errore, coda SOAP)      |
| Sicurezza                             | TLS 1.2+, certificate pinning lato mobile, HSTS, audit log strutturato      |

---

## 7. Riepilogo visivo — Creazione OdL end-to-end

```
1. Admin/CRM front-end                                   [fuori scope qui]
        │  POST /api/v1/work-orders  { woType: DISA, customer, meter, … }
        ▼
2. Middleware Spring Boot (questo progetto)
   • valida i campi
   • assegna externalCode (90000001)
   • persiste in base dati / store
   • (prod) chiama SAP in SOAP : createWorkOrderFromField (I4)
   • (prod) invia un push FCM al tablet del tecnico
        │
        ▼
3. App Flutter (il tablet del tecnico)
   • il push invalida workOrdersProvider, oppure pull-to-refresh
   • il nuovo OdL appare nella lista
   • il tecnico apre il dettaglio, vede matricola + lettura
   • esegue l'intervento (lettura finale, foto, sigillo)
   • POST /api/v1/esiti { result: SUCCESS, meterReadings: […] }
        │
        ▼
4. Middleware
   • (prod) submitEsito in SOAP verso SAP (S13 + E55)
   • l'OdL passa a COMPLETATO
        │
        ▼
5. SAP — chiusura contabile e tecnica dell'OdL.
```

