# Test del workflow Avviso + ODL

## Endpoint
```
POST http://localhost:8080/workflow/avviso-with-odl
Content-Type: application/json
```

## Esempio rapido — curl

```bash
curl -X POST http://localhost:8080/workflow/avviso-with-odl \
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
POST /work-orders
```
con il body dell'OdL.

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
- `ZA01` — Manutenzione servizio idrico
- `ZA02` — Manutenzione acqua
- `PA` — Generazione preventivo
