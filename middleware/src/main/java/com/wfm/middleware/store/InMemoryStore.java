package com.wfm.middleware.store;

import com.wfm.middleware.dto.Dto;
import jakarta.annotation.PostConstruct;
import org.springframework.stereotype.Component;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicLong;
import java.util.stream.Collectors;

/**
 * Store in memoria — simula i dati lato SAP per i test end-to-end con l'app.
 * In produzione: sostituito dal client SOAP verso SAP.
 *
 * Tutti i campi DTO sono nullable: i mock seed usano helper per minimizzare
 * il rumore e mantenere la leggibilita.
 */
@Component
public class InMemoryStore {

    private final Map<String, Dto.WorkOrder> orders = new ConcurrentHashMap<>();
    private final Map<String, Dto.Notification> notifications = new ConcurrentHashMap<>();
    private final AtomicLong sequence = new AtomicLong(90000000L);
    private final AtomicLong notifSequence = new AtomicLong(10000200L);

    @PostConstruct
    void seed() {
        // ── Avviso ZF-PF (Pronto Intervento Fognatura) ─────────────────────
        Dto.Notification a1 = new Dto.Notification(
                "10000123", "Segnalazione perdita acqua su strada",
                "Perdita acqua VIA SAN PIETRO",
                "Forte perdita d'acqua segnalata dai residenti.",
                "ZF-PF", "CID-2026-0123",
                "GUASTO", "TELEFONO", "EMERGENZA",
                "GU-PRD-01", "CA-ROT-02", "Chiamata urgente, condominio 12 unita.",
                "Alta", "In lavorazione",
                "CTR-2024-00087", "CTR-IDR-87", true,
                "ST-AN-CTR-145", "AN-DIST-01-Z3", "EQ-CTR-15516", "M-15516",
                "GUASTO", "Distribuzione idrica", "Rete primaria",
                "IMP-DN150-AN03", "PM-AN-145", "WC-AN-01",
                "Marco Rossi", "Squadra Nord Ancona", "VAIOTTIM", null,
                "op.callcenter", "CLI-14093829", "Simone Figuretti", "3401816346",
                "FGRSMN70A01A271X", "Area Ancona Sud",
                "Cancello sul retro, citofonare al 12.",
                true, false, true,
                "4h", "2h", true, "Allagamento strada pubblica",
                "2026-05-25", "14:20", "2026-05-27", "2026-05-27",
                "2026-05-25", null, null,
                "MATTINA",
                "2026-05-25T14:35:00", "2026-05-27T09:45:00", "2026-05-27T10:30:00",
                "SUL_POSTO",
                "2026-05-25", "14:20",
                addr("VIA SAN PIETRO", "145", "60131", "Gallignano",
                        "ANCONA", "AN", "Marche", "IT", null, 43.6158, 13.5189),
                "3401816346",
                addr("VIA SAN PIETRO", "145", "60131", "Vano contatore esterno",
                        "ANCONA", "AN", "Marche", "IT", null, null, null),
                addr("VIA SAN PIETRO", "143", "60131", null,
                        "ANCONA", "AN", "Marche", "IT", null, 43.6158, 13.5189),
                cust("74747", "SIMONE", "FIGURETTI", null,
                        "FGRSMN70A01A271X", null,
                        "3401816346", "simone.figuretti@example.it",
                        "90053496", "14093829", 3),
                "50674709", "Ricevuto", "VAIOTTIM", false);
        notifications.put(a1.numeroAvviso(), a1);

        // ── ODL ATTI collegato ─────────────────────────────────────────────
        Dto.WorkOrder o1 = new Dto.WorkOrder(
                "50674709", "10000123", "10000123",
                "ATTI", "Attivazione fornitura - Apertura disco",
                "ATTI", "ADS - Apertura (disco)", "ADS", "Apertura disco",
                "RICEVUTO", "Alta",
                "cruscotto.sap", "2026-05-25T14:35:00",
                "CP-AN-01", "WC-AN-01",
                "2026-05-27", "10:30", "12:30",
                addr("VIA SAN PIETRO", "145", "60131", "Gallignano",
                        "ANCONA", "AN", "Marche", "IT",
                        "ESTERNO PASSO DESTRA", 43.6158, 13.5189),
                addr("VIA SAN PIETRO", "145", "60131", "Vano contatore esterno",
                        "ANCONA", "AN", "Marche", "IT", null, null, null),
                addr("VIA SAN PIETRO", "143", "60131", null,
                        "ANCONA", "AN", "Marche", "IT", null, 43.6158, 13.5189),
                cust("74747", "SIMONE", "FIGURETTI", null,
                        "FGRSMN70A01A271X", null,
                        "3401816346", "simone.figuretti@example.it",
                        "90053496", "14093829", 3),
                "CLI-14093829", "Simone Figuretti", "3401816346",
                "ST-AN-CTR-145", "EQ-CTR-15516", "15516",
                "AN-DIST-01-Z3", "ESTERNO PASSO DESTRA",
                "74747",
                new Dto.Meter("15516", "MADDALENA", "MIS. ACQUA 015 5 CIF",
                        "15", "976", "A0079 - ESTERNO PASSO DESTRA", "H1", 2.0, "2025-12-01"),
                templateOperations("VAIOTTIM", "2026-05-27", "WC-AN-01"),
                List.of(
                        new Dto.MaterialUsage("M010", "Guarnizione gomma DN15",
                                1.0, 0.0, "PZ", "W01", "0010", false),
                        new Dto.MaterialUsage("M020", "Sigillo antifrode",
                                1.0, 0.0, "PZ", "W01", "0020", false)
                ),
                "VAIOTTIM", "Squadra Nord Ancona",
                "Ing. Luca Bianchi", null, true,
                "CTR-2024-00087", "74747",
                "STD-001 / GRP-IDR / CONT.001", "MP-2025-12", "2025-12-01",
                "POT - Servizio acqua potabile",
                "Cliente disponibile, cancello sul retro.");
        orders.put(o1.externalCode(), o1);

        // ── ODL DISA ────────────────────────────────────────────────────────
        Dto.WorkOrder o2 = new Dto.WorkOrder(
                "50557262", null, null,
                "DISA", "Disattivazione fornitura - Chiusura sigillo",
                "DISA", "Disattivazione fornitura", "DIS", "Chiusura sigillo",
                "RICEVUTO", "Media",
                "cruscotto.sap", "2026-06-05T14:00:00",
                "CP-FA-01", "WC-FA-01",
                "2026-06-08", "08:00", "08:30",
                addr("VIA GIACOMO MATTEOTTI", "52", "60015", "INT. 14",
                        "FALCONARA MARITTIMA", "AN", "Marche", "IT",
                        null, null, null),
                null, null,
                cust("90200509", "CATERINA", "GAGLIANESE", null,
                        "GGLCRN65P58D429R", null,
                        "3346566751", null, "90200509", null, 2),
                "CLI-90200509", "Caterina Gaglianese", "3346566751",
                "ST-FA-MAT-052", "EQ-CTR-20114578", "20114578",
                "C0014 - NICCHIA INTERNA", "NICCHIA INTERNA",
                "88012",
                new Dto.Meter("20114578", "SENSUS", "MIS. ACQUA 015 5 CIF",
                        "15", "976", "C0014 - NICCHIA INTERNA", "H1", 348.0, "2026-04-30"),
                List.of(
                        new Dto.Operation("OP-DISA-1", "0010", "CHF-001",
                                "Chiusura fornitura", "VAIOTTIM",
                                "Chiusura fornitura idrica e apposizione sigillo.",
                                "WC-FA-01", "2026-06-08", null, 0.5, null, null,
                                null, false),
                        new Dto.Operation("OP-DISA-2", "0020", "LET-001",
                                "Lettura finale contatore", "VAIOTTIM",
                                "Lettura finale e foto del display.",
                                "WC-FA-01", "2026-06-08", null, 0.25, null, null,
                                null, false)
                ),
                List.of(),
                "VAIOTTIM", "Squadra Nord Falconara",
                "Ing. Paolo Verdi", null, false,
                "CTR-2024-00410", "88012",
                "STD-001 / GRP-IDR / CONT.001", "MP-2026-04", "2026-04-30",
                "POT - Servizio acqua potabile", "");
        orders.put(o2.externalCode(), o2);
    }

