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

## Ambito funzionale (V1)

L'app copre i moduli **M1–M14** del Capitolato:

| | Modulo | | Modulo |
|---|---|---|---|
| M1 | Autenticazione | M8 | Allegati (foto/documenti/firme) |
| M2 | Elenco OdL | M9 | Avvisi (+ preventivo/firma/PDF) |
| M3 | Dettaglio OdL (schede) | M10 | Creazione OdL sul campo |
| M4 | Ciclo di vita OdL | M11 | Modalità offline + coda sync |
| M5 | Esito | M12 | Geolocalizzazione |
| M6 | Contatori | M13 | Notifiche push |
| M7 | Componenti e materiali | M14 | Impostazioni locali |

I moduli **M15–M18** (RQTI, Determina 5 / bilancio idrico, Lavori cliente
standalone, Inventario veicoli) sono evoluzioni successive e **non** fanno parte
di questa V1.

## Architettura dell'app

Clean Architecture su tre strati (`domain` / `data` / `presentation`), con
inversione delle dipendenze centralizzata in
[`core_providers.dart`](lib/presentation/providers/core_providers.dart).

- **Navigazione** — guscio persistente
  ([`AppShell`](lib/presentation/features/shell/app_shell.dart)) con
  `StatefulShellRoute`: `NavigationRail` su tablet e `NavigationBar` su
  smartphone, quattro destinazioni primarie (Home, Ordini, Avvisi, Mappa). Le
  schermate di dettaglio e i sotto-flussi si aprono a schermo intero sul root
  navigator.
- **Offline-first** — cache locale Hive + coda di sincronizzazione persistente,
  con retry esponenziale in background (Workmanager, ogni 15 min).
- **Sorgente dati remota** — interfaccia unica
  [`WfmRemoteDataSource`](lib/data/datasources/remote/remote_data_source.dart)
  con due implementazioni intercambiabili: `MockRemoteDataSource` (dati locali)
  e `HttpRemoteDataSource` (middleware REST). Il login restituisce una
  `AuthSession` (utente + token di sessione + scadenza).

## Collegare il backend reale

L'app è pronta per il middleware: la commutazione mock ↔ HTTP è governata da un
solo flag.

1. In [`app_config.dart`](lib/core/config/app_config.dart) impostare
   `useMockData: false` per il flavor desiderato e configurare
   `middlewareBaseUrl` (es. `http://10.0.2.2:8080/api/v1` su emulatore Android).
2. Nessun'altra modifica: `remoteDataSourceProvider` istanzia automaticamente
   `HttpRemoteDataSource` (Dio con interceptor Bearer + retry). Gli endpoint
   REST e la loro corrispondenza con i servizi SOAP SAP sono documentati in
   [`http_remote_data_source.dart`](lib/data/datasources/remote/http_remote_data_source.dart).

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

