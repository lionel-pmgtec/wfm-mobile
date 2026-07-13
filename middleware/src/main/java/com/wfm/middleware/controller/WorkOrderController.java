package com.wfm.middleware.controller;

/**
 *
 * Ordini  di lavoro
 *
 * Endpoints :
 *  GET    /work-orders               -> getWorkOrdersByTechnician
 *  GET    /work-orders/{id}          -> getWorkOrderDetail
 *  POST   /work-orders               -> createWorkOrderFromField (flusso I4)
 *  PATCH  /work-orders/{id}/status   -> aggiornaStatoOrdineDiLavoro (S51 / S13)
 */

import com.wfm.middleware.dto.Dto;
import com.wfm.middleware.service.WorkOrderNotifier;
import com.wfm.middleware.store.ExcelStore;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/work-orders")
public class WorkOrderController {

    private final ExcelStore store;
    private final WorkOrderNotifier notifier;

    public WorkOrderController(ExcelStore store, WorkOrderNotifier notifier) {
        this.store = store;
        this.notifier = notifier;
    }

    @GetMapping
    public Dto.WorkOrderList list(
            @RequestParam(required = false) String status,
            @RequestParam(required = false) String q,
            @RequestParam(required = false) String date) {
        List<Dto.WorkOrder> result = store.findOrders(status, q, date);
        return new Dto.WorkOrderList(result);
    }

    @GetMapping("/{id}")
    public ResponseEntity<Dto.WorkOrder> detail(@PathVariable String id) {
        return store.findOrder(id)
                .map(ResponseEntity::ok)
                .orElseGet(() -> ResponseEntity.notFound().build());
    }

    /**
     * Creazione dell'ODL. Se externalCode è vuoto, il middleware ne genera uno.
     * Se operations è vuoto/null, viene applicato il template standard.
     */
    @PostMapping
    public ResponseEntity<Dto.WorkOrder> create(@RequestBody Dto.WorkOrder body) {
        Dto.WorkOrder created = store.upsert(body);
        notifier.notifyAssignedTechnician(created);
        return ResponseEntity.status(201).body(created);
    }

    /**
     * Aggiornamento generico dell'OdL (materiali, chiusura, note, ecc.).
     * Il body è l'OdL completo con externalCode = {id}. Persiste su Excel.
     */
    @PatchMapping("/{id}")
    public ResponseEntity<Dto.WorkOrder> update(
            @PathVariable String id, @RequestBody Dto.WorkOrder body) {
        if (store.findOrder(id).isEmpty()) return ResponseEntity.notFound().build();
        Dto.WorkOrder saved = store.upsert(body);
        return ResponseEntity.ok(saved);
    }

    /** Elimina un OdL. 204 se eliminato, 404 se inesistente. */
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable String id) {
        return store.deleteOrder(id)
                ? ResponseEntity.noContent().build()
                : ResponseEntity.notFound().build();
    }

    @PatchMapping("/{id}/status")
    public ResponseEntity<Dto.WorkOrder> changeStatus(
            @PathVariable String id, @RequestBody Dto.StatusUpdateRequest body) {
        Dto.WorkOrder updated = store.updateStatus(id, body.status(), body.reason(), body.note());
        if (updated == null) return ResponseEntity.notFound().build();
        return ResponseEntity.ok(updated);
    }

    /** Metadati degli allegati di un OdL. */
    @GetMapping("/{id}/attachments")
    public Map<String, Object> attachments(@PathVariable String id) {
        return Map.of("attachments", store.findAttachments(id));
    }

    /** Download del file allegato (bytes). */
    @GetMapping("/{id}/attachments/{attId}/file")
    public ResponseEntity<byte[]> attachmentFile(
            @PathVariable String id, @PathVariable String attId) {
        byte[] bytes = store.readAttachmentBytes(attId);
        if (bytes == null) return ResponseEntity.notFound().build();
        String contentType = store.findAttachment(attId)
                .map(a -> a.get("mimeType"))
                .filter(java.util.Objects::nonNull)
                .map(Object::toString)
                .orElse("application/octet-stream");
        return ResponseEntity.ok().header("Content-Type", contentType).body(bytes);
    }

    /** Elimina un allegato (file + metadati). */
    @DeleteMapping("/{id}/attachments/{attId}")
    public ResponseEntity<Void> deleteAttachment(
            @PathVariable String id, @PathVariable String attId) {
        return store.deleteAttachment(attId)
                ? ResponseEntity.noContent().build()
                : ResponseEntity.notFound().build();
    }
}
