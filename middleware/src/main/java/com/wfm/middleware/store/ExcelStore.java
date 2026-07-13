package com.wfm.middleware.store;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.wfm.middleware.dto.Dto;
import jakarta.annotation.PostConstruct;
import org.apache.poi.ss.usermodel.*;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.io.*;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicLong;
import java.util.stream.Collectors;

/**
 * "Database" del middleware su file Excel (.xlsx).
 *
 * Tutti i dati transazionali creati dal Cruscotto/Postman — Avvisi, ODL, Esiti —
 * sono persistiti in un unico workbook (una scheda per entita) tramite Apache
 * POI. Le anagrafiche di riferimento (materiali, magazzini, cause, soluzioni,
 * equipment, tecnici) vivono nello stesso file come schede di lookup.
 *
 * Strategia: cache in memoria (ConcurrentHashMap) caricata all'avvio dal file;
 * ad ogni mutazione l'intero workbook viene riscritto su disco (semplice e
 * robusto per i volumi previsti). In produzione: sostituibile da un vero DB.
 *
 * Le schede transazionali hanno colonne leggibili + una colonna finale {@code
 * _json} che contiene il record completo (round-trip lossless via Jackson).
 */
@Component
public class ExcelStore {

    private static final String SHEET_AVVISI = "Avvisi";
    private static final String SHEET_ODL = "ODL";
    private static final String SHEET_ESITI = "Esiti";
    private static final String SHEET_ALLEGATI = "Allegati";
    private static final String SHEET_MATERIALI = "Materiali";
    private static final String SHEET_MAGAZZINI = "Magazzini";
    private static final String SHEET_MARCHE = "MarcheContatori";
    private static final String SHEET_TAM = "CodiciTAM";
    private static final String SHEET_CAUSE = "Cause";
    private static final String SHEET_SOLUZIONI = "Soluzioni";
    private static final String SHEET_EQUIPMENT = "Equipment";
    private static final String SHEET_TECNICI = "Tecnici";
    private static final String JSON_COL = "_json";

    private final ObjectMapper objectMapper;
    private final String excelPath;
    private final String attachmentsDir;
    private final Object lock = new Object();

    private final Map<String, Dto.WorkOrder> orders = new ConcurrentHashMap<>();
    private final Map<String, Dto.Notification> notifications = new ConcurrentHashMap<>();
    private final List<Map<String, Object>> esiti =
            Collections.synchronizedList(new ArrayList<>());
    private final List<Map<String, Object>> attachments =
            Collections.synchronizedList(new ArrayList<>());
    private final AtomicLong sequence = new AtomicLong(90000000L);
    private final AtomicLong notifSequence = new AtomicLong(10000200L);

    // Anagrafiche di riferimento (schede di lookup).
    private List<Dto.MaterialItem> materialsCatalog = new ArrayList<>();
    private List<Dto.Warehouse> warehousesCatalog = new ArrayList<>();
    private List<String> meterBrandsCatalog = new ArrayList<>();
    private List<String> tamCodesCatalog = new ArrayList<>();
    private List<Dto.CodeLabel> causesCatalog = new ArrayList<>();
    private List<Dto.CodeLabel> solutionsCatalog = new ArrayList<>();
    private List<Dto.Equipment> equipmentCatalog = new ArrayList<>();
    private List<Dto.Technician> techniciansCatalog = new ArrayList<>();

    public ExcelStore(ObjectMapper objectMapper,
                      @Value("${wfm.excel.path:./data/wfm-database.xlsx}") String excelPath,
                      @Value("${wfm.attachments.dir:./data/attachments}") String attachmentsDir) {
        this.objectMapper = objectMapper;
        this.excelPath = excelPath;
        this.attachmentsDir = attachmentsDir;
    }

    // ─── Ciclo di vita -------------------------------------------------------------

    @PostConstruct
    void init() {
        File file = new File(excelPath);
        if (file.exists()) {
            load(file);
        } else {
            // Prima esecuzione: le anagrafiche partono dai valori di default,
            // i dati transazionali (Avvisi/ODL/Esiti) partono vuoti.
            seedReferenceDefaults();
            persist();
        }
    }

