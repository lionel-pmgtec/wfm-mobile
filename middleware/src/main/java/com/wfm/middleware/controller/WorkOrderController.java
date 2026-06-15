package com.wfm.middleware.controller;

import com.wfm.middleware.dto.Dto;
import com.wfm.middleware.store.InMemoryStore;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * Ordini di Lavoro (M2, M3, M4, M10).
 *
 * Endpoints :
 *   GET    /work-orders               -> getWorkOrdersByTechnician
 *   GET    /work-orders/{id}          -> getWorkOrderDetail
 *   POST   /work-orders               -> createWorkOrderFromField (flusso I4)
 *   PATCH  /work-orders/{id}/status   -> aggiornaStatoOrdineDiLavoro (S51 / S13)
 */
@RestController
@RequestMapping("/work-orders")
public class WorkOrderController {

    private final InMemoryStore store;
    public WorkOrderController(InMemoryStore store) { this.store = store; }

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
     * Creazione dell'OdL. Se externalCode e vuoto, il middleware ne genera uno.
     * Se operations e vuoto/null, viene applicato il template standard.
     */
    @PostMapping
    public ResponseEntity<Dto.WorkOrder> create(@RequestBody Dto.WorkOrder body) {
        Dto.WorkOrder created = store.upsert(body);
        return ResponseEntity.status(201).body(created);
    }

    @PatchMapping("/{id}/status")
    public ResponseEntity<Dto.WorkOrder> changeStatus(
            @PathVariable String id, @RequestBody Dto.StatusUpdateRequest body) {
        Dto.WorkOrder updated = store.updateStatus(id, body.status(), body.reason(), body.note());
        if (updated == null) return ResponseEntity.notFound().build();
        return ResponseEntity.ok(updated);
    }

    @GetMapping("/{id}/attachments")
    public java.util.Map<String, List<Object>> attachments(@PathVariable String id) {
        return java.util.Map.of("attachments", List.of());
    }
}
