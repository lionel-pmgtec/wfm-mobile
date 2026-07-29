# Guida operativa — Avvio, configurazione e test dell'app col backend cruscotto

Guida pratica per far girare l'app WFM (tablet Flutter) con il **backend unico**
del collega (`Backend-WFM-VIVA/`, Node, porta 4000). Comandi copia-incolla.

> **Modello in una riga:** SAP → backend (`/api/refresh`) → il **pianificatore
> assegna** (`/api/assegnazioni`) → il tecnico sul tablet vede **solo i suoi**
> ordini/avvisi. Senza assegnazione la lista è vuota: è corretto, non è un bug.

---

## 1. Prerequisiti

| Cosa | Dettaglio |
|------|-----------|
| **Backend attivo** | In `Backend-WFM-VIVA/`: `npm run dev` → deve loggare "in ascolto sulla porta 4000". |
| **VPN Vivaservizi** | Attiva **solo per `POST /api/refresh`** (il backend chiama SAP). Login e assegnazioni NON la richiedono. |
| **Wi-Fi condivisa** | Tablet e PC sulla **stessa** rete Wi-Fi. |
| **Firewall** | Porta **4000** in ingresso consentita sul PC (al 1° avvio Windows chiede: "Consenti" su rete privata). |
| **`data/tecnici.json`** | Deve esistere con i CID di login (vedi §3). |

---

## 2. Configurazione dell'app (dove punta il backend)

Un solo file: [`lib/core/config/app_config.dart`](lib/core/config/app_config.dart),
una sola riga → `backendBaseUrl`. È **un solo backend** (`:4000`); i path `/api/v1`
(dati) e `/api` (SSE) sono derivati automaticamente.

| Dove gira l'app | `backendBaseUrl` |
|-----------------|------------------|
| **Tablet fisico** (Wi-Fi) | `http://<IP-LAN-del-PC>:4000` — es. `http://192.168.1.93:4000` |
| Web / Desktop (stesso PC) | `http://localhost:4000` |
| Emulatore Android (AVD) | `http://10.0.2.2:4000` |

- ⚠️ Sul **tablet fisico NON usare `localhost`**: lì `localhost` è il tablet, non il PC → "Server non raggiungibile".
- **IP del PC**: su PC `ipconfig` → IPv4 della scheda Wi-Fi (NON quello della VPN `172.x`). È **DHCP**: può cambiare.
- Se cambi IP, aggiornalo **anche** in [`android/app/src/main/res/xml/network_security_config.xml`](android/app/src/main/res/xml/network_security_config.xml) (Android permette il cleartext HTTP solo agli IP elencati lì).

---

## 3. Anagrafica tecnici e login

Il login accetta **solo CID presenti** in `Backend-WFM-VIVA/data/tecnici.json`
(la password **non** è verificata). Formato:

```json
[
  { "cid": "MROSSI", "nome": "Mario", "cognome": "Rossi", "workCenter": "SP1", "squadra": "Squadra A", "email": "mario.rossi@vivaservizi.local" }
]
```

- Dopo aver creato/modificato il file → **riavvia il backend**. All'avvio deve dire
  "Anagrafica tecnici caricata: N tecnici".
- CID di test attuali: **`MROSSI`**, `LBIANCHI`. In produzione li fornisce il collega.

---

## 4. Far comparire i dati sul tablet (passi da "pianificatore")

Da eseguire **sul PC**, in **PowerShell**. (Normalmente lo fa il cruscotto web con
un click; qui a mano per testare il tablet.)

```powershell
# 1) Carica i dati SAP nel backend (VPN ATTIVA). Risponde "Estratti N ordini e M avvisi".
Invoke-RestMethod -Method Post -Uri "http://localhost:4000/api/refresh"

# 2) Elenco ordini disponibili: prendi un valore della colonna ORDINE.
(Invoke-RestMethod -Uri "http://localhost:4000/api/odl").items | Select-Object ORDINE, DESCRIZIONE

# 3) Assegna un ORDINE al tecnico (sostituisci id con uno del passo 2).
Invoke-RestMethod -Method Post -Uri "http://localhost:4000/api/assegnazioni" `
  -ContentType "application/json" `
  -Body '{"tipo":"odl","id":"000060000475","technicianCID":"MROSSI"}'

# (facoltativo) Assegna anche un AVVISO.
Invoke-RestMethod -Method Post -Uri "http://localhost:4000/api/assegnazioni" `
  -ContentType "application/json" `
  -Body '{"tipo":"avviso","id":"000600002159","technicianCID":"MROSSI"}'
```

Nel tablet (loggato come lo stesso CID) l'oggetto **compare da solo** (evento SSE
`assegnazioni`) oppure tocca **🔄 Aggiorna**.

Comandi utili:
```powershell
Invoke-RestMethod -Uri "http://localhost:4000/api/health"            # conteggi backend
Invoke-RestMethod -Uri "http://localhost:4000/api/assegnazioni"      # assegnazioni correnti
# Disassegna:
Invoke-RestMethod -Method Delete -Uri "http://localhost:4000/api/assegnazioni/odl/000060000475"
```

---

## 5. Checklist end-to-end

- [ ] Backend avviato (log "porta 4000") + `tecnici.json` caricato.
- [ ] `backendBaseUrl` corretto (IP del PC per tablet fisico) + IP in `network_security_config.xml`.
- [ ] Tablet stessa Wi-Fi, firewall porta 4000 aperto.
- [ ] Test rete: dal **browser del tablet** apri `http://<IP-PC>:4000/api/health` → vedi JSON.
- [ ] `POST /api/refresh` (VPN) → ordini/avvisi > 0.
- [ ] `POST /api/assegnazioni` con il tuo CID.
- [ ] App: login col CID → l'ordine/avviso assegnato compare; il dettaglio mostra i campi.
- [ ] Cambio stato dal tablet → il cruscotto lo vede (SSE); l'esito arriva a `GET /api/assegnazioni`.

---

## 6. Troubleshooting

| Sintomo | Causa probabile | Rimedio |
|---------|-----------------|---------|
| **"Server non raggiungibile"** al login | `backendBaseUrl` = `localhost` su tablet fisico, o IP PC cambiato, o firewall | Metti l'IP LAN del PC; verifica `http://<IP>:4000/api/health` dal browser del tablet; sblocca porta 4000 |
| Login: **"CID non riconosciuto"** | CID assente in `tecnici.json` | Aggiungilo e riavvia il backend |
| **Lista vuota** dopo login | Nessuna assegnazione per quel CID (o store SAP vuoto) | `POST /api/refresh` poi `POST /api/assegnazioni` (§4) |
| `refresh`: **"Nessun oggetto disponibile"** | Selezione SAP vuota | In SAP `ZWFMT_ESPONI_PM` seleziona righe e reinvia, poi refresh |
| `refresh` va in timeout | VPN non attiva | Attiva la VPN Vivaservizi |
| Foto/firma o "Crea ordine" danno errore | Endpoint dichiarati **501** (non previsti) | È voluto: gli oggetti nascono in SAP |

---

## 7. Limiti noti del backend (dichiarati dal collega)

- L'**esito** si ferma nel backend: manca la scrittura verso SAP (`submitEsito` SOAP).
- **Allegati/creazione dal campo** → `501` (non previsti in questa fase).
- **Push FCM** non attive (aggiornamento via SSE/polling).
- **Sessioni in memoria**: al riavvio del backend i tablet rifanno login.

Vedi anche [`CONCLUSION.md`](CONCLUSION.md) (analisi + procedura d'integrazione) e
`DOC_ALE/10-BACKEND-FUNZIONI.md` (funzioni backend del collega).
