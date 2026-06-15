# Guide complet — Créer un OdL côté backend

Ce middleware **Spring Boot** est le composant qui s'intercale entre ton app
Flutter et SAP : il reçoit les requêtes REST/JSON de l'app, persiste/expose les
ordres de travail (OdL), et (en production) traduit en appels SOAP vers SAP.

```
[App Flutter] ◄── REST/JSON ──► [Middleware Spring Boot] ◄── SOAP/XML ──► [SAP]
```

Pour l'instant l'étape SOAP→SAP est **stubée** (store en mémoire) : l'objectif
est que tu puisses **créer un OdL et le voir apparaître dans l'app Flutter en
quelques minutes**.

---

## 1. Prérequis

- **Java 21** (`java --version`)
- **Maven 3.9+** (`mvn -v`)
- Le dossier `middleware/` se trouve dans la racine du projet `wfm_app`.

---

## 2. Démarrer le serveur

Depuis `wfm_app/middleware/` :

```bash
mvn spring-boot:run
```

Tu dois voir :

```
Started WfmMiddlewareApplication ... on port(s): 8080
```

Le serveur écoute sur :

- **Base API** : `http://localhost:8080/api/v1`
- **Swagger UI** : `http://localhost:8080/api/v1/swagger-ui.html`

Le store est pré-rempli avec 3 OdL (dont le **DISA 50557262** correspondant au
document de spec) et 1 avviso, identiques à ceux de l'app mobile en mode mock.

---

## 3. Étapes pour créer un OdL côté backend

### Étape 3.1 — Comprendre la structure d'un OdL

Un OdL est défini par les champs du DTO `Dto.WorkOrder`
(`middleware/src/main/java/com/wfm/middleware/dto/Dto.java`). Les noms suivent
exactement le contrat SOAP de la spec §8.3 *et* les mappers Dart de l'app.

Champs minimaux pour créer un OdL :

| Champ                   | Obligatoire | Notes                                    |
|-------------------------|-------------|------------------------------------------|
| `externalCode`          | non         | Si vide, le middleware en génère un      |
| `woType`                | **oui**     | `ATTI`, `SOST`, `DISA`, `ZA02`, `PA`     |
| `woTypeDescription`     | **oui**     | Description visible côté technicien      |
| `status`                | non         | `RICEVUTO` par défaut                    |
| `appointmentDate`       | **oui**     | Format ISO `yyyy-MM-dd`                  |
| `appointmentStartTime`  | non         | `HH:mm`                                  |
| `address`               | **oui**     | Objet `{city, street, streetNumber, …}`  |
| `customer`              | selon type  | Obligatoire pour ATTI/SOST/DISA          |
| `meter`                 | selon type  | Obligatoire pour DISA, SOST, ATTI        |
| `technicianCID`         | **oui**     | CID du technicien destinataire           |
| `accountingSector`      | recommandé  | Ex. `POT - Servizio acqua potabile`      |

### Étape 3.2 — Appeler `POST /work-orders`

Exemple complet pour créer un **OdL DISA** (le cas du document) avec `curl` :

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

**Réponse 201 Created** :
```json
{
  "externalCode": "90000001",
  "woType": "DISA",
  "status": "RICEVUTO",
  ...
}
```

L'OdL est désormais visible :
- via `GET /work-orders` ;
- depuis l'**app Flutter** une fois branchée (voir §5).

### Étape 3.3 — Notifier le tablet (push)

Pour l'MVP, l'app récupère ses OdL en *pull* (au lancement et lors d'un
pull-to-refresh). En production, ajouter un push **Firebase Cloud Messaging
(FCM)** dans `WorkOrderController.create(...)` :

```java
// pseudo-code
fcm.send(token, Map.of("event","NEW_OR_UPDATED_OR_CANCELLED",
                       "externalCode", created.externalCode()));
```

L'app peut écouter ces messages pour invalider `workOrdersProvider` et
rafraîchir la liste sans intervention de l'utilisateur (spec EF-M13.1).

### Étape 3.4 — Le technicien envoie l'esito

Quand le technicien termine l'intervention (et la lecture finale dans le cas
DISA), l'app appelle :

```
POST /api/v1/esiti
```

avec le payload sérialisé par `esitoToJson` (lib/data/models/mappers.dart) :

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

Le middleware (en production) appelle `submitEsito` SOAP côté SAP, qui ferme
techniquement l'OdL (flux S13) et enregistre l'esito (E55).

---

## 4. Tous les endpoints exposés

