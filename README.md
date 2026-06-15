# WFM Mobile

Application Flutter tablet pour la gestion d'Ordres de Travail / Avvisi adossée à SAP (Work Manager), avec un middleware Spring Boot exposant une API REST/JSON au-dessus des services SOAP SAP.

## Stack

- **Mobile** : Flutter 3 (Dart >= 3.0), Riverpod, go_router, Dio + Retrofit, Hive, mobile_scanner, flutter_map, Firebase Messaging, Workmanager, pdf/printing.
- **Middleware** : Spring Boot 3.2 (Java 21), springdoc OpenAPI.

## Structure

```
.
├── lib/                # App Flutter (core / data / domain / presentation)
├── assets/             # Images & icônes embarqués dans l'app
├── android/  ios/  web/  test/
├── middleware/         # API REST/JSON Spring Boot (pont vers SAP SOAP)
└── pubspec.yaml
```

## Lancer l'app

```bash
flutter pub get
flutter run
```

Génération des sources Riverpod / Retrofit :

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Lancer le middleware

```bash
cd middleware
./mvnw spring-boot:run        # ou : mvn spring-boot:run
```

Swagger UI : `http://localhost:8080/swagger-ui.html`
