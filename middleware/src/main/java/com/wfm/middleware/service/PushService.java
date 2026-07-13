package com.wfm.middleware.service;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingException;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.Notification;
import jakarta.annotation.PostConstruct;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;
import java.util.Map;

/**
 * Invio delle notifiche push (Firebase Cloud Messaging) tramite Firebase Admin.
 *
 * Resiliente: se la chiave service account non è configurata o non è
 * raggiungibile, il servizio resta disattivato e {@link #sendToToken} è un
 * no-op — il middleware continua a funzionare normalmente.
 */
@Service
public class PushService {

    private static final Logger log = LoggerFactory.getLogger(PushService.class);

    @Value("${wfm.firebase.service-account:}")
    private String serviceAccountPath;

    /** null => push disattivate. */
    private FirebaseMessaging messaging;

    @PostConstruct
    void init() {
        if (serviceAccountPath == null || serviceAccountPath.isBlank()) {
            log.warn("[fcm] Nessun 'wfm.firebase.service-account' configurato: push disattivate.");
            return;
        }
        try (InputStream is = openCredentials(serviceAccountPath)) {
            if (is == null) {
                log.warn("[fcm] Chiave Firebase non trovata ({}): push disattivate.", serviceAccountPath);
                return;
            }
            FirebaseOptions options = FirebaseOptions.builder()
                    .setCredentials(GoogleCredentials.fromStream(is))
                    .build();
            FirebaseApp app = FirebaseApp.getApps().isEmpty()
                    ? FirebaseApp.initializeApp(options)
                    : FirebaseApp.getInstance();
            messaging = FirebaseMessaging.getInstance(app);
            log.info("[fcm] Firebase Admin inizializzato: push attive.");
        } catch (Exception e) {
            log.error("[fcm] Inizializzazione Firebase fallita ({}): push disattivate.", e.getMessage());
        }
    }

    /** Apre la chiave da classpath: (dentro resources) o da filesystem (file: o path nudo). */
    private InputStream openCredentials(String path) throws Exception {
        if (path.startsWith("classpath:")) {
            return getClass().getClassLoader()
                    .getResourceAsStream(path.substring("classpath:".length()));
        }
        String fsPath = path.startsWith("file:") ? path.substring("file:".length()) : path;
        File f = new File(fsPath);
        return f.exists() ? new FileInputStream(f) : null;
    }

    public boolean isEnabled() {
        return messaging != null;
    }

    /**
     * Invia una notifica a un singolo token FCM. No-op se le push sono
     * disattivate, il token è vuoto o l'invio fallisce (errore solo loggato).
     */
    public void sendToToken(String token, String title, String body, Map<String, String> data) {
        if (messaging == null || token == null || token.isBlank()) return;
        try {
            Message.Builder mb = Message.builder()
                    .setToken(token)
                    .setNotification(Notification.builder()
                            .setTitle(title)
                            .setBody(body)
                            .build());
            if (data != null) data.forEach(mb::putData);
            String id = messaging.send(mb.build());
            log.info("[fcm] Push inviata (id={}): {}", id, title);
        } catch (FirebaseMessagingException e) {
            log.warn("[fcm] Invio push fallito: {}", e.getMessage());
        }
    }
}