    private void load(File file) {
        synchronized (lock) {
            try (Workbook wb = new XSSFWorkbook(new FileInputStream(file))) {
                loadTransactional(wb);
                loadReference(wb);
                realignSequences();
            } catch (IOException e) {
                throw new IllegalStateException(
                        "Impossibile leggere il database Excel: " + excelPath, e);
            }
        }
    }

    private void loadTransactional(Workbook wb) {
        forEachJsonRow(wb, SHEET_AVVISI, json -> {
            Dto.Notification n = fromJson(json, Dto.Notification.class);
            if (n != null && n.numeroAvviso() != null) notifications.put(n.numeroAvviso(), n);
        });
        forEachJsonRow(wb, SHEET_ODL, json -> {
            Dto.WorkOrder w = fromJson(json, Dto.WorkOrder.class);
            if (w != null && w.externalCode() != null) orders.put(w.externalCode(), w);
        });
        forEachJsonRow(wb, SHEET_ESITI, json -> {
            Map<String, Object> m = fromJsonMap(json);
            if (m != null) esiti.add(m);
        });
        forEachJsonRow(wb, SHEET_ALLEGATI, json -> {
            Map<String, Object> m = fromJsonMap(json);
            if (m != null) attachments.add(m);
        });
    }

    @SuppressWarnings("unchecked")
    private void loadReference(Workbook wb) {
        materialsCatalog = readRows(wb, SHEET_MATERIALI, r -> new Dto.MaterialItem(
                str(r, 0), str(r, 1), str(r, 2), str(r, 3), str(r, 4), dbl(r, 5)));
        warehousesCatalog = readRows(wb, SHEET_MAGAZZINI,
                r -> new Dto.Warehouse(str(r, 0), str(r, 1)));
        meterBrandsCatalog = readRows(wb, SHEET_MARCHE, r -> str(r, 0));
        tamCodesCatalog = readRows(wb, SHEET_TAM, r -> str(r, 0));
        causesCatalog = readRows(wb, SHEET_CAUSE,
                r -> new Dto.CodeLabel(str(r, 0), str(r, 1)));
        solutionsCatalog = readRows(wb, SHEET_SOLUZIONI,
                r -> new Dto.CodeLabel(str(r, 0), str(r, 1)));
        equipmentCatalog = readRows(wb, SHEET_EQUIPMENT, r -> new Dto.Equipment(
                str(r, 0), str(r, 1), str(r, 2), str(r, 3), str(r, 4),
                str(r, 5), str(r, 6), str(r, 7), str(r, 8)));
        techniciansCatalog = readRows(wb, SHEET_TECNICI, r -> new Dto.Technician(
                str(r, 0), str(r, 1), str(r, 2), str(r, 3), str(r, 4),
                str(r, 5), str(r, 6)));
        // Se il file esisteva ma senza anagrafiche, ripopola i default.
        if (materialsCatalog.isEmpty() && warehousesCatalog.isEmpty()
                && causesCatalog.isEmpty()) {
            seedReferenceDefaults();
        }
    }

    /** Riallinea i contatori ID per non collidere con quelli gia presenti. */
    private void realignSequences() {
        orders.keySet().stream().filter(k -> k.matches("\\d+"))
                .mapToLong(Long::parseLong).max()
                .ifPresent(max -> sequence.set(Math.max(sequence.get(), max)));
        notifications.keySet().stream().filter(k -> k.matches("\\d+"))
                .mapToLong(Long::parseLong).max()
                .ifPresent(max -> notifSequence.set(Math.max(notifSequence.get(), max)));
    }

    // ─── Persistenza -------------------------------------------------------------

