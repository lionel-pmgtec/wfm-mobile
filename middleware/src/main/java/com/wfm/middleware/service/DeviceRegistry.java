package com.wfm.middleware.service;

import org.springframework.stereotype.Component;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Registro in memoria dei token FCM per CID tecnico.
 *
 * L'app ri-registra il proprio token ad ogni login (POST /devices), quindi la
 * mappa si ripopola automaticamente dopo un riavvio del middleware.
 */
@Component
public class DeviceRegistry {

    private final Map<String, String> cidToToken = new ConcurrentHashMap<>();

    public void register(String cid, String fcmToken) {
        if (cid == null || cid.isBlank() || fcmToken == null || fcmToken.isBlank()) return;
        cidToToken.put(cid.toUpperCase(), fcmToken);
    }

    /** Token del dispositivo del tecnico, o null se non registrato. */
    public String tokenFor(String cid) {
        return cid == null ? null : cidToToken.get(cid.toUpperCase());
    }
}
