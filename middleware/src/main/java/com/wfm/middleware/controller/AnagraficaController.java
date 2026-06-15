package com.wfm.middleware.controller;

import com.wfm.middleware.dto.Dto;
import com.wfm.middleware.store.InMemoryStore;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * Anagrafiche (M7 / M11): materiali, magazzini, marche contatori, codici TAM,
 * cause/soluzioni. Mapping verso WS SAP "AnagraficheService".
 */
@RestController
@RequestMapping("/anagrafica")
public class AnagraficaController {

    private final InMemoryStore store;
    public AnagraficaController(InMemoryStore store) { this.store = store; }

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
}