    private void persist() {
        synchronized (lock) {
            ByteArrayOutputStream baos = new ByteArrayOutputStream();
            try (Workbook wb = new XSSFWorkbook()) {
                // Schede transazionali (colonne leggibili + _json).
                writeAvvisi(wb);
                writeOdl(wb);
                writeEsiti(wb);
                writeAllegati(wb);
                // Schede di riferimento.
                writeSheet(wb, SHEET_MATERIALI,
                        List.of("materialCode", "description", "unitOfMeasure",
                                "barcode", "defaultWarehouseCode", "stockDisponibile"),
                        materialsCatalog, m -> List.of(nz(m.materialCode()),
                                nz(m.description()), nz(m.unitOfMeasure()), nz(m.barcode()),
                                nz(m.defaultWarehouseCode()), nz(m.stockDisponibile())));
                writeSheet(wb, SHEET_MAGAZZINI, List.of("code", "name"),
                        warehousesCatalog, w -> List.of(nz(w.code()), nz(w.name())));
                writeSheet(wb, SHEET_MARCHE, List.of("brand"),
                        meterBrandsCatalog, b -> List.of(nz(b)));
                writeSheet(wb, SHEET_TAM, List.of("code"),
                        tamCodesCatalog, c -> List.of(nz(c)));
                writeSheet(wb, SHEET_CAUSE, List.of("code", "label"),
                        causesCatalog, c -> List.of(nz(c.code()), nz(c.label())));
                writeSheet(wb, SHEET_SOLUZIONI, List.of("code", "label"),
                        solutionsCatalog, s -> List.of(nz(s.code()), nz(s.label())));
                writeSheet(wb, SHEET_EQUIPMENT,
                        List.of("matricola", "barcode", "produttore", "modello",
                                "localita", "comune", "sedeTecnica", "dataInstallazione", "stato"),
                        equipmentCatalog, e -> List.of(nz(e.matricola()), nz(e.barcode()),
                                nz(e.produttore()), nz(e.modello()), nz(e.localita()),
                                nz(e.comune()), nz(e.sedeTecnica()), nz(e.dataInstallazione()),
                                nz(e.stato())));
                writeSheet(wb, SHEET_TECNICI,
                        List.of("cid", "nome", "cognome", "email", "role", "workCenter", "squadra"),
                        techniciansCatalog, t -> List.of(nz(t.cid()), nz(t.nome()),
                                nz(t.cognome()), nz(t.email()), nz(t.role()),
                                nz(t.workCenter()), nz(t.squadra())));

                wb.write(baos);
            } catch (IOException e) {
                throw new IllegalStateException("Errore generazione del workbook Excel", e);
            }
            writeBytesWithRetry(baos.toByteArray());
        }
    }

    /**
     * Scrive i byte del workbook su disco con qualche retry: il file può essere
     * temporaneamente bloccato (es. aperto in Excel dall'utente). Se resta
     * bloccato NON fa fallire la richiesta: i dati sono già in memoria e verranno
     * riscritti alla prossima mutazione (persist riscrive sempre l'intero file).
     */
    private void writeBytesWithRetry(byte[] bytes) {
        File file = new File(excelPath);
        File parent = file.getParentFile();
        if (parent != null && !parent.exists()) parent.mkdirs();
        IOException last = null;
        for (int attempt = 1; attempt <= 5; attempt++) {
            try (FileOutputStream out = new FileOutputStream(file)) {
                out.write(bytes);
                return;
            } catch (IOException e) {
                last = e;
                try {
                    Thread.sleep(200L);
                } catch (InterruptedException ie) {
                    Thread.currentThread().interrupt();
                    return;
                }
            }
        }
        System.err.println("[ExcelStore] ATTENZIONE: impossibile scrivere " + excelPath
                + " (file aperto in Excel?). I dati restano in memoria e saranno "
                + "riscritti al prossimo salvataggio. Causa: "
                + (last == null ? "?" : last.getMessage()));
    }

