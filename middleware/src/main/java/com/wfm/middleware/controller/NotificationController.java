package com.wfm.middleware.controller;

import com.wfm.middleware.dto.Dto;
import com.wfm.middleware.store.InMemoryStore;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

/**
 * Avvisi (M9). Mapping verso WS SAP:
 *   GET    /notifications                              -> getNotificationsByTechnician
 *   GET    /notifications/{id}                         -> getNotificationDetail
 *   POST   /notifications                              -> creaNotifica
 *   POST   /notifications/{id}/generate-work-order     -> generazione OdL collegato
 */
@RestController
@RequestMapping("/notifications")
public class NotificationController {

    private final InMemoryStore store;
    public NotificationController(InMemoryStore store) { this.store = store; }

    @GetMapping
    public Dto.NotificationList list(@RequestParam(required = false) String q) {
        return new Dto.NotificationList(store.findNotifications(q));
    }

    @GetMapping("/{id}")
    public ResponseEntity<Dto.Notification> detail(@PathVariable String id) {
        return store.findNotification(id)
                .map(ResponseEntity::ok)
                .orElseGet(() -> ResponseEntity.notFound().build());
    }

    @PostMapping
    public ResponseEntity<Dto.Notification> create(@RequestBody Dto.Notification body) {
        return ResponseEntity.status(201).body(store.saveNotification(body));
    }

    @PostMapping("/{id}/generate-work-order")
    public ResponseEntity<Dto.WorkOrder> generate(@PathVariable String id) {
        Dto.WorkOrder wo = store.generateWorkOrderFrom(id);
        if (wo == null) return ResponseEntity.notFound().build();
        return ResponseEntity.status(201).body(wo);
    }
}
