
// Usati da HttpRemoteDataSource per (de)serializzare i dati del Cruscotto.

import '../../domain/entities/entities.dart';

/// Data dal JSON; una data SAP "vuota" (0000-00-00, 00000000) non è una data:
/// diventerebbe l'anno 0001 e comparirebbe come "30/11/0001". Sotto il 1900 si
/// scarta.
DateTime? _date(dynamic v) {
  if (v == null) return null;
  final d = DateTime.tryParse(v.toString());
  return d == null || d.year < 1900 ? null : d;
}
String? _s(dynamic v) => v == null ? null : v.toString();
num? _n(dynamic v) => v as num?;
bool? _b(dynamic v) => v as bool?;

/// Valore annidato (`testata.date.fineSchedulato`); null se un livello manca.
dynamic _dentro(dynamic v, List<String> percorso) {
  for (final chiave in percorso) {
    if (v is! Map) return null;
    v = v[chiave];
  }
  return v;
}

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
    ubicazione: j['ubicazione']?.toString() ?? '',
    ubicazioneDesc: j['ubicazioneDesc']?.toString() ?? '',
    posizioneInBatteria: j['posizioneInBatteria']?.toString() ?? '',
    oggettoAllacciamento: j['oggettoAllacciamento']?.toString() ?? '',
    lastReading: j['lastReading'] as num?,
    lastReadingDate: _date(j['lastReadingDate']),
    previousReading: j['previousReading'] as num?,
    previousReadingDate: _date(j['previousReadingDate']),
    previousReadingTime: _s(j['previousReadingTime']),
    previousReadingStatus: _s(j['previousReadingStatus']),
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

/// Appuntamento FISSATO CON IL CLIENTE di un ordine: data, ora e ora limite.
///
/// Il backend (toMobile.ts) calcola `appointmentDate` a cascata: prima il
/// giorno in cui il cruscotto ha pianificato il lavoro (che, se non indicato,
/// diventa OGGI), poi l'appuntamento SAP. Quindi `appointmentDate` non dice se
/// il cliente ha un appuntamento: un ordine senza appuntamento arriva lo stesso
/// con una data, e un ordine con appuntamento il 7 ottobre arriva col giorno
/// della pianificazione. L'appuntamento vero sta in `datiSap.APPUNTAMENTO`
/// (assente se il cliente non ne ha uno): è quello che si mostra.
///
/// Senza `datiSap` (copia salvata sul tablet) i valori sono già quelli veri.
({DateTime? data, String ora, String oraLimite}) _appuntamentoCliente(
    Map<String, dynamic> j) {
  final sap = j['datiSap'];
  if (sap is! Map) {
    return (
      data: _date(j['appointmentDate']),
      ora: '${j['appointmentStartTime'] ?? ''}',
      oraLimite: '${j['appointmentEndTime'] ?? ''}',
    );
  }
  final a = sap['APPUNTAMENTO'];
  if (a is! Map) return (data: null, ora: '', oraLimite: '');
  return (
    data: _dataSap(a['FISSATO_DATA']),
    ora: _oraSap(a['FISSATO_ORA']),
    oraLimite: _oraSap(a['FISSATO_ORA_LIMITE']),
  );
}

/// "2026-10-07" oppure "20261007" (formati SAP) -> data; vuoto -> null.
DateTime? _dataSap(dynamic v) {
  final s = '${v ?? ''}'.trim();
  if (s.isEmpty) return null;
  final cifre = s.replaceAll(RegExp(r'\D'), '');
  if (cifre.length >= 8) {
    final d = DateTime.tryParse(
        '${cifre.substring(0, 4)}-${cifre.substring(4, 6)}-${cifre.substring(6, 8)}');
    return d == null || d.year < 1900 ? null : d; // 00000000 = vuota
  }
  return _date(s);
}

/// "10:30:00" oppure "103000" -> "10:30"; vuoto -> "".
String _oraSap(dynamic v) {
  final s = '${v ?? ''}'.trim();
  if (s.isEmpty) return '';
  final cifre = s.replaceAll(RegExp(r'\D'), '');
  if (cifre.length < 4 || RegExp(r'^0+$').hasMatch(cifre)) return ''; // 000000 = vuota
  return '${cifre.substring(0, 2)}:${cifre.substring(2, 4)}';
}

List<Operation> _operazioniOStandard(List<Operation>? dalBackend) =>
    dalBackend == null || dalBackend.isEmpty ? kOperazioniStandard : dalBackend;