    // ─── Helpers ────────────────────────────────────────────────────────────

    private static Dto.Address addr(String street, String civico, String cap,
                                     String localita, String city, String prov,
                                     String regione, String nazione,
                                     String additionalInfo,
                                     Double lat, Double lng) {
        return new Dto.Address(street, civico, cap, localita, city,
                prov, regione, nazione == null ? "IT" : nazione,
                additionalInfo, lat, lng);
    }

    private static Dto.Customer cust(String objectCode, String nome, String cognome,
                                      String ragSoc, String cf, String pi,
                                      String tel, String email,
                                      String codBp, String codCli, Integer fam) {
        return new Dto.Customer(objectCode, nome, cognome, ragSoc, cf, pi,
                tel, email, codBp, codCli, fam);
    }

    private static List<Dto.Operation> templateOperations(String cid, String date, String workCenter) {
        return List.of(
                new Dto.Operation("OP-T-1", "0010", "SOPR-001",
                        "Sopralluogo iniziale", cid,
                        "Verifica del punto di intervento, valutazione tecnica e "
                                + "identificazione delle attivita necessarie.",
                        workCenter, date, date, 0.5, null, null,
                        null, false),
                new Dto.Operation("OP-T-2", "0020", "EXEC-001",
                        "Esecuzione intervento", cid,
                        "Esecuzione delle lavorazioni previste come da spec.",
                        workCenter, date, date, 2.0, null, null,
                        null, false),
                new Dto.Operation("OP-T-3", "0030", "VRF-001",
                        "Verifica e chiusura", cid,
                        "Verifica funzionalita, ripristino sito, chiusura OdL.",
                        workCenter, date, date, 0.5, null, null,
                        null, false));
    }

