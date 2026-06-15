package com.wfm.middleware.dto;

import java.util.List;

/**
 * Contratto JSON tra il middleware e l'app Flutter (spec aziendale completa).
 * I nomi dei campi corrispondono ESATTAMENTE a quelli attesi dai mapper Dart.
 * Tutte le date sono stringhe ISO 8601.
 *
 * Tutti i campi sono nullable per consentire payload parziali e
 * back-compatibility con i mock esistenti.
 */
public final class Dto {

    private Dto() {}

    // ─── Auth ───────────────────────────────────────────────────────────────

    public record LoginRequest(String cid, String password) {}

    public record LoginResponse(
            String cid, String nome, String cognome, String email,
            String workCenter, String squadra, String token) {}

    // ─── Value objects ───────────────────────────────────────────────────────

    public record Address(
            String street, String streetNumber,
            String cap, String localita, String city,
            String provincia, String regione, String nazione,
            String additionalInfo,
            Double latitude, Double longitude) {}

    public record Customer(
            String objectCode,
            String nome, String cognome, String ragioneSociale,
            String codiceFiscale, String partitaIva,
            String telefono, String email,
            String codBp, String codCli, Integer familyNucleus) {}

    public record Meter(
            String matricola, String brand, String model, String caliber,
            String materialCode, String location, String sector,
            Double lastReading, String lastReadingDate) {}

    public record Operation(
            String id, String number, String codice, String testoBreve,
            String cid, String description, String workCenter,
            String dataInizioPrevista, String dataFinePrevista,
            Double plannedHours, Double durataEffettiva, Double actualHours,
            String tempoLavoroFase, Boolean completed) {}

    public record MaterialUsage(
            String materialCode, String description,
            Double plannedQuantity, Double usedQuantity,
            String unitOfMeasure, String warehouseCode,
            String operationNumber, Boolean consumato) {}

    // ─── Work order (ODL completo spec) ────────────────────────────────────

    public record WorkOrder(
            // Identita
            String externalCode,
            String notificationNumberSAP,
            String avvisoOrigine,
            // Tipo / Stato
            String woType,                  // ATTI, DISA, ZA01, ZA02, PA
            String woTypeDescription,
            String tam,
            String subTam,
            String tipoAttivitaCodice,
            String tipoAttivitaNome,
            String status,                  // RICEVUTO, IN_ESECUZIONE, ...
            String priorita,                // Alta, Media, Bassa
            // Tracciamento
            String creatoDa,
            String createdAt,
            // Pianificazione
            String centroPianificazione,
            String centroLavoro,
            String appointmentDate,
            String appointmentStartTime,
            String appointmentEndTime,
            // Indirizzi
            Address address,                // indirizzo cliente
            Address indirizzoOggetto,
            Address indirizzoIntervento,
            // Cliente
            Customer customer,
            String codiceCliente,
            String referente,
            String telefonoCliente,
            // Tecnici
            String sedeTecnica,
            String equipment,
            String matricola,
            String ubicazione,              // ubicazione tecnica
            String aggUbicazione,
            String impianto,
            Meter meter,
            // Lavorazione
            List<Operation> operations,
            List<MaterialUsage> plannedMaterials,
            // Risorse
            String technicianCID,            // tecnico assegnato (CID)
            String squadra,
            String responsabile,
            String fornitoreEsterno,
            Boolean reperibilita,
            // Ampliamento / pianificazione
            String contratto,
            String impiantoDis,
            String ultimoCicloManutenzione,
            String postManut,
            String dataEsec,
            // Altri
            String accountingSector,
            String notes) {}

    public record WorkOrderList(List<WorkOrder> workOrders) {}

    // ─── Notification (Avviso completo spec) ────────────────────────────────

    public record Notification(
            // Identita
            String numeroAvviso,
            String descrizione,
            String descrizioneBreve,
            String descrizioneEstesa,
            String tipo,                    // ZF-PF, ZA01, ZF-ZF01, ZA02, PA
            String cid,                     // CID disservizio
            // Classificazione
            String categoriaIntervento,     // GUASTO / INSTALLAZIONE / MANUTENZIONE
            String canaleApertura,          // TELEFONO / EMAIL / WEB
            String tipoServizio,            // EMERGENZA / PROGRAMMATO
            String codiceGuasto,
            String codiceCausa,
            String noteOperatore,
            // Stato
            String priorita,                // Alta / Media / Bassa
            String stato,                   // Creato / Preso in carico / ...
            // Tecnici (SAP)
            String contratto,
            String codiceContratto,
            Boolean contrattoAttivo,
            String sedeTecnica,
            String ubicazioneTecnica,
            String equipment,
            String matricola,
            String statoEquipment,          // ATTIVO / GUASTO / SOSPESO
            String categoriaTecnica,
            String tipoImpianto,
            String impianto,
            String puntoMisura,
            String centroLavoro,
            // Risorse
            String assegnatoA,
            String squadra,
            String cidAssegnato,
            String autore,
            String creatoDa,
            String codiceCliente,
            String referente,
            String cellulare,
            String codiceFiscaleCliente,
            String areaTecnica,
            String noteAccesso,
            Boolean gestionePermessi,
            Boolean lavoriACaricoCliente,
            Boolean reperibilita,
            // SLA
            String slaTarget,
            String tempoRispostaAtteso,
            Boolean urgente,
            String motivoUrgenza,
            // Date
            String dataApertura,
            String oraApertura,
            String dataPianificata,
            String dataInterventoRichiesta,
            String dataInizioGuasto,
            String dataFineGuasto,
            String dataChiusura,
            String fasciaOraria,            // MATTINA / POMERIGGIO / SERA
            String dataPresaInCarico,
            String dataInvioTecnico,
            String dataArrivoPrevista,
            String statoOperativo,          // IN_ATTESA / IN_VIAGGIO / SUL_POSTO
            String dataSegnalazione,
            String oraSegnalazione,
            // Indirizzi
            Address address,                // indirizzo Avviso
            String indirizzoAvvisoTelefono,
            Address indirizzoOggetto,
            Address indirizzoLavoro,
            // Cliente
            Customer customer,
            // OdL collegato
            String ordineDiLavoro,
            String statoOdl,
            String technicianCID,
            Boolean interruzioneFornitura) {}

    public record NotificationList(List<Notification> notifications) {}

    // ─── Combined request (creazione atomica Avviso + ODL) ──────────────────

    /**
     * Crea contemporaneamente un Avviso di Servizio e l'Ordine di Lavoro
     * collegato. Se [odl] e null, viene generato automaticamente con le
     * operazioni standard di template.
     */
    public record AvvisoWithOdlRequest(
            Notification avviso,
            WorkOrder odl) {}

    /** Risposta combinata. */
    public record AvvisoWithOdlResponse(
            Notification avviso,
            WorkOrder odl) {}

    // ─── Esito ────────────────────────────────────────────────────────────────

    public record StatusUpdateRequest(String status, String reason, String note) {}

    public record EsitoResponse(String status, String esitoId, String sapDocumentNumber) {}

    // ─── Anagrafiche ────────────────────────────────────────────────────────

    public record MaterialItem(String materialCode, String description,
                               String unitOfMeasure, String barcode,
                               String defaultWarehouseCode, Double stockDisponibile) {}

    public record Warehouse(String code, String name) {}

    public record CodeLabel(String code, String label) {}
}
