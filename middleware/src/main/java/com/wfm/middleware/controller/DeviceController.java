package com.wfm.middleware.controller;

import com.wfm.middleware.dto.Dto;
import com.wfm.middleware.service.DeviceRegistry;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Registrazione dei dispositivi per le notifiche push (FCM).
 *
 *  POST /devices  -> memorizza il token FCM del tecnico (per CID).
 */
@RestController
@RequestMapping("/devices")
public class DeviceController {

    private final DeviceRegistry registry;

    public DeviceController(DeviceRegistry registry) {
        this.registry = registry;
    }

    @PostMapping
    public ResponseEntity<Void> register(@RequestBody Dto.DeviceRegistration body) {
        registry.register(body.cid(), body.fcmToken());
        return ResponseEntity.noContent().build();
    }
}