    // ─── Query OdL ──────────────────────────────────────────────────────────

    public List<Dto.WorkOrder> findOrders(String status, String q, String date) {
        return orders.values().stream()
                .filter(w -> status == null || status.equalsIgnoreCase(w.status()))
                .filter(w -> q == null || matches(w, q.toLowerCase()))
                .filter(w -> date == null || date.equals(w.appointmentDate()))
                .sorted(Comparator.comparing(
                        Dto.WorkOrder::appointmentDate,
                        Comparator.nullsLast(Comparator.naturalOrder())))
                .collect(Collectors.toList());
    }

    private boolean matches(Dto.WorkOrder w, String q) {
        if (w.externalCode() != null && w.externalCode().toLowerCase().contains(q)) return true;
        if (w.woTypeDescription() != null && w.woTypeDescription().toLowerCase().contains(q)) return true;
        if (w.address() != null && w.address().city() != null
                && w.address().city().toLowerCase().contains(q)) return true;
        if (w.customer() != null && w.customer().cognome() != null
                && w.customer().cognome().toLowerCase().contains(q)) return true;
        return false;
    }

    public Optional<Dto.WorkOrder> findOrder(String code) {
        return Optional.ofNullable(orders.get(code));
    }

    // ─── Mutations OdL ──────────────────────────────────────────────────────

    /** Crea o aggiorna un OdL. Se externalCode e vuoto, ne genera uno. */
    public Dto.WorkOrder upsert(Dto.WorkOrder incoming) {
        String code = (incoming.externalCode() == null || incoming.externalCode().isBlank())
                ? String.valueOf(sequence.incrementAndGet())
                : incoming.externalCode();
        Dto.WorkOrder existing = orders.get(code);
        // Operazioni: se mancano e non e una creazione da Avviso, applichiamo il template.
        List<Dto.Operation> ops = incoming.operations() != null && !incoming.operations().isEmpty()
                ? incoming.operations()
                : (existing != null ? existing.operations()
                        : templateOperations(
                                incoming.technicianCID() != null ? incoming.technicianCID() : "",
                                incoming.appointmentDate() != null
                                        ? incoming.appointmentDate()
                                        : LocalDate.now().toString(),
                                incoming.centroLavoro() != null ? incoming.centroLavoro() : ""));
        Dto.WorkOrder saved = new Dto.WorkOrder(
                code,
                or(incoming.notificationNumberSAP(),
                        existing == null ? null : existing.notificationNumberSAP()),
                or(incoming.avvisoOrigine(),
                        existing == null ? null : existing.avvisoOrigine()),
                incoming.woType(), incoming.woTypeDescription(),
                or(incoming.tam(), incoming.woType()), incoming.subTam(),
                incoming.tipoAttivitaCodice(), incoming.tipoAttivitaNome(),
                or(incoming.status(), "RICEVUTO"),
                or(incoming.priorita(), "Media"),
                or(incoming.creatoDa(), "middleware"),
                or(incoming.createdAt(), LocalDateTime.now().toString()),
                incoming.centroPianificazione(), incoming.centroLavoro(),
                incoming.appointmentDate(), incoming.appointmentStartTime(),
                incoming.appointmentEndTime(),
                incoming.address(), incoming.indirizzoOggetto(),
                incoming.indirizzoIntervento(),
                incoming.customer(),
                incoming.codiceCliente(), incoming.referente(), incoming.telefonoCliente(),
                incoming.sedeTecnica(), incoming.equipment(), incoming.matricola(),
                incoming.ubicazione(), incoming.aggUbicazione(), incoming.impianto(),
                incoming.meter(),
                ops,
                incoming.plannedMaterials() != null
                        ? incoming.plannedMaterials()
                        : (existing == null ? List.of() : existing.plannedMaterials()),
                incoming.technicianCID(), incoming.squadra(),
                incoming.responsabile(), incoming.fornitoreEsterno(),
                or(incoming.reperibilita(), false),
                incoming.contratto(), incoming.impiantoDis(),
                incoming.ultimoCicloManutenzione(), incoming.postManut(), incoming.dataEsec(),
                incoming.accountingSector(), incoming.notes());
        orders.put(code, saved);
        return saved;
    }

