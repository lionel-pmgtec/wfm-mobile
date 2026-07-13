package com.wfm.middleware.controller;

import com.wfm.middleware.dto.Dto;
import com.wfm.middleware.store.ExcelStore;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Esito intervento (M5) e allegati (M8).
 *
 *  POST /esiti                  -> submitEsito (flussi S13 + E55)
 *  POST /esiti/attachments      -> inviaEsitoAllegato (MTOM/XOP via SOAP)
 */
@RestController
@RequestMapping("/esiti")
public class EsitoController {

    private final ExcelStore store;
    public EsitoController(ExcelStore store) { this.store = store; }

    @PostMapping
    public ResponseEntity<Dto.EsitoResponse> submit(@RequestBody Map<String, Object> esito) {
        // Persiste l'esito nel database Excel e porta l'OdL collegato a COMPLETATO.
        // In produzione: validazione + chiamata SOAP submitEsito verso SAP.
        String esitoId = store.saveEsito(esito);
        String sapDoc  = "SAP-" + System.currentTimeMillis();
        return ResponseEntity.ok(new Dto.EsitoResponse("OK", esitoId, sapDoc));
    }

    @PostMapping(value = "/attachments", consumes = "multipart/form-data")
    public ResponseEntity<Map<String, Object>> uploadAttachment(
            @RequestParam("workOrderCode") String workOrderCode,
            @RequestParam("type") String type,
            @RequestParam("file") MultipartFile file) throws IOException {
        // Salva il file su disco + metadati nel database Excel (scheda Allegati).
        // In produzione: invio MTOM/XOP verso SAP.
        Map<String, Object> meta = store.saveAttachment(
                workOrderCode, type, file.getOriginalFilename(),
                file.getContentType(), file.getBytes());
        Map<String, Object> resp = new LinkedHashMap<>(meta);
        resp.put("status", "OK");
        return ResponseEntity.ok(resp);
    }
}
