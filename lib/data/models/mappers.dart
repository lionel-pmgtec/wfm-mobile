// Mapper DTO <-> Entita. La nomenclatura JSON segue il contratto REST del
// middleware Spring Boot (com.wfm.middleware.dto.Dto).
//
// Usati da HttpRemoteDataSource quando AppConfig.useMockData == false.

import '../../domain/entities/entities.dart';

DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());
String? _s(dynamic v) => v == null ? null : v.toString();
num? _n(dynamic v) => v as num?;
bool? _b(dynamic v) => v as bool?;

// ─── ADDRESS ───────────────────────────────────────────────────────────────

Address addressFromJson(Map<String, dynamic>? j) {
  if (j == null) return const Address();
  return Address(
    street: j['street'] ?? '',
    streetNumber: j['streetNumber']?.toString() ?? '',
    cap: j['cap'] ?? '',
    localita: j['localita'] ?? '',
    city: j['city'] ?? '',
    provincia: j['provincia'] ?? '',
    regione: j['regione'] ?? '',
    nazione: j['nazione'] ?? 'IT',
    additionalInfo: j['additionalInfo'] ?? '',
    latitude: (j['latitude'] as num?)?.toDouble(),
    longitude: (j['longitude'] as num?)?.toDouble(),
  );
}

Map<String, dynamic> addressToJson(Address a) => {
      'street': a.street,
      'streetNumber': a.streetNumber,
      'cap': a.cap,
      'localita': a.localita,
      'city': a.city,
      'provincia': a.provincia,
      'regione': a.regione,
      'nazione': a.nazione,
      'additionalInfo': a.additionalInfo,
      'latitude': a.latitude,
      'longitude': a.longitude,
    };

// ─── CUSTOMER ──────────────────────────────────────────────────────────────

Customer customerFromJson(Map<String, dynamic>? j) {
  if (j == null) return const Customer();
  return Customer(
    objectCode: _s(j['objectCode']),
    nome: _s(j['nome']) ?? _s(j['firstName']),
    cognome: _s(j['cognome']) ?? _s(j['lastName']),
    ragioneSociale: _s(j['ragioneSociale']),
    codiceFiscale: _s(j['codiceFiscale']),
    partitaIva: _s(j['partitaIva']),
    telefono: _s(j['telefono']) ?? _s(j['phone']),
    email: _s(j['email']),
    codBp: _s(j['codBp']),
    codCli: _s(j['codCli']),
    familyNucleus: (j['familyNucleus'] as num?)?.toInt(),
  );
}

Map<String, dynamic> customerToJson(Customer c) => {
      'objectCode': c.objectCode,
      'nome': c.nome,
      'cognome': c.cognome,
      'ragioneSociale': c.ragioneSociale,
      'codiceFiscale': c.codiceFiscale,
      'partitaIva': c.partitaIva,
      'telefono': c.telefono,
      'email': c.email,
      'codBp': c.codBp,
      'codCli': c.codCli,
      'familyNucleus': c.familyNucleus,
    };

// ─── METER ─────────────────────────────────────────────────────────────────

Meter? meterFromJson(Map<String, dynamic>? j) {
  if (j == null) return null;
  return Meter(
    matricola: j['matricola']?.toString() ?? '',
    brand: j['brand'] ?? '',
    model: j['model'] ?? '',
    caliber: j['caliber']?.toString() ?? '',
    materialCode: j['materialCode']?.toString() ?? '',
    location: j['location'] ?? '',
    sector: j['sector'] ?? '',
    lastReading: j['lastReading'] as num?,
    lastReadingDate: _date(j['lastReadingDate']),
  );
}

// ─── OPERATION / MATERIAL ─────────────────────────────────────────────────

Operation operationFromJson(Map<String, dynamic> j) => Operation(
      id: j['id']?.toString() ?? '',
      number: j['number']?.toString() ?? '',
      codice: j['codice']?.toString() ?? '',
      testoBreve: j['testoBreve'] ?? '',
      cid: j['cid'] ?? '',
      description: j['description'] ?? '',
      workCenter: j['workCenter'] ?? '',
      dataInizioPrevista: _date(j['dataInizioPrevista']),
      dataFinePrevista: _date(j['dataFinePrevista']),
      plannedHours: _n(j['plannedHours']),
      durataEffettiva: _n(j['durataEffettiva']),
      actualHours: _n(j['actualHours']),
      tempoLavoroFase: _s(j['tempoLavoroFase']),
      completed: j['completed'] == true,
    );