    private void writeAvvisi(Workbook wb) {
        Sheet sheet = wb.createSheet(SHEET_AVVISI);
        header(sheet, List.of("numeroAvviso", "tipo", "descrizione", "stato",
                "priorita", "cidAssegnato", "citta", "dataApertura",
                "ordineDiLavoro", JSON_COL));
        int r = 1;
        for (Dto.Notification n : notifications.values()) {
            Row row = sheet.createRow(r++);
            set(row, 0, nz(n.numeroAvviso()));
            set(row, 1, nz(n.tipo()));
            set(row, 2, nz(n.descrizione()));
            set(row, 3, nz(n.stato()));
            set(row, 4, nz(n.priorita()));
            set(row, 5, nz(n.cidAssegnato()));
            set(row, 6, n.address() != null ? nz(n.address().city()) : "");
            set(row, 7, nz(n.dataApertura()));
            set(row, 8, nz(n.ordineDiLavoro()));
            set(row, 9, toJson(n));
        }
    }

    private void writeOdl(Workbook wb) {
        Sheet sheet = wb.createSheet(SHEET_ODL);
        header(sheet, List.of("externalCode", "woType", "woTypeDescription", "status",
                "priorita", "technicianCID", "citta", "appointmentDate",
                "notificationNumberSAP", JSON_COL));
        int r = 1;
        for (Dto.WorkOrder w : orders.values()) {
            Row row = sheet.createRow(r++);
            set(row, 0, nz(w.externalCode()));
            set(row, 1, nz(w.woType()));
            set(row, 2, nz(w.woTypeDescription()));
            set(row, 3, nz(w.status()));
            set(row, 4, nz(w.priorita()));
            set(row, 5, nz(w.technicianCID()));
            set(row, 6, w.address() != null ? nz(w.address().city()) : "");
            set(row, 7, nz(w.appointmentDate()));
            set(row, 8, nz(w.notificationNumberSAP()));
            set(row, 9, toJson(w));
        }
    }

    private void writeEsiti(Workbook wb) {
        Sheet sheet = wb.createSheet(SHEET_ESITI);
        header(sheet, List.of("esitoId", "workOrderCode", "technicianCID", "result",
                "startDateTime", "endDateTime", "createdAt", JSON_COL));
        int r = 1;
        synchronized (esiti) {
            for (Map<String, Object> e : esiti) {
                Row row = sheet.createRow(r++);
                set(row, 0, mapStr(e, "esitoId"));
                set(row, 1, mapStr(e, "workOrderCode"));
                set(row, 2, mapStr(e, "technicianCID"));
                set(row, 3, mapStr(e, "result"));
                set(row, 4, mapStr(e, "startDateTime"));
                set(row, 5, mapStr(e, "endDateTime"));
                set(row, 6, mapStr(e, "createdAt"));
                set(row, 7, toJson(e));
            }
        }
    }

    private void writeAllegati(Workbook wb) {
        Sheet sheet = wb.createSheet(SHEET_ALLEGATI);
        header(sheet, List.of("id", "workOrderCode", "type", "fileName",
                "mimeType", "size", "path", "capturedAt", JSON_COL));
        int r = 1;
        synchronized (attachments) {
            for (Map<String, Object> a : attachments) {
                Row row = sheet.createRow(r++);
                set(row, 0, mapStr(a, "id"));
                set(row, 1, mapStr(a, "workOrderCode"));
                set(row, 2, mapStr(a, "type"));
                set(row, 3, mapStr(a, "fileName"));
                set(row, 4, mapStr(a, "mimeType"));
                set(row, 5, mapStr(a, "size"));
                set(row, 6, mapStr(a, "path"));
                set(row, 7, mapStr(a, "capturedAt"));
                set(row, 8, toJson(a));
            }
        }
    }

    // ─── Query ODL -------------------------------------------------------------

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

    // ─── Mutazioni ODL -------------------------------------------------------------

    /** Crea o aggiorne un ODL. Se externalCode è vuoto, ne genera uno. */
    public Dto.WorkOrder upsert(Dto.WorkOrder incoming) {
        String code = (incoming.externalCode() == null || incoming.externalCode().isBlank())
                ? String.valueOf(sequence.incrementAndGet())
                : incoming.externalCode();
        Dto.WorkOrder existing = orders.get(code);
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
        persist();
        return saved;
    }

    /** Elimina un OdL. Restituisce true se esisteva. */
    public boolean deleteOrder(String code) {
        boolean removed = orders.remove(code) != null;
        if (removed) persist();
        return removed;
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
        persist();
        return updated;
    }

