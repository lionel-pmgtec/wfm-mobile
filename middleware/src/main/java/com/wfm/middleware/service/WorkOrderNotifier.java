package com.wfm.middleware.service;

import com.wfm.middleware.dto.Dto;
import org.springframework.stereotype.Component;

import java.util.HashMap;
import java.util.Map;

/**
 * Invia la notifica push al tecnico assegnato alla creazione di un OdL.
 * Usato sia da {@code POST /work-orders} sia da {@code POST /workflow/avviso-with-odl}.
 */
@Component
public class WorkOrderNotifier {

    private final DeviceRegistry devices;
    private final PushService push;

    public WorkOrderNotifier(DeviceRegistry devices, PushService push) {
        this.devices = devices;
        this.push = push;
    }

    public void notifyAssignedTechnician(Dto.WorkOrder odl) {
        if (odl == null || odl.technicianCID() == null) return;
        String token = devices.tokenFor(odl.technicianCID());
        if (token == null) return;

        String code = odl.externalCode() != null ? odl.externalCode() : "";
        String tipo = odl.woTypeDescription() != null ? odl.woTypeDescription()
                : (odl.woType() != null ? odl.woType() : "OdL");

        Map<String, String> data = new HashMap<>();
        data.put("type", "nuovoOdl");
        data.put("source", "firebase-fcm"); // marcatore per distinguere dal polling locale
        if (!code.isBlank()) {
            data.put("relatedId", code);
            data.put("routePath", "/work-orders/" + code);
        }

        push.sendToToken(
                token,
                "Nuovo Ordine di Lavoro",
                (tipo + " " + code).trim() + " assegnato a te",
                data);
    }
}