Map<String, dynamic> operationToJson(Operation o) => {
      'id': o.id,
      'number': o.number,
      'codice': o.codice,
      'testoBreve': o.testoBreve,
      'cid': o.cid,
      'description': o.description,
      'workCenter': o.workCenter,
      'dataInizioPrevista': o.dataInizioPrevista?.toIso8601String(),
      'dataFinePrevista': o.dataFinePrevista?.toIso8601String(),
      'plannedHours': o.plannedHours,
      'durataEffettiva': o.durataEffettiva,
      'actualHours': o.actualHours,
      'tempoLavoroFase': o.tempoLavoroFase,
      'completed': o.completed,
    };

MaterialUsage materialUsageFromJson(Map<String, dynamic> j) => MaterialUsage(
      materialCode: j['materialCode']?.toString() ?? '',
      description: j['description'] ?? '',
      plannedQuantity: (j['plannedQuantity'] as num?) ?? 0,
      usedQuantity: (j['usedQuantity'] as num?) ?? 0,
      unitOfMeasure: j['unitOfMeasure'] ?? 'PZ',
      warehouseCode: j['warehouseCode'] ?? '',
    );

Map<String, dynamic> materialUsageToJson(MaterialUsage m) => {
      'materialCode': m.materialCode,
      'description': m.description,
      'plannedQuantity': m.plannedQuantity,
      'usedQuantity': m.usedQuantity,
      'unitOfMeasure': m.unitOfMeasure,
      'warehouseCode': m.warehouseCode,
    };

// ─── WORK ORDER ───────────────────────────────────────────────────────────