/// Cliente e nome dell'indirizzo di un ordine.
///
/// Il backend (toMobile.ts) mette in `customer.nome/cognome` il CLIENTE di SAP
/// e, se manca, il nome dell'indirizzo (ADRC-NAME1/NAME2): così un condominio
/// compare come "cliente" e come "referente". Il record SAP è in `datiSap`:
/// da lì si separano le due cose. Il cliente ha nome solo se SAP manda
/// CLIENTE.NOME/COGNOME; il nome dell'indirizzo (di lavoro, altrimenti
/// dell'oggetto) è il nome del battimento.
///
/// Senza `datiSap` (copia salvata sul tablet) i valori sono già separati.
({Customer cliente, String? nomeIndirizzo}) _clienteENomeIndirizzo(
    Map<String, dynamic> j) {
  final base = customerFromJson(j['customer'] as Map<String, dynamic>?);
  final sap = j['datiSap'];
  if (sap is! Map) return (cliente: base, nomeIndirizzo: _s(j['nomeIndirizzo']));

  String t(dynamic v) => '${v ?? ''}'.trim();
  String? vuoto(String s) => s.isEmpty ? null : s;
  final c = sap['CLIENTE'];
  final cliente = base.conNome(
    vuoto(t(c is Map ? c['NOME'] : null)),
    vuoto(t(c is Map ? c['COGNOME'] : null)),
  );
  final ind = sap['INDIRIZZO_LAVORO'] is Map
      ? sap['INDIRIZZO_LAVORO'] as Map
      : (sap['INDIRIZZO'] is Map ? sap['INDIRIZZO'] as Map : null);
  final nome = [t(ind?['NOME']), t(ind?['NOME2'])]
      .where((e) => e.isNotEmpty)
      .join(' ');
  return (cliente: cliente, nomeIndirizzo: vuoto(nome));
}

