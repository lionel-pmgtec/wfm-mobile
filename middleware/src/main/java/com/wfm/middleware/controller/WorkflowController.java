package com.wfm.middleware.controller;

import com.wfm.middleware.dto.Dto;
import com.wfm.middleware.store.InMemoryStore;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

/**
 * Endpoint di workflow combinato : creazione ATOMICA di un Avviso di
 * Servizio e l'Ordine di Lavoro collegato.
 *
 *   POST /workflow/avviso-with-odl
 *
 * Comportamento :
 *   - Salva l'Avviso con tutti i campi
 *   - Se nel body e presente "odl", lo crea linkandolo all'Avviso
 *   - Se "odl" e null, l'OdL viene generato dal template con le operazioni
 *     standard (Sopralluogo / Esecuzione / Verifica e chiusura)
 *   - Aggiorna l'Avviso con il riferimento all'OdL appena creato
 *
 * Restituisce { "avviso": {...}, "odl": {...} }.
 */
@RestController
@RequestMapping("/workflow")
public class WorkflowController {

    private final InMemoryStore store;
    public WorkflowController(InMemoryStore store) { this.store = store; }

    @PostMapping("/avviso-with-odl")
    public ResponseEntity<Dto.AvvisoWithOdlResponse> createAvvisoWithOdl(
            @RequestBody Dto.AvvisoWithOdlRequest request) {
        if (request == null || request.avviso() == null) {
            return ResponseEntity.badRequest().build();
        }
        Dto.AvvisoWithOdlResponse resp = store.createAvvisoWithOdl(request);
        return ResponseEntity.status(201).body(resp);
    }
}