    public Dto.WorkOrder updateStatus(String code, String status, String reason, String note) {
        Dto.WorkOrder w = orders.get(code);
        if (w == null) return null;
        Dto.WorkOrder updated = new Dto.WorkOrder(
                w.externalCode(), w.notificationNumberSAP(), w.avvisoOrigine(),
                w.woType(), w.woTypeDescription(), w.tam(), w.subTam(),
                w.tipoAttivitaCodice(), w.tipoAttivitaNome(),
                status, w.priorita(),
                w.creatoDa(), w.createdAt(),
                w.centroPianificazione(), w.centroLavoro(),
                w.appointmentDate(), w.appointmentStartTime(), w.appointmentEndTime(),
                w.address(), w.indirizzoOggetto(), w.indirizzoIntervento(),
                w.customer(), w.codiceCliente(), w.referente(), w.telefonoCliente(),
                w.sedeTecnica(), w.equipment(), w.matricola(),
                w.ubicazione(), w.aggUbicazione(), w.impianto(),
                w.meter(),
                w.operations(), w.plannedMaterials(),
                w.technicianCID(), w.squadra(), w.responsabile(),
                w.fornitoreEsterno(), w.reperibilita(),
                w.contratto(), w.impiantoDis(),
                w.ultimoCicloManutenzione(), w.postManut(), w.dataEsec(),
                w.accountingSector(),
                note == null ? w.notes() : note);
        orders.put(code, updated);
        return updated;
    }

    // ─── Notifiche ──────────────────────────────────────────────────────────

    public List<Dto.Notification> findNotifications(String q) {
        return notifications.values().stream()
                .filter(n -> q == null
                        || (n.descrizione() != null
                                && n.descrizione().toLowerCase().contains(q.toLowerCase()))
                        || (n.numeroAvviso() != null && n.numeroAvviso().contains(q)))
                .toList();
    }

    public Optional<Dto.Notification> findNotification(String n) {
        return Optional.ofNullable(notifications.get(n));
    }

