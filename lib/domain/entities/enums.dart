import 'package:flutter/material.dart';

/// Stato del ciclo di vita di un OdL (specifiche EF-M4.1).
enum WorkOrderStatus {
  ricevuto,     // Assegnato al tecnico, non ancora avviato
  inEsecuzione, // In esecuzione (stato reale su server)
  inPausa,      // LOCAL ONLY — sul server rimane inEsecuzione
  sospeso,      // Sospeso — restituito al Cruscotto
  completato,   // Chiuso dal tecnico
  annullato,    // Annullato
  inviatoSAP;   // Inviato a SAP (post-completamento, stato finale)

  String get label => switch (this) {
        WorkOrderStatus.ricevuto => 'Assegnato',
        WorkOrderStatus.inEsecuzione => 'In esecuzione',
        WorkOrderStatus.inPausa => 'In pausa',
        WorkOrderStatus.sospeso => 'Sospeso',
        WorkOrderStatus.completato => 'Chiuso',
        WorkOrderStatus.annullato => 'Annullato',
        WorkOrderStatus.inviatoSAP => 'Inviato a SAP',
      };

  /// Codice SAP corrispondente.
  /// inPausa → IN_ESECUZIONE: è uno stato locale, il server non lo conosce.
  String get sapCode => switch (this) {
        WorkOrderStatus.ricevuto => 'RICEVUTO',
        WorkOrderStatus.inEsecuzione => 'IN_ESECUZIONE',
        WorkOrderStatus.inPausa => 'IN_ESECUZIONE',
        WorkOrderStatus.sospeso => 'SOSPESO',
        WorkOrderStatus.completato => 'COMPLETATO',
        WorkOrderStatus.annullato => 'ANNULLATO',
        WorkOrderStatus.inviatoSAP => 'INVIATO_SAP',
      };

  static WorkOrderStatus fromSap(String? raw) {
    switch ((raw ?? '').toUpperCase().replaceAll(' ', '_')) {
      case 'RICEVUTO':
      case 'ASSEGNATO':
      case 'I0001':
        return WorkOrderStatus.ricevuto;
      case 'IN_ESECUZIONE':
      case 'IN_CORSO':
      case 'I0002':
        return WorkOrderStatus.inEsecuzione;
      case 'SOSPESO':
      case 'I0003':
        return WorkOrderStatus.sospeso;
      case 'COMPLETATO':
      case 'CHIUSO':
      case 'TERMINATO':
      case 'I0005':
        return WorkOrderStatus.completato;
      case 'ANNULLATO':
        return WorkOrderStatus.annullato;
      case 'INVIATO_SAP':
        return WorkOrderStatus.inviatoSAP;
      default:
        return WorkOrderStatus.ricevuto;
    }
  }
}

/// Stato di sincronizzazione locale dell'entità (specifiche §9.1).
enum LocalSyncStatus {
  synced,
  pendingUpload,
  error;

  String get label => switch (this) {
        LocalSyncStatus.synced => 'Sincronizzato',
        LocalSyncStatus.pendingUpload => 'In attesa',
        LocalSyncStatus.error => 'Errore',
      };
}

/// Esito dell'intervento (specifiche EF-M5.1).
enum EsitoResult {
  success,
  rinviato,
  impossibile;

  String get label => switch (this) {
        EsitoResult.success => 'Riuscito',
        EsitoResult.rinviato => 'Rinviato',
        EsitoResult.impossibile => 'Impossibile',
      };

  String get sapCode => switch (this) {
        EsitoResult.success => 'SUCCESS',
        EsitoResult.rinviato => 'POSTPONED',
        EsitoResult.impossibile => 'FAILED',
      };
}

/// Tipo di allegato (specifiche §9.1 - Allegato).
enum AttachmentType {
  fotoPrima,
  fotoDopo,
  firma,
  documento;

  String get label => switch (this) {
        AttachmentType.fotoPrima => 'Foto prima',
        AttachmentType.fotoDopo => 'Foto dopo',
        AttachmentType.firma => 'Firma',
        AttachmentType.documento => 'Documento',
      };