WorkOrder workOrderFromJson(Map<String, dynamic> j) {
  final appuntamento = _appuntamentoCliente(j);
  final cn = _clienteENomeIndirizzo(j);
  return WorkOrder(
    externalCode: j['externalCode']?.toString() ?? '',
    notificationNumberSap: _s(j['notificationNumberSAP']),
    avvisoOrigine: _s(j['avvisoOrigine']),
    // Ordine d'origine: consumato se il backend lo fornisce, altrimenti null.
    // Il backend usa `ordinePrecedente` (retro-compat: legge anche il vecchio nome).
    ordineOrigine: _s(j['ordinePrecedente']) ?? _s(j['ordineOrigine']),
    woType: j['woType'] ?? '',
    woTypeDescription: j['woTypeDescription'] ?? '',
    tam: j['tam'] ?? '',
    subTam: j['subTam'] ?? '',
    tipoAttivitaCodice: _s(j['tipoAttivitaCodice']),
    tipoAttivitaNome: _s(j['tipoAttivitaNome']),
    status: WorkOrderStatus.fromSap(j['status']?.toString()),
    statoSap: _s(j['statoSap']),
    // `prioritaDesc` = descrizione salvata nell'outbox locale (dove `priorita`
    // porta il codice inviato al backend); dal backend arriva solo `priorita`
    // (già descrizione).
    priorita: j['prioritaDesc'] ?? j['priorita'] ?? '',
    prioritaCodice: _s(j['prioritaCodice']),
    gruppoCicli: _s(j['gruppoCicli']),
    inviatoSap: j['inviatoSap'] == true,
    creatoDa: _s(j['creatoDa']),
    createdAt: _date(j['createdAt']),
    centroPianificazione: j['centroPianificazione'] ?? '',
    centroLavoro: j['centroLavoro'] ?? '',
    appointmentDate: appuntamento.data,
    appointmentStartTime: appuntamento.ora,
    appointmentEndTime: appuntamento.oraLimite,
    address: addressFromJson(j['address'] as Map<String, dynamic>?),
    indirizzoOggetto: j['indirizzoOggetto'] == null
        ? null
        : addressFromJson(j['indirizzoOggetto'] as Map<String, dynamic>),
    indirizzoIntervento: j['indirizzoIntervento'] == null
        ? null
        : addressFromJson(j['indirizzoIntervento'] as Map<String, dynamic>),
    customer: cn.cliente,
    codiceCliente: _s(j['codiceCliente']),
    // Il referente del backend è lo stesso nome del cliente o dell'indirizzo:
    // senza una persona diversa non c'è un referente.
    referente: referenteDistinto(
        referenteDistinto(_s(j['referente']), cn.nomeIndirizzo ?? ''),
        cn.cliente.fullName),
    nomeIndirizzo: cn.nomeIndirizzo,
    telefonoCliente: _s(j['telefonoCliente']),
    sedeTecnica: j['sedeTecnica'] ?? '',
    equipment: j['equipment'] ?? '',
    matricola: _s(j['matricola']),
    ubicazione: j['ubicazione'] ?? '',
    aggUbicazione: j['aggUbicazione'] ?? '',
    impianto: j['impianto'] ?? '',
    meter: meterFromJson(j['meter'] as Map<String, dynamic>?),
    operations: _operazioniOStandard((j['operations'] as List?)
            ?.map((e) => operationFromJson(e as Map<String, dynamic>))
            .toList()),
    plannedMaterials: (j['plannedMaterials'] as List?)
            ?.map((e) => materialUsageFromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
    cidAssegnato: _s(j['technicianCID']),
    assegnaA: _s(j['assegnaA']),
    squadra: j['squadra'] ?? '',
    responsabile: _s(j['responsabile']),
    fornitoreEsterno: _s(j['fornitoreEsterno']),
    reperibilita: _b(j['reperibilita']) ?? false,
    contratto: _s(j['contratto']),
    impiantoDis: _s(j['impiantoDis']),
    ultimoCicloManutenzione: _s(j['ultimoCicloManutenzione']),
    postManut: _s(j['postManut']),
    // Il backend manda il DATA_FINE di SAP (AFKO-GLTRP) come `dataEsec`. La
    // "fine prevista" vera è la fine schedulata (AFKO-GLTRS), che sta nella
    // testata: `null` finché il web service SAP non la manda.
    dataEsec: _date(j['dataEsec']),
    dataFine: _date(_dentro(j['testata'], ['date', 'fineSchedulato'])),
    // Inizio cardine: dal backend sta nella testata; nella copia salvata sul
    // tablet (senza testata) è `dataInizio`.
    dataInizio: _date(_dentro(j['testata'], ['date', 'inizioCardine'])) ??
        _date(j['dataInizio']),
    accountingSector: j['accountingSector'] ?? '',
    notes: j['notes'] ?? '',
    // Note SAP (sola lettura) e note aggiunte sul campo, separate dal backend.
    noteSap: j['noteSap']?.toString() ?? '',
    noteAggiunte: j['noteAggiunte']?.toString() ?? '',
  );
}

Map<String, dynamic> workOrderToJson(WorkOrder o) => {
      'externalCode': o.externalCode,
      'notificationNumberSAP': o.notificationNumberSap,
      'avvisoOrigine': o.avvisoOrigine,
      // Tracciabilità "creato da OdL #…": chiave attesa dal backend.
      'ordinePrecedente': o.ordineOrigine,
      'woType': o.woType,
      'woTypeDescription': o.woTypeDescription,
      'tam': o.tam,
      'subTam': o.subTam,
      'tipoAttivitaCodice': o.tipoAttivitaCodice,
      'tipoAttivitaNome': o.tipoAttivitaNome,
      'status': o.status.sapCode,
      'statoSap': o.statoSap,
      // Al backend va il CODICE ("1"); se non c'è (OdL nato altrove) resta la
      // descrizione, che il backend riconosce comunque.
      'priorita': (o.prioritaCodice ?? '').isNotEmpty ? o.prioritaCodice : o.priorita,
      'prioritaDesc': o.priorita,
      'prioritaCodice': o.prioritaCodice,
      'gruppoCicli': o.gruppoCicli,
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
      'nomeIndirizzo': o.nomeIndirizzo,
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
      // Solo per la copia locale (outbox): il backend non lo legge, assegna
      // sempre a chi crea. Il passaggio al collega lo fa l'app dopo, con
      // POST /work-orders/:id/reassign.
      if (o.assegnaA != null) 'assegnaA': o.assegnaA,
      'squadra': o.squadra,
      'responsabile': o.responsabile,
      'fornitoreEsterno': o.fornitoreEsterno,
      'reperibilita': o.reperibilita,
      'contratto': o.contratto,
      'impiantoDis': o.impiantoDis,
      'ultimoCicloManutenzione': o.ultimoCicloManutenzione,
      'postManut': o.postManut,
      'dataEsec': o.dataEsec?.toIso8601String(),
      'dataInizio': o.dataInizio?.toIso8601String(),
      'accountingSector': o.accountingSector,
      'notes': o.notes,
      // Note SAP (sola lettura) e note aggiunte sul campo: servono a conservare
      // la nota quando l'OdL locale viene riletto dall'outbox (round-trip Hive).
      'noteSap': o.noteSap,
      'noteAggiunte': o.noteAggiunte,
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
      statoSap: _s(j['statoSap']),
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
      centroManut: _s(j['centroManut']),
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
      oraInterventoRichiesta: _s(j['oraInterventoRichiesta']),
      oraInizioGuasto: _s(j['oraInizioGuasto']),
      oraFineGuasto: _s(j['oraFineGuasto']),
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
      'statoSap': a.statoSap,
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
      'centroManut': a.centroManut,
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
      // Il backend legge `materials` (o `materialiUsati`), non `materialsUsed`:
      // usa `materialCode`, `usedQuantity`, `warehouseCode` di ogni riga.
      'materials': e.materials.map(materialUsageToJson).toList(),
      // Esito appuntamento nel nodo `appointment` (chiavi del backend).
      if (e.appointment != null)
        'appointment': {
          'result': e.appointment!.esito,
          'causeCode': e.appointment!.causa,
          'reasonCode': e.appointment!.motivo,
          'customerPresent': e.appointment!.clientePresente == null
              ? null
              : (e.appointment!.clientePresente! ? 'SI' : 'NO'),
          // Solo la data (yyyy-MM-dd), come nel contratto del backend.
          'visitDate': e.appointment!.sopralluogoData
              ?.toIso8601String()
              .substring(0, 10),
          'visitTime': e.appointment!.sopralluogoOra,
          'pickup': e.appointment!.ritiro,
          'delayCauseCode': e.appointment!.causaRitardo,
          'delayReason': e.appointment!.motivoRitardo,
        },
      // Ore per operazione: forma attesa dal backend/cruscotto.
      // Il backend odierno ne somma solo `hours` (oreLavorate); `operation` e
      // `description` servono al cruscotto per la colonna "Ore lavorate" per
      // riga, appena il backend le inoltrerà.
      'hoursWorked': e.hoursWorked
          .map((h) => {
                'operation': h.operation,
                'description': h.description,
                'hours': h.hours,
              })
          .toList(),
      // NUOVO contatore posato (SOST): nodo `newMeter`. Inviato solo se c'è un
      // numero di serie del nuovo contatore.
      if ((e.newMeterSerial ?? '').trim().isNotEmpty)
        'newMeter': {
          'serialNumber': e.newMeterSerial,
          if ((e.newMeterManufacturer ?? '').trim().isNotEmpty)
            'manufacturer': e.newMeterManufacturer,
          'installReading': e.newMeterInstallReading ?? 0,
          if (e.newMeterInstallDate != null)
            'installDate': e.newMeterInstallDate!.toIso8601String(),
        },
      // Spostamento contatore (nodo `contatore`). Inviato solo se il nuovo va in
      // un posto diverso dal vecchio (ubicazione o posizione in batteria).
      if ((e.newMeterLocation ?? '').trim().isNotEmpty ||
          (e.newMeterLocationAdditional ?? '').trim().isNotEmpty ||
          (e.newMeterPosition ?? '').trim().isNotEmpty)
        'contatore': {
          'newLocation': e.newMeterLocation,
          'newLocationAdditional': e.newMeterLocationAdditional,
          if ((e.newMeterPosition ?? '').trim().isNotEmpty)
            'newPosition': e.newMeterPosition,
        },
      // Oggetti del lavoro (mezzi e apparecchiature impegnati): per un automezzo
      // `equipment` è la targa. Il backend li mostra nella tabella Oggetti.
      if (e.objects.isNotEmpty)
        'objects': e.objects
            .map((o) => {
                  'equipment': o.equipment,
                  if (o.description.trim().isNotEmpty) 'description': o.description,
                })
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
      stockPerMagazzino: _stockPerMagazzino(j['stockPerMagazzino']),
    );

/// Giacenza per magazzino: lista `[{warehouseCode, quantity}]` oppure mappa
/// `{W01: 30}`. Assente o illeggibile -> vuota (si usa lo stock unico).
Map<String, num> _stockPerMagazzino(dynamic v) {
  final out = <String, num>{};
  if (v is Map) {
    v.forEach((k, q) {
      final n = _n(q);
      if (n != null) out['$k'] = n;
    });
  } else if (v is List) {
    for (final e in v) {
      if (e is! Map) continue;
      final code = '${e['warehouseCode'] ?? e['code'] ?? ''}'.trim();
      final n = _n(e['quantity'] ?? e['quantita'] ?? e['stock']);
      if (code.isNotEmpty && n != null) out[code] = n;
    }
  }
  return out;
}

Warehouse warehouseFromJson(Map<String, dynamic> j) =>
    Warehouse(code: j['code']?.toString() ?? '', name: j['name'] ?? '');

CodeLabel codeLabelFromJson(Map<String, dynamic> j) =>
    CodeLabel(j['code']?.toString() ?? '', (j['label'] ?? j['descrizione'] ?? '').toString());

// ─── CATALOGHI SELEZIONABILI (dal cruscotto) ─────────────────────────────────

WorkOrderTypeOption workOrderTypeOptionFromJson(Map<String, dynamic> j) =>
    WorkOrderTypeOption(
      code: j['code']?.toString() ?? '',
      label: (j['label'] ?? j['descrizione'] ?? j['code'] ?? '').toString(),
      category: _s(j['category'] ?? j['categoria']),
    );

WorkOrderActivityTemplate workOrderActivityTemplateFromJson(Map<String, dynamic> j) {
  final raw = j['daConfermare'];
  return WorkOrderActivityTemplate(
    woType: (j['woType'] ?? '').toString(),
    tipoAttivita: (j['tipoAttivita'] ?? '').toString(),
    tipoAttivitaDesc: (j['tipoAttivitaDesc'] ?? '').toString(),
    gruppoCicli: (j['gruppoCicli'] ?? '').toString(),
    settoreContabile: (j['settoreContabile'] ?? '').toString(),
    settoreContabileDesc: (j['settoreContabileDesc'] ?? '').toString(),
    daConfermare:
        raw is List ? raw.map((e) => e.toString()).toList() : const [],
    predefinita: j['predefinita'] == true,
  );
}

DynFieldSpec dynFieldSpecFromJson(Map<String, dynamic> j) {
  final rawOptions = j['options'] ?? j['opzioni'];
  return DynFieldSpec(
    key: (j['key'] ?? j['id'] ?? '').toString(),
    label: (j['label'] ?? j['etichetta'] ?? '').toString(),
    type: dynFieldTypeFrom(j['type']?.toString()),
    options: rawOptions is List
        ? rawOptions.map((e) => e.toString()).toList()
        : const [],
    required: j['required'] == true || j['obbligatorio'] == true,
  );
}

// ─── EQUIPMENT ───────────────────────────────────────────────────────────────

Equipment equipmentFromJson(Map<String, dynamic> j) {
  final fonte = j['fonte'];
  return Equipment(
    matricola: j['matricola']?.toString() ?? '',
    barcode: j['barcode']?.toString() ?? '',
    produttore: j['produttore'] ?? '',
    modello: j['modello'] ?? '',
    localita: j['localita'] ?? '',
    comune: j['comune'] ?? '',
    sedeTecnica: j['sedeTecnica'] ?? '',
    dataInstallazione: _date(j['dataInstallazione']),
    stato: j['stato'] ?? '',
    // Dati ricchi della casetta (precompilazione SOST).
    equipment: j['equipment']?.toString() ?? '',
    oggettoAllacciamento: j['oggettoAllacciamento']?.toString() ?? '',
    accountingSector: j['accountingSector']?.toString() ?? '',
    fonteExternalCode:
        fonte is Map ? (fonte['externalCode']?.toString() ?? '') : '',
    meter: meterFromJson(j['meter'] as Map<String, dynamic>?),
    address: j['address'] == null
        ? null
        : addressFromJson(j['address'] as Map<String, dynamic>),
    customer: j['customer'] == null
        ? null
        : customerFromJson(j['customer'] as Map<String, dynamic>),
  );
}

// ─── TECNICO (AppUser) ───────────────────────────────────────────────────────

UserRole _roleFromJson(dynamic v) {
  switch ((v ?? '').toString().toLowerCase()) {
    case 'tecnicosenior':
    case 'senior':
      return UserRole.tecnicoSenior;
    case 'readonly':
    case 'sola lettura':
      return UserRole.readOnly;
    default:
      return UserRole.tecnico;
  }
}

AppUser technicianFromJson(Map<String, dynamic> j) => AppUser(
      cid: j['cid']?.toString() ?? '',
      nome: j['nome'] ?? '',
      cognome: j['cognome'] ?? '',
      email: _s(j['email']),
      role: _roleFromJson(j['role']),
      workCenter: j['workCenter'] ?? '',
      squadra: _s(j['squadra']),
      tecnicoVV: _s(j['tecnicoVV']),
    );
