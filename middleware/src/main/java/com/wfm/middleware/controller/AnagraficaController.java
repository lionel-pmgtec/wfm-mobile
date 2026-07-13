package com.wfm.middleware.controller;

import com.wfm.middleware.dto.Dto;
import com.wfm.middleware.store.ExcelStore;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * Anagrafiche (M7 / M11): materiali, magazzini, marche contatori, codici TAM,
 * cause/soluzioni, equipment, tecnici. Mapping verso WS SAP "AnagraficheService".
 */
@RestController
@RequestMapping("/anagrafica")
public class AnagraficaController {

    private final ExcelStore store;
    public AnagraficaController(ExcelStore store) { this.store = store; }

    @GetMapping("/materials")
    public List<Dto.MaterialItem> materials(@RequestParam(required = false) String q) {
        return store.materials(q);
    }

    @GetMapping("/warehouses")
    public List<Dto.Warehouse> warehouses() { return store.warehouses(); }

    @GetMapping("/meter-brands")
    public List<String> meterBrands() { return store.meterBrands(); }

    @GetMapping("/tam-codes")
    public List<String> tamCodes() { return store.tamCodes(); }

    @GetMapping("/causes")
    public List<Dto.CodeLabel> causes() { return store.causes(); }

    @GetMapping("/solutions")
    public List<Dto.CodeLabel> solutions() { return store.solutions(); }

    /** Ricerca equipment per matricola o barcode (Standalone). */
    @GetMapping("/equipment")
    public ResponseEntity<Dto.Equipment> equipment(
            @RequestParam(required = false) String matricola,
            @RequestParam(required = false) String barcode) {
        Dto.Equipment e = store.findEquipment(matricola, barcode);
        return e == null ? ResponseEntity.notFound().build() : ResponseEntity.ok(e);
    }

    /** Elenco/ricerca tecnici (Cambio CID, riassegnazione OdL). */
    @GetMapping("/tecnici")
    public List<Dto.Technician> tecnici(@RequestParam(required = false) String q) {
        return store.technicians(q);
    }

    /** Alias di /tecnici usato dalla riassegnazione OdL (lista operatori). */
    @GetMapping("/operatori")
    public List<Dto.Technician> operatori(@RequestParam(required = false) String q) {
        return store.technicians(q);
    }
}