    // ─── Notifiche -------------------------------------------------------------

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
        Dto.Notification saved = normalizeNotification(n);
        notifications.put(saved.numeroAvviso(), saved);
        persist();
        return saved;
    }

    /** Elimina un Avviso. Restituisce true se esisteva. */
    public boolean deleteNotification(String numero) {
        boolean removed = notifications.remove(numero) != null;
        if (removed) persist();
        return removed;
    }

    /**
     * Genera un OdL minimal a partire da un Avviso (usato da
     * POST /notifications/{id}/generate-work-order).
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
        Dto.WorkOrder created = upsert(wo); // upsert persiste gia
        // Aggiorna l'avviso con l'OdL collegato.
        notifications.put(notificationNumber, withOdl(n, created.externalCode()));
        persist();
        return created;
    }

    /** Crea atomicamente un Avviso + l'ODL collegato (entrambi completi). */
    public Dto.AvvisoWithOdlResponse createAvvisoWithOdl(Dto.AvvisoWithOdlRequest req) {
        Dto.Notification savedAvviso = normalizeNotification(req.avviso());
        notifications.put(savedAvviso.numeroAvviso(), savedAvviso);
        Dto.WorkOrder odl;
        if (req.odl() != null) {
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
            odl = upsert(linked); // persiste
        } else {
            odl = generateWorkOrderFrom(savedAvviso.numeroAvviso()); // persiste
        }
        if (odl != null && (savedAvviso.ordineDiLavoro() == null
                || savedAvviso.ordineDiLavoro().isBlank())) {
            Dto.Notification linkedAvviso = withOdl(savedAvviso, odl.externalCode());
            notifications.put(linkedAvviso.numeroAvviso(), linkedAvviso);
            persist();
            return new Dto.AvvisoWithOdlResponse(linkedAvviso, odl);
        }
        persist();
        return new Dto.AvvisoWithOdlResponse(notifications.get(savedAvviso.numeroAvviso()), odl);
    }

    /** Normalizza un Avviso in ingresso (id, default) senza persistere. */
    private Dto.Notification normalizeNotification(Dto.Notification n) {
        String num = (n.numeroAvviso() == null || n.numeroAvviso().isBlank())
                ? String.valueOf(notifSequence.incrementAndGet())
                : n.numeroAvviso();
        return new Dto.Notification(
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

    // ─── Esiti -------------------------------------------------------------

    /** Persiste un esito intervento (M5) e lo collega all'OdL. */
    public String saveEsito(Map<String, Object> esito) {
        String esitoId = "ES-" + UUID.randomUUID();
        Map<String, Object> record = new LinkedHashMap<>(esito);
        record.put("esitoId", esitoId);
        record.put("createdAt", LocalDateTime.now().toString());
        esiti.add(record);
        // Se l'esito e collegato a un OdL, portalo a COMPLETATO.
        Object code = esito.get("workOrderCode");
        if (code != null && orders.containsKey(code.toString())) {
            updateStatus(code.toString(), "COMPLETATO", null, null); // persiste
        } else {
            persist();
        }
        return esitoId;
    }

    // ─── Allegati (M8) -------------------------------------------------------------

    /** Salva un allegato: scrive il file su disco e ne registra i metadati. */
    public Map<String, Object> saveAttachment(String workOrderCode, String type,
                                              String fileName, String contentType,
                                              byte[] bytes) {
        String id = "AT-" + UUID.randomUUID();
        String safeName = (fileName == null || fileName.isBlank())
                ? id : fileName.replaceAll("[\\\\/:*?\"<>|]", "_");
        String folder = (workOrderCode == null || workOrderCode.isBlank()) ? "_" : workOrderCode;
        Path dir = Path.of(attachmentsDir, folder);
        Path filePath = dir.resolve(id + "_" + safeName);
        try {
            Files.createDirectories(dir);
            Files.write(filePath, bytes == null ? new byte[0] : bytes);
        } catch (IOException e) {
            throw new IllegalStateException("Impossibile salvare l'allegato: " + filePath, e);
        }
        Map<String, Object> meta = new LinkedHashMap<>();
        meta.put("id", id);
        meta.put("workOrderCode", workOrderCode);
        meta.put("type", type);
        meta.put("fileName", fileName);
        meta.put("mimeType", contentType);
        meta.put("size", bytes == null ? 0 : bytes.length);
        meta.put("path", filePath.toString());
        meta.put("capturedAt", LocalDateTime.now().toString());
        meta.put("url", "/work-orders/" + workOrderCode + "/attachments/" + id + "/file");
        meta.put("author", "");
        attachments.add(meta);
        persist();
        return meta;
    }

    public List<Map<String, Object>> findAttachments(String workOrderCode) {
        synchronized (attachments) {
            return attachments.stream()
                    .filter(a -> workOrderCode == null
                            || workOrderCode.equals(mapStr(a, "workOrderCode")))
                    .toList();
        }
    }

    public Optional<Map<String, Object>> findAttachment(String id) {
        synchronized (attachments) {
            return attachments.stream()
                    .filter(a -> id != null && id.equals(mapStr(a, "id")))
                    .findFirst();
        }
    }

    /** Legge i byte del file allegato dal disco (per il download). */
    public byte[] readAttachmentBytes(String id) {
        Map<String, Object> a = findAttachment(id).orElse(null);
        if (a == null) return null;
        String path = mapStr(a, "path");
        if (path.isBlank()) return null;
        try {
            return Files.readAllBytes(Path.of(path));
        } catch (IOException e) {
            return null;
        }
    }

    /** Elimina un allegato: rimuove il file dal disco e i metadati da Excel. */
    public boolean deleteAttachment(String id) {
        Map<String, Object> a = findAttachment(id).orElse(null);
        if (a == null) return false;
        String path = mapStr(a, "path");
        if (!path.isBlank()) {
            try {
                Files.deleteIfExists(Path.of(path));
            } catch (IOException ignored) {
                // file già assente o non eliminabile: procediamo comunque coi metadati
            }
        }
        attachments.remove(a);
        persist();
        return true;
    }

    // ─── Anagrafiche -------------------------------------------------------------

    public List<Dto.MaterialItem> materials(String q) {
        if (q == null || q.isBlank()) return materialsCatalog;
        String s = q.toLowerCase();
        return materialsCatalog.stream().filter(m ->
                m.materialCode().toLowerCase().contains(s)
                        || m.description().toLowerCase().contains(s)
                        || (m.barcode() != null && m.barcode().contains(s))).toList();
    }

    public List<Dto.Warehouse> warehouses() { return warehousesCatalog; }
    public List<String> meterBrands() { return meterBrandsCatalog; }
    public List<String> tamCodes() { return tamCodesCatalog; }
    public List<Dto.CodeLabel> causes() { return causesCatalog; }
    public List<Dto.CodeLabel> solutions() { return solutionsCatalog; }

    /** Ricerca equipment per matricola o barcode (primo match). */
    public Dto.Equipment findEquipment(String matricola, String barcode) {
        return equipmentCatalog.stream()
                .filter(e -> (matricola != null && !matricola.isBlank()
                                && matricola.equalsIgnoreCase(e.matricola()))
                        || (barcode != null && !barcode.isBlank()
                                && barcode.equalsIgnoreCase(e.barcode())))
                .findFirst().orElse(null);
    }

    /** Elenco/ricerca tecnici (Cambio CID, riassegnazione). */
    public List<Dto.Technician> technicians(String q) {
        if (q == null || q.isBlank()) return techniciansCatalog;
        String s = q.toLowerCase();
        return techniciansCatalog.stream().filter(t ->
                (t.cid() != null && t.cid().toLowerCase().contains(s))
                        || (t.nome() != null && t.nome().toLowerCase().contains(s))
                        || (t.cognome() != null && t.cognome().toLowerCase().contains(s)))
                .toList();
    }

    // ─── Default anagrafiche -------------------------------------------------------------

    private void seedReferenceDefaults() {
        materialsCatalog = new ArrayList<>(List.of(
                new Dto.MaterialItem("M001", "Contatore acqua DN15", "PZ", "8001234560011", "W01", 12.0),
                new Dto.MaterialItem("M002", "Contatore acqua DN20", "PZ", "8001234560028", "W01", 7.0),
                new Dto.MaterialItem("M010", "Guarnizione gomma DN15", "PZ", "8001234560103", "W01", 48.0),
                new Dto.MaterialItem("M020", "Sigillo antifrode", "PZ", "8001234560202", "W01", 100.0),
                new Dto.MaterialItem("M030", "Tubo PE DN25", "M", "8001234560301", "W01", 80.0)));
        warehousesCatalog = new ArrayList<>(List.of(
                new Dto.Warehouse("W01", "Furgone Tecnico"),
                new Dto.Warehouse("W02", "Magazzino Centrale ANCONA"),
                new Dto.Warehouse("W03", "Magazzino JESI")));
        meterBrandsCatalog = new ArrayList<>(List.of(
                "MADDALENA", "SENSUS", "ITRON", "ZENNER", "DIEHL"));
        tamCodesCatalog = new ArrayList<>(List.of("ATTI", "DISA", "ZA01", "ZA02", "PA"));
        causesCatalog = new ArrayList<>(List.of(
                new Dto.CodeLabel("C001", "Intervento programmato"),
                new Dto.CodeLabel("C002", "Perdita su rete"),
                new Dto.CodeLabel("C003", "Contatore guasto"),
                new Dto.CodeLabel("C004", "Richiesta cliente"),
                new Dto.CodeLabel("C005", "Verifica periodica")));
        solutionsCatalog = new ArrayList<>(List.of(
                new Dto.CodeLabel("S001", "Sostituzione contatore"),
                new Dto.CodeLabel("S002", "Riparazione perdita"),
                new Dto.CodeLabel("S003", "Apertura fornitura"),
                new Dto.CodeLabel("S004", "Chiusura fornitura (DISA)"),
                new Dto.CodeLabel("S005", "Lettura effettuata")));
        equipmentCatalog = new ArrayList<>(List.of(
                new Dto.Equipment("20114578", "8001234560011", "MADDALENA",
                        "MIS. ACQUA 015 5 CIF", "Centro", "ANCONA", "TS-001-ANC",
                        "2022-03-15", "ATTIVO"),
                new Dto.Equipment("20999999", "8001234560028", "SENSUS",
                        "MIS. ACQUA 020 5 CIF", "Periferia Nord", "JESI", "TS-002-JES",
                        "2021-07-01", "ATTIVO")));
        techniciansCatalog = new ArrayList<>(List.of(
                new Dto.Technician("VAIOTTIM", "Marco", "Vaiotti", "vaiottim@wfm.local",
                        "tecnicoSenior", "WC01", "Squadra Nord"),
                new Dto.Technician("ROSSIPAO", "Paolo", "Rossi", "rossipao@wfm.local",
                        "tecnico", "WC01", "Squadra Nord"),
                new Dto.Technician("BIANCRG", "Giulia", "Bianchi", "biancrg@wfm.local",
                        "tecnico", "WC02", "Squadra Sud"),
                new Dto.Technician("CONTISAR", "Sara", "Conti", "contisar@wfm.local",
                        "tecnicoSenior", "WC02", "Squadra Sud")));
    }

    // ─── Helper POI / JSON -------------------------------------------------------------

    private static List<Dto.Operation> templateOperations(String cid, String date, String workCenter) {
        return List.of(
                new Dto.Operation("OP-T-1", "0010", "SOPR-001",
                        "Sopralluogo iniziale", cid,
                        "Verifica del punto di intervento, valutazione tecnica e "
                                + "identificazione delle attivita necessarie.",
                        workCenter, date, date, 0.5, null, null, null, false),
                new Dto.Operation("OP-T-2", "0020", "EXEC-001",
                        "Esecuzione intervento", cid,
                        "Esecuzione delle lavorazioni previste come da spec.",
                        workCenter, date, date, 2.0, null, null, null, false),
                new Dto.Operation("OP-T-3", "0030", "VRF-001",
                        "Verifica e chiusura", cid,
                        "Verifica funzionalita, ripristino sito, chiusura OdL.",
                        workCenter, date, date, 0.5, null, null, null, false));
    }

    private interface RowMapper<T> { T map(Row row); }

    private <T> List<T> readRows(Workbook wb, String sheetName, RowMapper<T> mapper) {
        List<T> out = new ArrayList<>();
        Sheet sheet = wb.getSheet(sheetName);
        if (sheet == null) return out;
        for (int i = sheet.getFirstRowNum() + 1; i <= sheet.getLastRowNum(); i++) {
            Row row = sheet.getRow(i);
            if (row == null) continue;
            String first = str(row, 0);
            if (first == null || first.isBlank()) continue;
            out.add(mapper.map(row));
        }
        return out;
    }

    private void forEachJsonRow(Workbook wb, String sheetName, java.util.function.Consumer<String> consumer) {
        Sheet sheet = wb.getSheet(sheetName);
        if (sheet == null) return;
        Row headerRow = sheet.getRow(sheet.getFirstRowNum());
        if (headerRow == null) return;
        int jsonCol = -1;
        for (int c = 0; c < headerRow.getLastCellNum(); c++) {
            if (JSON_COL.equals(str(headerRow, c))) { jsonCol = c; break; }
        }
        if (jsonCol < 0) return;
        for (int i = sheet.getFirstRowNum() + 1; i <= sheet.getLastRowNum(); i++) {
            Row row = sheet.getRow(i);
            if (row == null) continue;
            String json = str(row, jsonCol);
            if (json != null && !json.isBlank()) consumer.accept(json);
        }
    }

    private <T> void writeSheet(Workbook wb, String name, List<String> headers,
                                List<T> items, java.util.function.Function<T, List<String>> row) {
        Sheet sheet = wb.createSheet(name);
        header(sheet, headers);
        int r = 1;
        for (T item : items) {
            Row rr = sheet.createRow(r++);
            List<String> values = row.apply(item);
            for (int c = 0; c < values.size(); c++) set(rr, c, values.get(c));
        }
    }

    private void header(Sheet sheet, List<String> headers) {
        Row row = sheet.createRow(0);
        for (int c = 0; c < headers.size(); c++) set(row, c, headers.get(c));
    }

    private static void set(Row row, int col, String value) {
        row.createCell(col).setCellValue(value == null ? "" : value);
    }

    private static String str(Row row, int col) {
        Cell cell = row.getCell(col);
        if (cell == null) return "";
        return switch (cell.getCellType()) {
            case STRING -> cell.getStringCellValue();
            case NUMERIC -> {
                double d = cell.getNumericCellValue();
                yield d == Math.floor(d) ? String.valueOf((long) d) : String.valueOf(d);
            }
            case BOOLEAN -> String.valueOf(cell.getBooleanCellValue());
            default -> "";
        };
    }

    private static Double dbl(Row row, int col) {
        String s = str(row, col);
        if (s == null || s.isBlank()) return null;
        try { return Double.parseDouble(s); } catch (NumberFormatException e) { return null; }
    }

    private String toJson(Object o) {
        try { return objectMapper.writeValueAsString(o); }
        catch (Exception e) { throw new IllegalStateException("Serializzazione JSON fallita", e); }
    }

    private <T> T fromJson(String s, Class<T> clazz) {
        try { return objectMapper.readValue(s, clazz); }
        catch (Exception e) { return null; }
    }

    @SuppressWarnings("unchecked")
    private Map<String, Object> fromJsonMap(String s) {
        try { return objectMapper.readValue(s, Map.class); }
        catch (Exception e) { return null; }
    }

    private static String mapStr(Map<String, Object> m, String key) {
        Object v = m.get(key);
        return v == null ? "" : v.toString();
    }

    private static String nz(Object v) { return v == null ? "" : v.toString(); }

    private static <T> T or(T a, T b) { return a != null ? a : b; }
}