  String get sapCode => switch (this) {
        AttachmentType.fotoPrima => 'BEFORE',
        AttachmentType.fotoDopo => 'AFTER',
        AttachmentType.firma => 'SIGNATURE',
        AttachmentType.documento => 'DOCUMENT',
      };
}

/// Stato di upload di un allegato.
enum UploadStatus { local, uploading, uploaded, error }

/// Ruolo utente (matrice diritti, specifiche §4.4).
enum UserRole {
  tecnico,
  tecnicoSenior,
  readOnly;

  bool get canEdit => this != UserRole.readOnly;

  String get label => switch (this) {
        UserRole.tecnico => 'Tecnico',
        UserRole.tecnicoSenior => 'Tecnico Senior',
        UserRole.readOnly => 'Sola lettura',
      };
}

/// Tipo di operazione in coda di sincronizzazione (specifiche §9.3).
enum SyncOperationType {
  submitEsito,
  updateStatus,
  uploadAttachment,
  submitMeterReading,
  submitMaterials,
  createWorkOrder,
  createNotification,
}

/// Stato di un'operazione di sincronizzazione.
enum SyncStatus { pending, inProgress, success, failed }

/// Esito della sospensione/avvio (azioni del ciclo di vita).
enum LifecycleAction { avvia, sospendi, riprendi, concludi, annulla }

/// Stato dell'Avviso di Servizio (spec aziendale).
///
/// Flusso: creato → presoInCarico → inLavorazione → (sospeso) → chiuso
enum AvvisoStato {
  creato,
  presoInCarico,
  inLavorazione,
  sospeso,
  chiuso;

  String get label => switch (this) {
        AvvisoStato.creato => 'Creato',
        AvvisoStato.presoInCarico => 'Preso in carico',
        AvvisoStato.inLavorazione => 'In lavorazione',
        AvvisoStato.sospeso => 'Sospeso',
        AvvisoStato.chiuso => 'Chiuso',
      };

  String get sapCode => switch (this) {
        AvvisoStato.creato => 'CREATO',
        AvvisoStato.presoInCarico => 'PRESO_IN_CARICO',
        AvvisoStato.inLavorazione => 'IN_LAVORAZIONE',
        AvvisoStato.sospeso => 'SOSPESO',
        AvvisoStato.chiuso => 'CHIUSO',
      };

  bool get isClosed => this == AvvisoStato.chiuso;

  /// Tenta di mappare uno stato libero proveniente da SAP nell'enum.
  static AvvisoStato fromRaw(String? raw) {
    final r = (raw ?? '').toLowerCase();
    if (r.contains('chius') || r.contains('completat')) {
      return AvvisoStato.chiuso;
    }
    if (r.contains('sospes')) return AvvisoStato.sospeso;
    if (r.contains('lavorazion') ||
        r.contains('corso') ||
        r.contains('inizia')) {
      return AvvisoStato.inLavorazione;
    }
    if (r.contains('carico') || r.contains('assegn')) {
      return AvvisoStato.presoInCarico;
    }
    return AvvisoStato.creato;
  }
}

/// Categoria di intervento (Pronto Intervento, spec).
enum CategoriaIntervento {
  guasto,
  installazione,
  manutenzione;

  String get label => switch (this) {
        CategoriaIntervento.guasto => 'Guasto',
        CategoriaIntervento.installazione => 'Installazione',
        CategoriaIntervento.manutenzione => 'Manutenzione',
      };

  IconData get icon => switch (this) {
        CategoriaIntervento.guasto => Icons.warning_amber_rounded,
        CategoriaIntervento.installazione => Icons.add_circle_outline,
        CategoriaIntervento.manutenzione => Icons.build_outlined,
      };
}

/// Canale di apertura dell'Avviso.
enum CanaleApertura {
  telefono,
  email,
  web;

  String get label => switch (this) {
        CanaleApertura.telefono => 'Telefono',
        CanaleApertura.email => 'Email',
        CanaleApertura.web => 'Web',
      };

  IconData get icon => switch (this) {
        CanaleApertura.telefono => Icons.phone_outlined,
        CanaleApertura.email => Icons.email_outlined,
        CanaleApertura.web => Icons.public_outlined,
      };
}

/// Tipo di servizio (Emergenza / Programmato).
enum TipoServizio {
  emergenza,
  programmato;

