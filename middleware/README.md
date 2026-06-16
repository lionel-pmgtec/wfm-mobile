# Guida completa — Creare un OdL lato backend

Questo middleware **Spring Boot** è il componente che si interpone tra l'app
Flutter e SAP : riceve le richieste REST/JSON dall'app, persiste ed espone gli
ordini di lavoro (OdL), e (in produzione) traduce in chiamate SOAP verso SAP.

```
[App Flutter] ◄── REST/JSON ──► [Middleware Spring Boot] ◄── SOAP/XML ──► [SAP]
```

Per il momento la fase SOAP→SAP è **stubbata** (store in memoria) : l'obiettivo
è che tu possa **creare un OdL e vederlo apparire nell'app Flutter in pochi
minuti**.

---

## 1. Prerequisiti

- **Java 21** (`java --version`)
- **Maven 3.9+** (`mvn -v`)
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

Lo store è pre-popolato con 3 OdL (tra cui il **DISA 50557262** corrispondente
al documento di specifica) e 1 avviso, identici a quelli dell'app mobile in
modalità mock.

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
  ...
}
```

L'OdL è ora visibile :
- tramite `GET /work-orders` ;
- dall'**app Flutter** una volta collegata (vedere §5).

### Passaggio 3.3 — Notificare il tablet (push)

Per l'MVP, l'app recupera i propri OdL in *pull* (all'avvio e tramite
pull-to-refresh). In produzione, aggiungere un push **Firebase Cloud Messaging
(FCM)** in `WorkOrderController.create(...)` :

```java
// pseudo-codice
fcm.send(token, Map.of("event","NEW_OR_UPDATED_OR_CANCELLED",
                       "externalCode", created.externalCode()));
```

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

Swagger UI fornisce la documentazione interattiva di tutti questi endpoint.

---

## 5. Collegare l'app Flutter a questo middleware

Due modifiche in `lib/core/config/app_config.dart` :

```dart
// Per sviluppo locale
const AppConfig kAppConfig = AppConfig(
  flavor: AppFlavor.dev,
  // Emulatore Android Studio -> host = 10.0.2.2
  // Simulatore iOS           -> host = localhost
  // Dispositivo fisico       -> IP della tua macchina sulla rete Wi-Fi
  middlewareBaseUrl: 'http://10.0.2.2:8080/api/v1',
  useMockData: false,           // ← importante : si esce dal mock
);
```

L'app passa automaticamente da `MockRemoteDataSource` a `HttpRemoteDataSource`
(gestione affidata a `presentation/providers/core_providers.dart`).

Per dispositivo iOS/Android senza HTTPS durante i test :
- **Android** : aggiungere `android:usesCleartextTraffic="true"` in
  `AndroidManifest.xml`.
- **iOS** : `NSAppTransportSecurity → NSAllowsArbitraryLoads = YES` in
  `Info.plist`.

(da rimuovere in produzione : tutto deve passare in HTTPS, spec §11.3).

---

## 6. Prossimi passi per la produzione

| Passo                                 | Cosa fare                                                                   |
|---------------------------------------|----------------------------------------------------------------------------|
| Sostituire `InMemoryStore`            | PostgreSQL tramite Spring Data JPA + entità `WorkOrderEntity` ecc.          |
| Collegare SAP in SOAP                 | Apache CXF, generare gli stub dai WSDL forniti dal team SAP                 |
| Autenticazione reale                  | JWT (o OAuth2), filtro Spring Security, WS-Security UsernameToken verso SAP |
| Push FCM                              | `firebase-admin-java`, inviare un push alla creazione/modifica di OdL       |
| Coda di messaggi                      | RabbitMQ o Kafka per l'asincrono con SAP (spec §7.2.2)                      |
| Cache anagrafiche                     | Redis con TTL 24 h (spec tabella §12 anagrafiche)                           |
| Osservabilità                         | Micrometer + Prometheus + Grafana (latenza, tasso d'errore, coda SOAP)      |
| CI/CD                                 | Pipeline build → test → push immagine Docker                                |
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

Già da oggi puoi eseguire i passaggi 2 e 3 in locale (mock SOAP).