| Méthode | Chemin                                          | Rôle                                      |
|---------|-------------------------------------------------|-------------------------------------------|
| POST    | `/auth/login`                                   | Connexion technicien                      |
| POST    | `/auth/logout`                                  | Déconnexion                               |
| GET     | `/work-orders?status=&q=&date=`                 | Liste OdL filtrée                         |
| GET     | `/work-orders/{id}`                             | Détail OdL                                |
| POST    | `/work-orders`                                  | **Créer un OdL** (utilisé ici)            |
| PATCH   | `/work-orders/{id}`                             | Mise à jour générique                     |
| PATCH   | `/work-orders/{id}/status`                      | Changer statut (Avvia/Sospendi/Concludi)  |
| GET     | `/work-orders/{id}/attachments`                 | Allegati                                  |
| GET     | `/notifications`                                | Liste Avvisi                              |
| GET     | `/notifications/{id}`                           | Détail Avviso                             |
| POST    | `/notifications`                                | Créer un Avviso                           |
| POST    | `/notifications/{id}/generate-work-order`       | Générer un OdL depuis un Avviso           |
| POST    | `/esiti`                                        | Soumettre l'esito                         |
| POST    | `/esiti/attachments`                            | Uploader une photo / firma                |
| GET     | `/anagrafica/materials?q=`                      | Catalogue matériaux                       |
| GET     | `/anagrafica/warehouses`                        | Magazzini                                 |
| GET     | `/anagrafica/meter-brands`                      | Marques de compteurs                      |
| GET     | `/anagrafica/tam-codes`                         | Codes TAM (dont `DISA`)                   |
| GET     | `/anagrafica/causes`                            | Codes motif (dropdown Esito)              |
| GET     | `/anagrafica/solutions`                         | Codes solution (dropdown Esito)           |

Swagger UI fournit la doc interactive de tous ces endpoints.

---

## 5. Brancher l'app Flutter sur ce middleware

Deux changements dans `lib/core/config/app_config.dart` :

```dart
// Pour développement local
const AppConfig kAppConfig = AppConfig(
  flavor: AppFlavor.dev,
  // Android Studio emulator -> host = 10.0.2.2
  // iOS simulator           -> host = localhost
  // Appareil physique       -> IP de ta machine sur le réseau Wi-Fi
  middlewareBaseUrl: 'http://10.0.2.2:8080/api/v1',
  useMockData: false,           // ← important : on quitte le mock
);
```

L'app passe automatiquement de `MockRemoteDataSource` à `HttpRemoteDataSource`
(branchement géré par `presentation/providers/core_providers.dart`).

Pour appareil iOS/Android sans HTTPS pendant les tests :
- **Android** : ajouter `android:usesCleartextTraffic="true"` dans
  `AndroidManifest.xml`.
- **iOS** : `NSAppTransportSecurity → NSAllowsArbitraryLoads = YES` dans
  `Info.plist`.

(à retirer en production : tout doit passer en HTTPS, spec §11.3).

---

## 6. Prochaines étapes pour la production

| Étape                                 | Quoi faire                                                                 |
|---------------------------------------|----------------------------------------------------------------------------|
| Remplacer `InMemoryStore`             | PostgreSQL via Spring Data JPA + entities `WorkOrderEntity` etc.            |
| Brancher SAP en SOAP                  | Apache CXF, générer les stubs depuis les WSDL fournis par l'équipe SAP      |
| Authentification réelle               | JWT (ou OAuth2), filtre Spring Security, WS-Security UsernameToken vers SAP |
| Push FCM                              | `firebase-admin-java`, envoyer un push à la création/modification d'OdL     |
| File de messages                      | RabbitMQ ou Kafka pour l'asynchrone avec SAP (spec §7.2.2)                  |
| Cache anagrafiche                     | Redis avec TTL 24 h (spec table §12 anagrafiche)                            |
| Observabilité                         | Micrometer + Prometheus + Grafana (latence, taux d'erreur, file SOAP)       |
| CI/CD                                 | Pipeline build → tests → push image Docker                                  |
| Sécurité                              | TLS 1.2+, certificate pinning côté mobile, HSTS, audit log structuré        |

---

## 7. Résumé visuel — Création OdL bout en bout

```
1. Admin/CRM front-end                                   [hors scope ici]
        │  POST /api/v1/work-orders  { woType: DISA, customer, meter, … }
        ▼
2. Middleware Spring Boot (ce projet)
   • valide les champs
   • assigne externalCode (90000001)
   • persiste en base / store
   • (prod) appelle SAP en SOAP : createWorkOrderFromField (I4)
   • (prod) envoie un push FCM au tablet du technicien
        │
        ▼
3. App Flutter (le tablet du technicien)
   • le push invalide workOrdersProvider, ou pull-to-refresh
   • le nouvel OdL apparaît dans la liste
   • le technicien ouvre le détail, voit matricola + lecture
   • effectue l'intervention (lecture finale, photo, sigillo)
   • POST /api/v1/esiti { result: SUCCESS, meterReadings: […] }
        │
        ▼
4. Middleware
   • (prod) submitEsito en SOAP vers SAP (S13 + E55)
   • l'OdL passe à COMPLETATO
        │
        ▼
5. SAP — clôture comptable et technique de l'OdL.
```

Tu peux dès aujourd'hui exécuter les étapes 2 et 3 en local (mock SOAP).
