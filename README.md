# WFM Mobile

Applicazione Flutter per tablet dedicata alla gestione degli Ordini di Lavoro / Avvisi connessa a SAP (Work Manager), con un middleware Spring Boot che espone un'API REST/JSON sopra i servizi SOAP di SAP.

```
[App Flutter] ◄── REST/JSON ──► [Middleware Spring Boot] ◄── SOAP/XML ──► [SAP DG1]
                                          │                          ZWFMT_SERVIZIO_PM
                                          ▼                            (sola lettura)
                                data/wfm-database.xlsx
                        anagrafiche + giornale delle scritture
```

## Stack

- **Mobile** : Flutter 3 (Dart >= 3.0), Riverpod, go_router, Dio, Hive, mobile_scanner, flutter_map, Firebase Messaging, Workmanager, pdf/printing.
- **Middleware** : Spring Boot 3.2 (**Java 17**), springdoc OpenAPI, Apache POI, firebase-admin. Il client SOAP verso SAP usa `java.net.http.HttpClient` del JDK: **nessuna dipendenza SOAP** (niente JAX-WS/CXF).

## Struttura

```
.
├── lib/                # App Flutter (core / data / domain / presentation)
├── assets/             # Immagini e icone incluse nell'app
├── android/  ios/  web/  test/
├── middleware/         # API REST/JSON Spring Boot (ponte verso SAP SOAP)
├── INTEGRAZIONE.md     # Analisi del servizio SAP + richieste aperte al team SAP
├── PIANO_SAP.md        # Piano del collegamento SAP (archivio, con scostamenti)
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
- **Offline-first** — cache locale + coda di sincronizzazione persistente,
  con retry esponenziale in background (Workmanager, ogni 15 min).
- **Sorgente dati remota** — **nessun mock**: l'unica implementazione di
  [`WfmRemoteDataSource`](lib/data/datasources/remote/remote_data_source.dart)
  è [`HttpRemoteDataSource`](lib/data/datasources/remote/http_remote_data_source.dart)
  (Dio con interceptor Bearer + retry). Il login restituisce una `AuthSession`
  (utente + token di sessione + scadenza).
- **Deserializzazione manuale** — i mapper stanno in
  [`mappers.dart`](lib/data/models/mappers.dart). **Nessun codegen**: non esiste
  nessun `.g.dart` e non c'è nessun `build_runner` da lanciare.

## Sorgente dati: SAP o Excel

Il middleware legge ordini e avvisi da **SAP** oppure dall'**Excel**, secondo
`wfm.sap.enabled`. Il default è `false` → Excel, così l'ambiente di sviluppo
senza credenziali SAP funziona da subito.

| | `SAP_ENABLED=false` (default) | `SAP_ENABLED=true` |
|---|---|---|
| Ordini / Avvisi | letti dall'Excel | letti da **SAP DG1** (`ZWFMT_SERVIZIO_PM`) |
| Anagrafiche | Excel | Excel (SAP non le espone) |
| Scritture (stato, note, esiti, allegati) | Excel | Excel — **il servizio SAP è di sola lettura** |
| Capabilities | tutto attivo | solo ciò che SAP alimenta davvero |

### Il vincolo che spiega l'architettura

`ZWFMT_SERVIZIO_PM` è **di sola lettura** ed espone **13 campi per l'ordine e 11
per l'avviso**, contro i 46 e 68 dei DTO. Mancano fra gli altri **cliente,
indirizzi, appuntamento e tecnico assegnato**.

Da qui due scelte:

- **Nessun dato finto.** In modalità SAP l'Excel non riempie i buchi: i campi
  assenti restano vuoti e l'app li mostra **spenti, con il motivo**, invece di
  far credere che il dato non esista su quell'ordine.
- **L'Excel è il giornale locale delle scritture** (stato, note) in attesa del
  servizio di scrittura SAP. A ogni lettura SAP resta la verità su tutto il resto.

Analisi completa e richieste aperte verso il team SAP: **[INTEGRAZIONE.md](INTEGRAZIONE.md)**.

### Riattivare un campo quando SAP lo esporrà

`GET /api/v1/capabilities` dice all'app quali sezioni sono alimentate. Per
riaccenderne una basta una riga in `middleware/src/main/resources/application.yml`:

```yaml
wfm:
  capabilities:
    fields:
      odl.cliente: true
```

e un riavvio del middleware. **L'app non si ricompila.**

## Avviare l'app

```bash
flutter pub get
flutter run
```

L'URL del middleware si imposta in
[`app_config.dart`](lib/core/config/app_config.dart) → `middlewareBaseUrl`
(es. `http://10.0.2.2:8080/api/v1` su emulatore Android). Il flag `useMockData`
**non esiste più**: l'unica sorgente è il middleware.

## Avviare il middleware

```bash
cd middleware
mvn spring-boot:run
```

> Su questa macchina `mvn` non è nel PATH e **non c'è il wrapper `mvnw`**: usare
> il Maven incluso in IntelliJ —
> `& "C:\Program Files\JetBrains\IntelliJ IDEA <ver>\plugins\maven\lib\maven3\bin\mvn.cmd" spring-boot:run`

Modalità SAP (la password non va mai nel repo):

```powershell
$env:SAP_ENABLED="true"; $env:SAP_SOAP_USER="<utente>"; $env:SAP_SOAP_PASSWORD="<password>"
mvn spring-boot:run
```

- **Base API** : `http://localhost:8080/api/v1`
- **Swagger UI** : `http://localhost:8080/api/v1/swagger-ui.html`

Dettagli, endpoint e collezione Postman: [middleware/README.md](middleware/README.md).

## Test

```bash
flutter test                                  # app
mvn -f middleware/pom.xml test                # middleware (25 test SAP)
```

> **Noto**: i 2 test di `test/widget_test.dart` (Login) falliscono — cercano
> `'Accesso SAP'` e delle `Key()` rimosse dalla refonte UI in corso su
> `login_screen.dart`. Vanno riallineati alla nuova schermata.