    public Dto.Notification saveNotification(Dto.Notification n) {
        String num = (n.numeroAvviso() == null || n.numeroAvviso().isBlank())
                ? String.valueOf(notifSequence.incrementAndGet())
                : n.numeroAvviso();
        Dto.Notification saved = new Dto.Notification(
                num,
                or(n.descrizione(), ""),
                n.descrizioneBreve(), n.descrizioneEstesa(),
                n.tipo(), n.cid(),
                n.categoriaIntervento(), n.canaleApertura(), n.tipoServizio(),
                n.codiceGuasto(), n.codiceCausa(), n.noteOperatore(),
                or(n.priorita(), "Media"),
                or(n.stato(), "Creato"),
                n.contratto(), n.codiceContratto(),
                or(n.contrattoAttivo(), false),
                n.sedeTecnica(), n.ubicazioneTecnica(),
                n.equipment(), n.matricola(),
                n.statoEquipment(), n.categoriaTecnica(), n.tipoImpianto(),
                n.impianto(), n.puntoMisura(), n.centroLavoro(),
                n.assegnatoA(), n.squadra(), n.cidAssegnato(),
                n.autore(), or(n.creatoDa(), "middleware"),
                n.codiceCliente(), n.referente(), n.cellulare(),
                n.codiceFiscaleCliente(), n.areaTecnica(), n.noteAccesso(),
                or(n.gestionePermessi(), false),
                or(n.lavoriACaricoCliente(), false),
                or(n.reperibilita(), false),
                n.slaTarget(), n.tempoRispostaAtteso(),
                or(n.urgente(), false), n.motivoUrgenza(),
                or(n.dataApertura(), LocalDate.now().toString()),
                n.oraApertura(), n.dataPianificata(),
                n.dataInterventoRichiesta(), n.dataInizioGuasto(),
                n.dataFineGuasto(), n.dataChiusura(),
                n.fasciaOraria(),
                n.dataPresaInCarico(), n.dataInvioTecnico(),
                n.dataArrivoPrevista(), n.statoOperativo(),
                or(n.dataSegnalazione(), LocalDate.now().toString()),
                n.oraSegnalazione(),
                n.address(), n.indirizzoAvvisoTelefono(),
                n.indirizzoOggetto(), n.indirizzoLavoro(),
                n.customer(), n.ordineDiLavoro(), n.statoOdl(),
                n.technicianCID(),
                or(n.interruzioneFornitura(), false));
        notifications.put(num, saved);
        return saved;
    }

    /**
     * Genera un OdL minimal a partire da un Avviso (usato da
     * POST /notifications/{id}/generate-work-order).
     * Per la creazione COMPLETA usare l'endpoint /workflow/avviso-with-odl.
     */
    public Dto.WorkOrder generateWorkOrderFrom(String notificationNumber) {
        Dto.Notification n = notifications.get(notificationNumber);
        if (n == null) return null;
        String tipo = "PA".equals(n.tipo()) ? "PA"
                : (n.tipo() != null && n.tipo().startsWith("ZF") ? "ZA01" : "ZA02");
        String cid = n.cidAssegnato() != null ? n.cidAssegnato() : "VAIOTTIM";
        String date = LocalDate.now().toString();
        Dto.WorkOrder wo = new Dto.WorkOrder(
                "", n.numeroAvviso(), n.numeroAvviso(),
                tipo, n.descrizione(), tipo, null, null, null,
                "RICEVUTO", or(n.priorita(), "Media"),
                "middleware", LocalDateTime.now().toString(),
                null, n.centroLavoro(),
                date, "09:00", null,
                n.address(), n.indirizzoOggetto(), n.indirizzoLavoro(),
                n.customer(), n.codiceCliente(),
                n.referente(), n.cellulare(),
                n.sedeTecnica(), n.equipment(), n.matricola(),
                n.ubicazioneTecnica(), null, n.impianto(),
                null,
                templateOperations(cid, date, or(n.centroLavoro(), "")),
                List.of(),
                cid, n.squadra(), null, null, n.reperibilita(),
                n.contratto(), null, null, null, null,
                "POT - Servizio acqua potabile", "");
        Dto.WorkOrder created = upsert(wo);
        // Aggiorna l'avviso con l'OdL collegato
        notifications.put(notificationNumber, new Dto.Notification(
                n.numeroAvviso(), n.descrizione(), n.descrizioneBreve(),
                n.descrizioneEstesa(), n.tipo(), n.cid(),
                n.categoriaIntervento(), n.canaleApertura(), n.tipoServizio(),
                n.codiceGuasto(), n.codiceCausa(), n.noteOperatore(),
                n.priorita(), n.stato(), n.contratto(), n.codiceContratto(),
                n.contrattoAttivo(), n.sedeTecnica(), n.ubicazioneTecnica(),
                n.equipment(), n.matricola(), n.statoEquipment(),
                n.categoriaTecnica(), n.tipoImpianto(), n.impianto(),
                n.puntoMisura(), n.centroLavoro(), n.assegnatoA(),
                n.squadra(), n.cidAssegnato(), n.autore(), n.creatoDa(),
                n.codiceCliente(), n.referente(), n.cellulare(),
                n.codiceFiscaleCliente(), n.areaTecnica(), n.noteAccesso(),
                n.gestionePermessi(), n.lavoriACaricoCliente(), n.reperibilita(),
                n.slaTarget(), n.tempoRispostaAtteso(),
                n.urgente(), n.motivoUrgenza(),
                n.dataApertura(), n.oraApertura(), n.dataPianificata(),
                n.dataInterventoRichiesta(), n.dataInizioGuasto(),
                n.dataFineGuasto(), n.dataChiusura(), n.fasciaOraria(),
                n.dataPresaInCarico(), n.dataInvioTecnico(),
                n.dataArrivoPrevista(), n.statoOperativo(),
                n.dataSegnalazione(), n.oraSegnalazione(),
                n.address(), n.indirizzoAvvisoTelefono(),
                n.indirizzoOggetto(), n.indirizzoLavoro(),
                n.customer(), created.externalCode(), "Ricevuto",
                n.technicianCID(), n.interruzioneFornitura()));
        return created;
    }

