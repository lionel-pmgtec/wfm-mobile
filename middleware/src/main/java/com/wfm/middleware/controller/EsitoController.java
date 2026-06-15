package com.wfm.middleware.controller;

import com.wfm.middleware.dto.Dto;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.Map;
import java.util.UUID;

/**
 * Esito intervento (M5) e allegati (M8).
 *
 *  POST /esiti                  -> submitEsito (flussi S13 + E55)
 *  POST /esiti/attachments      -> inviaEsitoAllegato (MTOM/XOP via SOAP)
 */
@RestController
@RequestMapping("/esiti")
public class EsitoController {

    @PostMapping
    public ResponseEntity<Dto.EsitoResponse> submit(@RequestBody Map<String, Object> esito) {
        // In produzione: validazione + chiamata SOAP submitEsito verso SAP.
        String esitoId = "ES-" + UUID.randomUUID();
        String sapDoc  = "SAP-" + System.currentTimeMillis();
        return ResponseEntity.ok(new Dto.EsitoResponse("OK", esitoId, sapDoc));
    }

    @PostMapping(value = "/attachments", consumes = "multipart/form-data")
    public ResponseEntity<Map<String, Object>> uploadAttachment(
            @RequestParam("workOrderCode") String workOrderCode,
            @RequestParam("type") String type,
            @RequestParam("file") MultipartFile file) {
        // In produzione: invio MTOM/XOP verso SAP.
        return ResponseEntity.ok(Map.of(
                "status", "OK",
                "id", UUID.randomUUID().toString(),
                "workOrderCode", workOrderCode,
                "type", type,
                "fileName", file.getOriginalFilename(),
                "size", file.getSize()));
    }
}
