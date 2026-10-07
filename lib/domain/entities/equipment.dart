// Equipment SAP PM/IS-U — (Dettaglio Equipment, Sostituzione Barcode).

import 'meter.dart';
import 'value_objects.dart';

class Equipment {
  final String matricola; // numero di serie
  final String barcode;
  final String produttore;
  final String modello;
  final String localita;
  final String comune;
  final String sedeTecnica;
  final DateTime? dataInstallazione;
  final String stato; // ATTIVO, RIMOSSO, GUASTO...
  // Dati ricchi della "casetta" (GET /anagrafica/equipment): servono a
  // precompilare la creazione della SOST senza far ridigitare il tecnico.
  final String equipment; // codice equipment SAP
  final String oggettoAllacciamento; // punto di connessione
  final String accountingSector; // settore contabile (POT…)
  final String fonteExternalCode; // OdL da cui vengono questi dati
  final Meter? meter; // contatore esistente (da sostituire)
  final Address? address; // indirizzo del punto di fornitura
  final Customer? customer; // intestatario

  const Equipment({
    required this.matricola,
    this.barcode = '',
    this.produttore = '',
    this.modello = '',
    this.localita = '',
    this.comune = '',
    this.sedeTecnica = '',
    this.dataInstallazione,
    this.stato = '',
    this.equipment = '',
    this.oggettoAllacciamento = '',
    this.accountingSector = '',
    this.fonteExternalCode = '',
    this.meter,
    this.address,
    this.customer,
  });

  String get displayName =>
      [produttore, modello].where((e) => e.isNotEmpty).join(' ');
}

/// Veicolo della squadra (Gestione Targhe).
class Vehicle {
  final String id;
  final String targa;
  final String tipo;
  final String descrizione;
  final String assegnatoA; // CID

  const Vehicle({
    required this.id,
    required this.targa,
    this.tipo = '',
    this.descrizione = '',
    this.assegnatoA = '',
  });
}

/// Membro della squadra.
class TeamMember {
  final String cid;
  final String nome;
  final String cognome;
  final String ruolo;

  const TeamMember({
    required this.cid,
    this.nome = '',
    this.cognome = '',
    this.ruolo = '',
  });

  String get fullName => [nome, cognome].where((e) => e.isNotEmpty).join(' ');
}

/// Slot di magazzino dell'equipaggio.
class WarehouseSlot {
  final String materialCode;
  final String description;
  final num quantity;
  final String unitOfMeasure;

  const WarehouseSlot({
    required this.materialCode,
    this.description = '',
    this.quantity = 0,
    this.unitOfMeasure = 'PZ',
  });
}

/// Template di OdL riutilizzabile.
class WorkOrderTemplate {
  final String id;
  final String name;
  final String woType;
  final String description;
  final String defaultActivity;

  const WorkOrderTemplate({
    required this.id,
    required this.name,
    required this.woType,
    this.description = '',
    this.defaultActivity = '',
  });
}