    /**
     * Crea atomicamente un Avviso + l'ODL collegato (entrambi completi).
     * Se l'OdL nel body e null, viene generato dal template.
     */
    public Dto.AvvisoWithOdlResponse createAvvisoWithOdl(Dto.AvvisoWithOdlRequest req) {
        // 1. Salva l'Avviso
        Dto.Notification savedAvviso = saveNotification(req.avviso());
        // 2. Prepara l'OdL collegato (se fornito) o generalo dal template
        Dto.WorkOrder odl;
        if (req.odl() != null) {
            // Forza il collegamento all'avviso appena creato
            Dto.WorkOrder in = req.odl();
            Dto.WorkOrder linked = new Dto.WorkOrder(
                    in.externalCode(),
                    savedAvviso.numeroAvviso(), savedAvviso.numeroAvviso(),
                    in.woType(), in.woTypeDescription(), in.tam(), in.subTam(),
                    in.tipoAttivitaCodice(), in.tipoAttivitaNome(),
                    in.status(), in.priorita(),
                    in.creatoDa(), in.createdAt(),
                    in.centroPianificazione(), in.centroLavoro(),
                    in.appointmentDate(), in.appointmentStartTime(), in.appointmentEndTime(),
                    or(in.address(), savedAvviso.address()),
                    or(in.indirizzoOggetto(), savedAvviso.indirizzoOggetto()),
                    or(in.indirizzoIntervento(), savedAvviso.indirizzoLavoro()),
                    or(in.customer(), savedAvviso.customer()),
                    or(in.codiceCliente(), savedAvviso.codiceCliente()),
                    or(in.referente(), savedAvviso.referente()),
                    or(in.telefonoCliente(), savedAvviso.cellulare()),
                    or(in.sedeTecnica(), savedAvviso.sedeTecnica()),
                    or(in.equipment(), savedAvviso.equipment()),
                    or(in.matricola(), savedAvviso.matricola()),
                    or(in.ubicazione(), savedAvviso.ubicazioneTecnica()),
                    in.aggUbicazione(),
                    or(in.impianto(), savedAvviso.impianto()),
                    in.meter(),
                    in.operations(), in.plannedMaterials(),
                    or(in.technicianCID(), savedAvviso.cidAssegnato()),
                    or(in.squadra(), savedAvviso.squadra()),
                    in.responsabile(), in.fornitoreEsterno(),
                    or(in.reperibilita(), savedAvviso.reperibilita()),
                    or(in.contratto(), savedAvviso.contratto()),
                    in.impiantoDis(),
                    in.ultimoCicloManutenzione(), in.postManut(), in.dataEsec(),
                    in.accountingSector(), in.notes());
            odl = upsert(linked);
        } else {
            odl = generateWorkOrderFrom(savedAvviso.numeroAvviso());
        }
        // 3. Aggiorna l'avviso con il riferimento all'OdL creato (se non gia fatto)
        if (odl != null && (savedAvviso.ordineDiLavoro() == null
                || savedAvviso.ordineDiLavoro().isBlank())) {
            Dto.Notification linkedAvviso = withOdl(savedAvviso, odl.externalCode());
            notifications.put(linkedAvviso.numeroAvviso(), linkedAvviso);
            return new Dto.AvvisoWithOdlResponse(linkedAvviso, odl);
        }
        return new Dto.AvvisoWithOdlResponse(savedAvviso, odl);
    }