  String get label => switch (this) {
        TipoServizio.emergenza => 'Emergenza',
        TipoServizio.programmato => 'Programmato',
      };

  IconData get icon => switch (this) {
        TipoServizio.emergenza => Icons.priority_high_rounded,
        TipoServizio.programmato => Icons.event_outlined,
      };
}

/// Stato operativo del tecnico durante l'intervento.
enum StatoOperativo {
  inAttesa,
  inViaggio,
  sulPosto;

  String get label => switch (this) {
        StatoOperativo.inAttesa => 'In attesa',
        StatoOperativo.inViaggio => 'In viaggio',
        StatoOperativo.sulPosto => 'Sul posto',
      };

  IconData get icon => switch (this) {
        StatoOperativo.inAttesa => Icons.hourglass_bottom_rounded,
        StatoOperativo.inViaggio => Icons.directions_car_outlined,
        StatoOperativo.sulPosto => Icons.location_on_outlined,
      };

  Color get color => switch (this) {
        StatoOperativo.inAttesa => const Color(0xFF757575),
        StatoOperativo.inViaggio => const Color(0xFF1976D2),
        StatoOperativo.sulPosto => const Color(0xFF2E7D32),
      };
}

/// Fascia oraria intervento.
enum FasciaOraria {
  mattina,
  pomeriggio,
  sera;

  String get label => switch (this) {
        FasciaOraria.mattina => 'Mattina (08-13)',
        FasciaOraria.pomeriggio => 'Pomeriggio (14-18)',
        FasciaOraria.sera => 'Sera (18-22)',
      };
}

/// Stato dell'Equipment.
enum StatoEquipment {
  attivo,
  guasto,
  sospeso;

  String get label => switch (this) {
        StatoEquipment.attivo => 'Attivo',
        StatoEquipment.guasto => 'Guasto',
        StatoEquipment.sospeso => 'Sospeso',
      };

  Color get color => switch (this) {
        StatoEquipment.attivo => const Color(0xFF2E7D32),
        StatoEquipment.guasto => const Color(0xFFD32F2F),
        StatoEquipment.sospeso => const Color(0xFFFF9800),
      };

  IconData get icon => switch (this) {
        StatoEquipment.attivo => Icons.check_circle_outline,
        StatoEquipment.guasto => Icons.error_outline,
        StatoEquipment.sospeso => Icons.pause_circle_outline,
      };
}

/// Tipo di richiesta del Preventivo (spec RP).
enum TipoRichiestaPreventivo {
  nuovaInstallazione,
  sostituzione,
  adeguamento,
  manutenzioneStraordinaria;

  String get label => switch (this) {
        TipoRichiestaPreventivo.nuovaInstallazione => 'Nuova installazione',
        TipoRichiestaPreventivo.sostituzione => 'Sostituzione',
        TipoRichiestaPreventivo.adeguamento => 'Adeguamento',
        TipoRichiestaPreventivo.manutenzioneStraordinaria =>
          'Manutenzione straordinaria',
      };

  IconData get icon => switch (this) {
        TipoRichiestaPreventivo.nuovaInstallazione => Icons.add_circle_outline,
        TipoRichiestaPreventivo.sostituzione => Icons.swap_horiz_rounded,
        TipoRichiestaPreventivo.adeguamento => Icons.tune_rounded,
        TipoRichiestaPreventivo.manutenzioneStraordinaria =>
          Icons.build_outlined,
      };
}

/// Metodo di pagamento (spec §12).
enum MetodoPagamento {
  contanti,
  carta,
  bonifico,
  pos;

  String get label => switch (this) {
        MetodoPagamento.contanti => 'Contanti',
        MetodoPagamento.carta => 'Carta',
        MetodoPagamento.bonifico => 'Bonifico',
        MetodoPagamento.pos => 'POS',
      };
}

/// Esito di un pagamento (spec §12).
enum EsitoPagamento {
  riuscito,
  fallito,
  parziale,
  inAttesa;

  String get label => switch (this) {
        EsitoPagamento.riuscito => 'Riuscito',
        EsitoPagamento.fallito => 'Fallito',
        EsitoPagamento.parziale => 'Parziale',
        EsitoPagamento.inAttesa => 'In attesa',
      };
}
