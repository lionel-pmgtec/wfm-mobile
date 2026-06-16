# WFM Mobile

Applicazione Flutter per tablet dedicata alla gestione degli Ordini di Lavoro / Avvisi connessa a SAP (Work Manager), con un middleware Spring Boot che espone un'API REST/JSON sopra i servizi SOAP di SAP.

## Stack

- **Mobile** : Flutter 3 (Dart >= 3.0), Riverpod, go_router, Dio + Retrofit, Hive, mobile_scanner, flutter_map, Firebase Messaging, Workmanager, pdf/printing.
- **Middleware** : Spring Boot 3.2 (Java 21), springdoc OpenAPI.

## Struttura

```
.
├── lib/                # App Flutter (core / data / domain / presentation)
├── assets/             # Immagini e icone incluse nell'app
├── android/  ios/  web/  test/
├── middleware/         # API REST/JSON Spring Boot (ponte verso SAP SOAP)
└── pubspec.yaml
```

## Avviare l'app

```bash
flutter pub get
flutter run
```

Generazione dei sorgenti Riverpod / Retrofit :

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Avviare il middleware

```bash
cd middleware
./mvnw spring-boot:run        # oppure : mvn spring-boot:run
```

Swagger UI : `http://localhost:8080/swagger-ui.html`
