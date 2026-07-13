# Test del workflow Avviso + ODL

## Endpoint
```
POST http://localhost:8080/api/v1/workflow/avviso-with-odl
Content-Type: application/json
```

## Esempio rapido — curl

```bash
curl -X POST http://localhost:8080/api/v1/workflow/avviso-with-odl \
  -H "Content-Type: application/json" \
  --data @create-avviso-with-odl.json
```

## Esempio Postman / Insomma / Httpie

Importa il file `create-avviso-with-odl.json` come body raw JSON.

## Risposta attesa

```json
{
  "avviso": {
    "numeroAvviso": "10000201",            // generato automaticamente
    "tipo": "ZF-PF",
    "stato": "Creato",
    "ordineDiLavoro": "90000001",          // link automatico all'ODL
    "statoOdl": "Ricevuto",
    ...
  },
  "odl": {
    "externalCode": "90000001",            // generato automaticamente
    "notificationNumberSAP": "10000201",   // link automatico all'Avviso
    "avvisoOrigine": "10000201",
    "woType": "ZA02",
    "status": "RICEVUTO",
    ...
  }
}
```

Status code : **201 Created**.

## Altri endpoint utili

### Creare solo l'Avviso (sense OdL)
```bash
POST /notifications
```
con il body dell'Avviso.

### Generare OdL dal template a partire da un Avviso esistente
```bash
POST /notifications/{numeroAvviso}/generate-work-order
```

### Creare solo l'OdL
```bash
curl -X POST http://localhost:8080/api/v1/work-orders \
  -H "Content-Type: application/json" \
  --data @create-odl.json
```
Usa il file `create-odl.json` (body completo di un OdL pronto da testare).
Note:
- Se `externalCode` è assente/vuoto, il middleware genera il codice (sequence interno).
- Se `operations` è assente/vuoto, viene applicato il **template standard** (3 operazioni).

Risposta attesa: **201 Created** con l'OdL creato (codice generato + operazioni del template).

### Recupare la lista
```bash
GET /notifications
GET /work-orders
```

### Recupare il dettaglio
```bash
GET /notifications/{numeroAvviso}
GET /work-orders/{externalCode}
```

## Persistenza (Excel)

Non esistono più dati di seed transazionali: **Avvisi e OdL partono vuoti**. Ogni
oggetto creato via questi endpoint viene scritto nel file Excel
`data/wfm-database.xlsx` (schede `Avvisi`, `ODL`, `Esiti`). Le sole anagrafiche
di riferimento (materiali, magazzini, cause, equipment, tecnici…) sono
pre-caricate al primo avvio. Per ripartire da zero, fermare il server ed
eliminare `data/wfm-database.xlsx`.

## Note importanti

- **Tutti i campi dei DTO sono nullable**. I campi minimi obbligatori sono :
  - Avviso : `tipo`, `descrizione`
  - OdL : `woType`, `woTypeDescription`
- Se `numeroAvviso` / `externalCode` mancano, il middleware li genera (sequence interno).
- Se l'OdL non fornisce certi campi (`address`, `customer`, `sedeTecnica`, ecc.) il middleware li **eredita dall'Avviso**.
- Se l'OdL non fornisce operazioni, viene applicato il **template standard** (3 operazioni : Sopralluogo / Esecuzione / Verifica e chiusura).
- Le date sono in formato **ISO 8601** (`YYYY-MM-DD` per le date, `YYYY-MM-DDTHH:mm:ss` per timestamp).

## Tipi avviso supportati
- `ZF-PF` — Pronto Intervento Fognatura
- `ZA01` — Servizio Idrico
- `ZF-ZF01` — Fognatura
- `ZA02` — Acqua
- `PA` — Richiesta di Preventivo

## Tipi OdL supportati
- `ATTI` — Attivazione fornitura
- `DISA` — Disattivazione fornitura
- `SOST` — Sostituzione contatore
- `ZA01` — Manutenzione servizio idrico
- `ZA02` — Manutenzione acqua
- `PA` — Generazione preventivo

## Indice dei file di esempio

### Avviso + OdL — `POST /api/v1/workflow/avviso-with-odl`
| File | Categoria | `tipo` avviso | `woType` OdL |
|------|-----------|---------------|--------------|
| `create-avviso-pronto-intervento.json` | Pronto Intervento | `ZA01` | `ZA01` |
| `create-avviso-with-odl.json` | Pronto Intervento | `ZF-PF` | `ZA02` |
| `create-avviso-preventivo.json` | Richiesta di Preventivo | `PA` | `PA` |

### Solo OdL — `POST /api/v1/work-orders`
| File | `woType` | Flusso app |
|------|----------|------------|
| `create-odl.json` | `ATTI` | Attivazione (sigillo + lettura iniziale) |
| `create-odl-disa.json` | `DISA` | Disattivazione (lettura finale + chiusura) |
| `create-odl-sostituzione.json` | `SOST` | Sostituzione contatore (lettura rimozione + nuovo misuratore) |

Esempio curl (uno qualsiasi dei file sopra):
```bash
# Avviso + OdL
curl -X POST http://localhost:8080/api/v1/workflow/avviso-with-odl \
  -H "Content-Type: application/json" --data @create-avviso-preventivo.json

# Solo OdL
curl -X POST http://localhost:8080/api/v1/work-orders \
  -H "Content-Type: application/json" --data @create-odl-disa.json
```

> In tutti gli esempi `technicianCID` / `cidAssegnato` = **VAIOTTIM**, così l'OdL
> compare al tecnico di test loggato (e, se le push FCM sono attive, arriva la
> notifica alla creazione).