    private Dto.Notification withOdl(Dto.Notification n, String odlCode) {
        return new Dto.Notification(
                n.numeroAvviso(), n.descrizione(), n.descrizioneBreve(),
                n.descrizioneEstesa(), n.tipo(), n.cid(),
                n.categoriaIntervento(), n.canaleApertura(), n.tipoServizio(),
                n.codiceGuasto(), n.codiceCausa(), n.noteOperatore(),
                n.priorita(), n.stato(), n.contratto(), n.codiceContratto(),
                n.contrattoAttivo(), n.sedeTecnica(), n.ubicazioneTecnica(),
                n.equipment(), n.matricola(), n.statoEquipment(),
                n.categoriaTecnica(), n.tipoImpianto(), n.impianto(),
                n.puntoMisura(), n.centroLavoro(), n.assegnatoA(),
                n.squadra(), n.cidAssegnato(), n.autore(), n.creatoDa(),
                n.codiceCliente(), n.referente(), n.cellulare(),
                n.codiceFiscaleCliente(), n.areaTecnica(), n.noteAccesso(),
                n.gestionePermessi(), n.lavoriACaricoCliente(), n.reperibilita(),
                n.slaTarget(), n.tempoRispostaAtteso(),
                n.urgente(), n.motivoUrgenza(),
                n.dataApertura(), n.oraApertura(), n.dataPianificata(),
                n.dataInterventoRichiesta(), n.dataInizioGuasto(),
                n.dataFineGuasto(), n.dataChiusura(), n.fasciaOraria(),
                n.dataPresaInCarico(), n.dataInvioTecnico(),
                n.dataArrivoPrevista(), n.statoOperativo(),
                n.dataSegnalazione(), n.oraSegnalazione(),
                n.address(), n.indirizzoAvvisoTelefono(),
                n.indirizzoOggetto(), n.indirizzoLavoro(),
                n.customer(), odlCode, "Ricevuto",
                n.technicianCID(), n.interruzioneFornitura());
    }

    // ─── Anagrafiche ────────────────────────────────────────────────────────

    public List<Dto.MaterialItem> materials(String q) {
        List<Dto.MaterialItem> all = List.of(
                new Dto.MaterialItem("M001", "Contatore acqua DN15", "PZ",
                        "8001234560011", "W01", 12.0),
                new Dto.MaterialItem("M002", "Contatore acqua DN20", "PZ",
                        "8001234560028", "W01", 7.0),
                new Dto.MaterialItem("M010", "Guarnizione gomma DN15", "PZ",
                        "8001234560103", "W01", 48.0),
                new Dto.MaterialItem("M020", "Sigillo antifrode", "PZ",
                        "8001234560202", "W01", 100.0),
                new Dto.MaterialItem("M030", "Tubo PE DN25", "M",
                        "8001234560301", "W01", 80.0));
        if (q == null || q.isBlank()) return all;
        String s = q.toLowerCase();
        return all.stream().filter(m ->
                m.materialCode().toLowerCase().contains(s)
                        || m.description().toLowerCase().contains(s)
                        || (m.barcode() != null && m.barcode().contains(s))).toList();
    }

    public List<Dto.Warehouse> warehouses() {
        return List.of(
                new Dto.Warehouse("W01", "Furgone Tecnico"),
                new Dto.Warehouse("W02", "Magazzino Centrale ANCONA"),
                new Dto.Warehouse("W03", "Magazzino JESI"));
    }

    public List<String> meterBrands() {
        return List.of("MADDALENA", "SENSUS", "ITRON", "ZENNER", "DIEHL");
    }

    public List<String> tamCodes() {
        return List.of("ATTI", "DISA", "ZA01", "ZA02", "PA");
    }

    public List<Dto.CodeLabel> causes() {
        return List.of(
                new Dto.CodeLabel("C001", "Intervento programmato"),
                new Dto.CodeLabel("C002", "Perdita su rete"),
                new Dto.CodeLabel("C003", "Contatore guasto"),
                new Dto.CodeLabel("C004", "Richiesta cliente"),
                new Dto.CodeLabel("C005", "Verifica periodica"));
    }

    public List<Dto.CodeLabel> solutions() {
        return List.of(
                new Dto.CodeLabel("S001", "Sostituzione contatore"),
                new Dto.CodeLabel("S002", "Riparazione perdita"),
                new Dto.CodeLabel("S003", "Apertura fornitura"),
                new Dto.CodeLabel("S004", "Chiusura fornitura (DISA)"),
                new Dto.CodeLabel("S005", "Lettura effettuata"));
    }

    private static <T> T or(T a, T b) { return a != null ? a : b; }
}