WorkOrder workOrderFromJson(Map<String, dynamic> j) {
  return WorkOrder(
    externalCode: j['externalCode']?.toString() ?? '',
    notificationNumberSap: _s(j['notificationNumberSAP']),
    avvisoOrigine: _s(j['avvisoOrigine']),
    woType: j['woType'] ?? '',
    woTypeDescription: j['woTypeDescription'] ?? '',
    tam: j['tam'] ?? '',
    subTam: j['subTam'] ?? '',
    tipoAttivitaCodice: _s(j['tipoAttivitaCodice']),
    tipoAttivitaNome: _s(j['tipoAttivitaNome']),
    status: WorkOrderStatus.fromSap(j['status']?.toString()),
    priorita: j['priorita'] ?? '',
    creatoDa: _s(j['creatoDa']),
    createdAt: _date(j['createdAt']),
    centroPianificazione: j['centroPianificazione'] ?? '',
    centroLavoro: j['centroLavoro'] ?? '',
    appointmentDate: _date(j['appointmentDate']),
    appointmentStartTime: j['appointmentStartTime'] ?? '',
    appointmentEndTime: j['appointmentEndTime'] ?? '',
    address: addressFromJson(j['address'] as Map<String, dynamic>?),
    indirizzoOggetto: j['indirizzoOggetto'] == null
        ? null
        : addressFromJson(j['indirizzoOggetto'] as Map<String, dynamic>),
    indirizzoIntervento: j['indirizzoIntervento'] == null
        ? null
        : addressFromJson(j['indirizzoIntervento'] as Map<String, dynamic>),
    customer: customerFromJson(j['customer'] as Map<String, dynamic>?),
    codiceCliente: _s(j['codiceCliente']),
    referente: _s(j['referente']),
    telefonoCliente: _s(j['telefonoCliente']),
    sedeTecnica: j['sedeTecnica'] ?? '',
    equipment: j['equipment'] ?? '',
    matricola: _s(j['matricola']),
    ubicazione: j['ubicazione'] ?? '',
    aggUbicazione: j['aggUbicazione'] ?? '',
    impianto: j['impianto'] ?? '',
    meter: meterFromJson(j['meter'] as Map<String, dynamic>?),
    operations: (j['operations'] as List?)
            ?.map((e) => operationFromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
    plannedMaterials: (j['plannedMaterials'] as List?)
            ?.map((e) => materialUsageFromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
    cidAssegnato: _s(j['technicianCID']),
    squadra: j['squadra'] ?? '',
    responsabile: _s(j['responsabile']),
    fornitoreEsterno: _s(j['fornitoreEsterno']),
    reperibilita: _b(j['reperibilita']) ?? false,
    contratto: _s(j['contratto']),
    impiantoDis: _s(j['impiantoDis']),
    ultimoCicloManutenzione: _s(j['ultimoCicloManutenzione']),
    postManut: _s(j['postManut']),
    dataEsec: _date(j['dataEsec']),
    accountingSector: j['accountingSector'] ?? '',
    notes: j['notes'] ?? '',
  );
}

Map<String, dynamic> workOrderToJson(WorkOrder o) => {
      'externalCode': o.externalCode,
      'notificationNumberSAP': o.notificationNumberSap,
      'avvisoOrigine': o.avvisoOrigine,
      'woType': o.woType,
      'woTypeDescription': o.woTypeDescription,
      'tam': o.tam,
      'subTam': o.subTam,
      'tipoAttivitaCodice': o.tipoAttivitaCodice,
      'tipoAttivitaNome': o.tipoAttivitaNome,
      'status': o.status.sapCode,
      'priorita': o.priorita,
      'creatoDa': o.creatoDa,
      'createdAt': o.createdAt?.toIso8601String(),
      'centroPianificazione': o.centroPianificazione,
      'centroLavoro': o.centroLavoro,
      'appointmentDate': o.appointmentDate?.toIso8601String(),
      'appointmentStartTime': o.appointmentStartTime,
      'appointmentEndTime': o.appointmentEndTime,
      'address': addressToJson(o.address),
      'indirizzoOggetto':
          o.indirizzoOggetto == null ? null : addressToJson(o.indirizzoOggetto!),
      'indirizzoIntervento': o.indirizzoIntervento == null
          ? null
          : addressToJson(o.indirizzoIntervento!),
      'customer': customerToJson(o.customer),
      'codiceCliente': o.codiceCliente,
      'referente': o.referente,
      'telefonoCliente': o.telefonoCliente,
      'sedeTecnica': o.sedeTecnica,
      'equipment': o.equipment,
      'matricola': o.matricola,
      'ubicazione': o.ubicazione,
      'aggUbicazione': o.aggUbicazione,
      'impianto': o.impianto,
      'operations': o.operations.map(operationToJson).toList(),
      'plannedMaterials': o.plannedMaterials.map(materialUsageToJson).toList(),
      'technicianCID': o.cidAssegnato,
      'squadra': o.squadra,
      'responsabile': o.responsabile,
      'fornitoreEsterno': o.fornitoreEsterno,
      'reperibilita': o.reperibilita,
      'contratto': o.contratto,
      'impiantoDis': o.impiantoDis,
      'ultimoCicloManutenzione': o.ultimoCicloManutenzione,
      'postManut': o.postManut,
      'dataEsec': o.dataEsec?.toIso8601String(),
      'accountingSector': o.accountingSector,
      'notes': o.notes,
    };

// ─── AVVISO ──────────────────────────────────────────────────────────────

NotificationAvviso avvisoFromJson(Map<String, dynamic> j) => NotificationAvviso(
      numeroAvviso: j['numeroAvviso']?.toString() ?? j['qmnum']?.toString() ?? '',
      descrizione: j['descrizione'] ?? '',
      descrizioneBreve: _s(j['descrizioneBreve']),
      descrizioneEstesa: _s(j['descrizioneEstesa']),
      tipo: j['tipo'] ?? '',
      cid: _s(j['cid']),
      categoriaIntervento: _categoria(j['categoriaIntervento']),
      canaleApertura: _canale(j['canaleApertura']),
      tipoServizio: _tipoServizio(j['tipoServizio']),
      codiceGuasto: _s(j['codiceGuasto']),
      codiceCausa: _s(j['codiceCausa']),
      noteOperatore: _s(j['noteOperatore']),
      priorita: j['priorita'] ?? '',
      stato: j['stato'] ?? 'Creato',
      statoEnum: AvvisoStato.fromRaw(j['stato']?.toString()),
      contratto: _s(j['contratto']),
      codiceContratto: _s(j['codiceContratto']),
      contrattoAttivo: _b(j['contrattoAttivo']) ?? false,
      sedeTecnica: _s(j['sedeTecnica']),
      ubicazioneTecnica: _s(j['ubicazioneTecnica']),
      equipment: _s(j['equipment']),
      matricola: _s(j['matricola']),
      statoEquipment: _statoEquipment(j['statoEquipment']),
      categoriaTecnica: _s(j['categoriaTecnica']),
      tipoImpianto: _s(j['tipoImpianto']),
      impianto: _s(j['impianto']),
      puntoMisura: _s(j['puntoMisura']),
      centroLavoro: _s(j['centroLavoro']),
      assegnatoA: _s(j['assegnatoA']),
      squadra: _s(j['squadra']),
      cidAssegnato: _s(j['cidAssegnato']) ?? _s(j['technicianCID']),
      autore: _s(j['autore']),
      creatoDa: _s(j['creatoDa']),
      codiceCliente: _s(j['codiceCliente']),
      referente: _s(j['referente']),
      cellulare: _s(j['cellulare']),
      codiceFiscaleCliente: _s(j['codiceFiscaleCliente']),
      areaTecnica: _s(j['areaTecnica']),
      noteAccesso: _s(j['noteAccesso']),
      gestionePermessi: _b(j['gestionePermessi']) ?? false,
      lavoriACaricoCliente: _b(j['lavoriACaricoCliente']) ?? false,
      reperibilita: _b(j['reperibilita']) ?? false,
      slaTarget: _s(j['slaTarget']),
      tempoRispostaAtteso: _s(j['tempoRispostaAtteso']),
      urgente: _b(j['urgente']) ?? false,
      motivoUrgenza: _s(j['motivoUrgenza']),
      dataApertura: _date(j['dataApertura']),
      oraApertura: _s(j['oraApertura']),
      dataPianificata: _date(j['dataPianificata']),
      dataInterventoRichiesta: _date(j['dataInterventoRichiesta']),
      dataInizioGuasto: _date(j['dataInizioGuasto']),
      dataFineGuasto: _date(j['dataFineGuasto']),
      dataChiusura: _date(j['dataChiusura']),
      fasciaOraria: _fasciaOraria(j['fasciaOraria']),
      dataPresaInCarico: _date(j['dataPresaInCarico']),
      dataInvioTecnico: _date(j['dataInvioTecnico']),
      dataArrivoPrevista: _date(j['dataArrivoPrevista']),
      statoOperativo: _statoOperativo(j['statoOperativo']),
      dataSegnalazione: _date(j['dataSegnalazione']),
      oraSegnalazione: _s(j['oraSegnalazione']),
      address: addressFromJson(j['address'] as Map<String, dynamic>?),
      indirizzoAvvisoTelefono: _s(j['indirizzoAvvisoTelefono']),
      indirizzoOggetto: j['indirizzoOggetto'] == null
          ? null
          : addressFromJson(j['indirizzoOggetto'] as Map<String, dynamic>),
      indirizzoLavoro: j['indirizzoLavoro'] == null
          ? null
          : addressFromJson(j['indirizzoLavoro'] as Map<String, dynamic>),
      customer: customerFromJson(j['customer'] as Map<String, dynamic>?),
      ordineDiLavoro: _s(j['ordineDiLavoro']),
      statoOdl: _s(j['statoOdl']),
      interruzioneFornitura: _b(j['interruzioneFornitura']) ?? false,
    );

Map<String, dynamic> avvisoToJson(NotificationAvviso a) => {
      'numeroAvviso': a.numeroAvviso,
      'descrizione': a.descrizione,
      'descrizioneBreve': a.descrizioneBreve,
      'descrizioneEstesa': a.descrizioneEstesa,
      'tipo': a.tipo,
      'cid': a.cid,
      'categoriaIntervento': a.categoriaIntervento?.name.toUpperCase(),
      'canaleApertura': a.canaleApertura?.name.toUpperCase(),
      'tipoServizio': a.tipoServizio?.name.toUpperCase(),
      'codiceGuasto': a.codiceGuasto,
      'codiceCausa': a.codiceCausa,
      'noteOperatore': a.noteOperatore,
      'priorita': a.priorita,
      'stato': a.stato,
      'contratto': a.contratto,
      'codiceContratto': a.codiceContratto,
      'contrattoAttivo': a.contrattoAttivo,
      'sedeTecnica': a.sedeTecnica,
      'ubicazioneTecnica': a.ubicazioneTecnica,
      'equipment': a.equipment,
      'matricola': a.matricola,
      'statoEquipment': a.statoEquipment?.name.toUpperCase(),
      'categoriaTecnica': a.categoriaTecnica,
      'tipoImpianto': a.tipoImpianto,
      'impianto': a.impianto,
      'puntoMisura': a.puntoMisura,
      'centroLavoro': a.centroLavoro,
      'assegnatoA': a.assegnatoA,
      'squadra': a.squadra,
      'cidAssegnato': a.cidAssegnato,
      'autore': a.autore,
      'creatoDa': a.creatoDa,
      'codiceCliente': a.codiceCliente,
      'referente': a.referente,
      'cellulare': a.cellulare,
      'codiceFiscaleCliente': a.codiceFiscaleCliente,
      'areaTecnica': a.areaTecnica,
      'noteAccesso': a.noteAccesso,
      'gestionePermessi': a.gestionePermessi,
      'lavoriACaricoCliente': a.lavoriACaricoCliente,
      'reperibilita': a.reperibilita,
      'slaTarget': a.slaTarget,
      'tempoRispostaAtteso': a.tempoRispostaAtteso,
      'urgente': a.urgente,
      'motivoUrgenza': a.motivoUrgenza,
      'dataApertura': a.dataApertura?.toIso8601String(),
      'oraApertura': a.oraApertura,
      'dataPianificata': a.dataPianificata?.toIso8601String(),
      'dataInterventoRichiesta': a.dataInterventoRichiesta?.toIso8601String(),
      'dataInizioGuasto': a.dataInizioGuasto?.toIso8601String(),
      'dataFineGuasto': a.dataFineGuasto?.toIso8601String(),
      'dataChiusura': a.dataChiusura?.toIso8601String(),
      'fasciaOraria': a.fasciaOraria?.name.toUpperCase(),
      'dataPresaInCarico': a.dataPresaInCarico?.toIso8601String(),
      'dataInvioTecnico': a.dataInvioTecnico?.toIso8601String(),
      'dataArrivoPrevista': a.dataArrivoPrevista?.toIso8601String(),
      'statoOperativo': a.statoOperativo?.name.toUpperCase(),
      'dataSegnalazione': a.dataSegnalazione?.toIso8601String(),
      'oraSegnalazione': a.oraSegnalazione,
      'address': addressToJson(a.address),
      'indirizzoAvvisoTelefono': a.indirizzoAvvisoTelefono,
      'indirizzoOggetto':
          a.indirizzoOggetto == null ? null : addressToJson(a.indirizzoOggetto!),
      'indirizzoLavoro':
          a.indirizzoLavoro == null ? null : addressToJson(a.indirizzoLavoro!),
      'customer': customerToJson(a.customer),
      'ordineDiLavoro': a.ordineDiLavoro,
      'statoOdl': a.statoOdl,
      'technicianCID': a.cidAssegnato,
      'interruzioneFornitura': a.interruzioneFornitura,
    };

// ─── Enum mapping helpers ──────────────────────────────────────────────────

CategoriaIntervento? _categoria(dynamic v) {
  final s = v?.toString().toUpperCase();
  if (s == null) return null;
  switch (s) {
    case 'GUASTO':
      return CategoriaIntervento.guasto;
    case 'INSTALLAZIONE':
      return CategoriaIntervento.installazione;
    case 'MANUTENZIONE':
      return CategoriaIntervento.manutenzione;
    default:
      return null;
  }
}

CanaleApertura? _canale(dynamic v) {
  final s = v?.toString().toUpperCase();
  if (s == null) return null;
  switch (s) {
    case 'TELEFONO':
      return CanaleApertura.telefono;
    case 'EMAIL':
      return CanaleApertura.email;
    case 'WEB':
      return CanaleApertura.web;
    default:
      return null;
  }
}

TipoServizio? _tipoServizio(dynamic v) {
  final s = v?.toString().toUpperCase();
  if (s == null) return null;
  switch (s) {
    case 'EMERGENZA':
      return TipoServizio.emergenza;
    case 'PROGRAMMATO':
      return TipoServizio.programmato;
    default:
      return null;
  }
}

StatoOperativo? _statoOperativo(dynamic v) {
  final s = v?.toString().toUpperCase();
  if (s == null) return null;
  switch (s) {
    case 'IN_ATTESA':
    case 'INATTESA':
      return StatoOperativo.inAttesa;
    case 'IN_VIAGGIO':
    case 'INVIAGGIO':
      return StatoOperativo.inViaggio;
    case 'SUL_POSTO':
    case 'SULPOSTO':
      return StatoOperativo.sulPosto;
    default:
      return null;
  }
}

FasciaOraria? _fasciaOraria(dynamic v) {
  final s = v?.toString().toUpperCase();
  if (s == null) return null;
  switch (s) {
    case 'MATTINA':
      return FasciaOraria.mattina;
    case 'POMERIGGIO':
      return FasciaOraria.pomeriggio;
    case 'SERA':
      return FasciaOraria.sera;
    default:
      return null;
  }
}

StatoEquipment? _statoEquipment(dynamic v) {
  final s = v?.toString().toUpperCase();
  if (s == null) return null;
  switch (s) {
    case 'ATTIVO':
      return StatoEquipment.attivo;
    case 'GUASTO':
      return StatoEquipment.guasto;
    case 'SOSPESO':
      return StatoEquipment.sospeso;
    default:
      return null;
  }
}

// ─── ESITO (solo serializzazione in uscita) ─────────────────────────────────

Map<String, dynamic> esitoToJson(Esito e) => {
      'workOrderCode': e.workOrderCode,
      'technicianCID': e.technicianCid,
      'startDateTime': e.startDateTime.toIso8601String(),
      'endDateTime': e.endDateTime?.toIso8601String(),
      'result': e.result?.sapCode,
      'causeCode': e.causeCode,
      'solutionCode': e.solutionCode,
      'notes': e.notes,
      'meterReadings': e.meterReadings
          .map((r) => {
                'matricola': r.matricola,
                'readingValue': r.readingValue,
                'readingDateTime': r.readingDateTime.toIso8601String(),
              })
          .toList(),
      'materialsUsed': const [],
      'hoursWorked': e.hoursWorked
          .map((h) => {'technicianCID': h.technicianCid, 'hours': h.hours})
          .toList(),
      'geolocation': e.geolocation == null
          ? null
          : {
              'latitude': e.geolocation!.latitude,
              'longitude': e.geolocation!.longitude,
              'accuracy': e.geolocation!.accuracy,
            },
    };

// ─── ANAGRAFICHE ────────────────────────────────────────────────────────────

MaterialItem materialItemFromJson(Map<String, dynamic> j) => MaterialItem(
      materialCode: j['materialCode']?.toString() ?? '',
      description: j['description'] ?? '',
      unitOfMeasure: j['unitOfMeasure'] ?? 'PZ',
      barcode: _s(j['barcode']),
      defaultWarehouseCode: j['defaultWarehouseCode'] ?? 'W01',
      stockDisponibile: _n(j['stockDisponibile']) ?? 0,
    );

Warehouse warehouseFromJson(Map<String, dynamic> j) =>
    Warehouse(code: j['code']?.toString() ?? '', name: j['name'] ?? '');

CodeLabel codeLabelFromJson(Map<String, dynamic> j) =>
    CodeLabel(j['code']?.toString() ?? '', j['label'] ?? '');
