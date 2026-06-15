package com.wfm.middleware.controller;

import com.wfm.middleware.dto.Dto;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

/**
 * Autenticazione (M1). In produzione: WS-Security UsernameToken verso SAP
 * (specifiche §8.2). Qui restituiamo un token JWT-like fittizio.
 */
@RestController
@RequestMapping("/auth")
public class AuthController {

    @PostMapping("/login")
    public ResponseEntity<Dto.LoginResponse> login(@RequestBody Dto.LoginRequest req) {
        if (req.cid() == null || req.cid().isBlank()
                || req.password() == null || req.password().isBlank()) {
            return ResponseEntity.status(401).build();
        }
        String cid = req.cid().toUpperCase();
        return ResponseEntity.ok(new Dto.LoginResponse(
                cid, "Marco", "Vaiotti",
                cid.toLowerCase() + "@wfm.local",
                "WC01", "Squadra Nord",
                "tk-" + UUID.randomUUID()));
    }

    @PostMapping("/logout")
    public ResponseEntity<Void> logout() {
        return ResponseEntity.noContent().build();
    }
}
