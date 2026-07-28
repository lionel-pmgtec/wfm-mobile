// Mapper dai record del BACKEND DEL COLLEGA (cruscotto) verso le entità app.
//
// Il backend del collega restituisce i record "SAP-shaped": nomi MAIUSCOLI del
// WSDL (ORDINE, CENTRO_MANUT, INDIRIZZO{VIA,...}, OPERAZIONI[...]) e sotto-nodi
// annidati. Qui li traduciamo nelle entità del dominio app.
//
// Le SCRITTURE restano sul mio middleware (mappers.dart); questo file è SOLO
// per le letture dal cruscotto. Struttura verificata su dati reali il
// 2026-07-27 (vedi docs_sap/SAP_selezione_esempio_2026-07-27.xml).

import '../../domain/entities/entities.dart';

// ─── Helper generici ────────────────────────────────────────────────────────

String? _s(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

String _str(dynamic v) => _s(v) ?? '';

/// Data SAP: "AAAA-MM-GG". Scarta le non valorizzate ("0000-00-00", vuote).
DateTime? _date(dynamic v) {
  final s = _s(v);
  if (s == null || s.startsWith('0000')) return null;
  return DateTime.tryParse(s);
}

double? _numOrNull(dynamic v) {
  final s = _s(v);
  if (s == null) return null;
  return double.tryParse(s.replaceAll(',', '.'));
}

/// Un nodo annidato può arrivare come Map diretta o incapsulata. Restituisce
/// la Map o null.
Map<String, dynamic>? _obj(dynamic v) =>
    v is Map ? v.cast<String, dynamic>() : null;

/// Una tabella annidata SAP può essere `[...]`, `{item: [...]}`, `{item: {...}}`
/// o un singolo oggetto. Normalizza sempre a List di Map.
List<Map<String, dynamic>> _list(dynamic v) {
  dynamic node = v;
  if (node is Map && node.containsKey('item')) node = node['item'];
  if (node == null) return const [];
  if (node is List) {
    return node.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }
  if (node is Map) return [node.cast<String, dynamic>()];
  return const [];
}

// ─── Stato / priorità (stessa logica del middleware) ────────────────────────

/// STATO SAP (flag calcolati, es. "TECO CALP…") -> codice applicativo.
/// Non essendoci tabella di corrispondenza, si riconoscono solo i flag certi.
String _statoApplicativo(String raw) {
  final tokens = raw.toUpperCase().split(RegExp(r'\s+'));
  for (final t in tokens) {
    if (t == 'TECO' || t == 'CHIU') return 'COMPLETATO';
    if (t == 'CANC' || t == 'DLFL') return 'ANNULLATO';
  }
  return 'RICEVUTO';
}

/// PRIORITA (1..4) -> etichetta. Usa PRIORITA_DESC se presente.
String _priorita(dynamic cod, dynamic desc) {
  final d = _s(desc);
  if (d != null) return d;
  switch (_str(cod)) {
    case '1':
    case '2':
      return 'Alta';
    case '3':
      return 'Media';
    case '4':
      return 'Bassa';
    default:
      return '';
  }
}

// ─── Indirizzo / contatore ──────────────────────────────────────────────────

Address? _indirizzo(dynamic v) {
  final m = _obj(v);
  if (m == null) return null;
  final via = _str(m['VIA']);
  final civico = _str(m['CIVICO']);
  final cap = _str(m['CAP']);
  final localita = _str(m['LOCALITA']);
  final provincia = _str(m['PROVINCIA']);
  final lat = _numOrNull(m['LATITUDINE']);
  final lon = _numOrNull(m['LONGITUDINE']);
  final vuoto = via.isEmpty &&
      civico.isEmpty &&
      cap.isEmpty &&
      localita.isEmpty &&
      provincia.isEmpty &&
      lat == null &&
      lon == null;
  if (vuoto) return null;
  return Address(
    street: via,
    streetNumber: civico,
    cap: cap,
    localita: localita,
    city: localita,
    provincia: provincia,
    latitude: lat,
    longitude: lon,
  );
}

Meter? _apparecchiatura(dynamic v) {
  final m = _obj(v);
  if (m == null) return null;
  final matricola = _s(m['NUMERO_SERIE']);
  final brand = _s(m['PRODUTTORE']);
  final lettura = _s(m['LETTURA']);
  final dataLettura = _date(m['DATA_LETTURA']);
  if (matricola == null && brand == null && lettura == null && dataLettura == null) {
    return null;
  }
  return Meter(
    matricola: matricola ?? '',
    brand: brand ?? '',
    lastReading: _numOrNull(lettura),
    lastReadingDate: dataLettura,
  );
}

Operation _operazione(Map<String, dynamic> o, int i) => Operation(
      id: _s(o['OPERAZIONE']) ?? 'OP-$i',
      number: _str(o['OPERAZIONE']),
      codice: _str(o['CHIAVE_CONTR']),
      testoBreve: _str(o['DESCRIZIONE']),
      description: _str(o['DESCRIZIONE']),
      workCenter: _str(o['CENTRO_LAVORO']),
      plannedHours: _numOrNull(o['LAVORO']),
    );

// ─── ORDINE ─────────────────────────────────────────────────────────────────

WorkOrder workOrderFromCruscotto(Map<String, dynamic> j) {
  final stato = _str(j['STATO']);
  final app = _obj(j['APPUNTAMENTO']);
  return WorkOrder(
    externalCode: _str(j['ORDINE']),
    notificationNumberSap: _s(j['AVVISO']),
    avvisoOrigine: _s(j['AVVISO']),
    woType: _str(j['TIPO_ORDINE']),
    woTypeDescription: _str(j['DESCRIZIONE']),
    tipoAttivitaCodice: _s(j['TP_ATT_PM']),
    tipoAttivitaNome: _s(j['TP_ATT_PM_DESC']),
    status: WorkOrderStatus.fromSap(_statoApplicativo(stato)),
    statoSap: _s(j['STATO']),
    priorita: _priorita(j['PRIORITA'], j['PRIORITA_DESC']),
    creatoDa: _s(j['AUTORE']),
    createdAt: _date(j['DATA_CREAZ']),
    centroPianificazione: _str(j['CENTRO_MANUT']),
    appointmentDate: _date(app?['FISSATO_DATA']),
    appointmentStartTime: _str(app?['FISSATO_ORA']).replaceAll(RegExp(r'^:\s*:$'), ''),
    address: _indirizzo(j['INDIRIZZO']) ?? const Address(),
    indirizzoIntervento: _indirizzo(j['INDIRIZZO_LAVORO']),
    sedeTecnica: _str(j['SEDE_TECNICA']),
    equipment: _str(j['EQUIPMENT']),
    impianto: _str(j['IMPIANTO_DISTRIB']),
    meter: _apparecchiatura(j['DATI_APPARECCHIATURA']),
    operations: [
      for (final (i, o) in _list(j['OPERAZIONI']).indexed) _operazione(o, i),
    ],
    contratto: _s(j['CONTRATTO']),
    dataEsec: _date(j['DATA_INIZIO']),
    dataFine: _date(j['DATA_FINE']),
    accountingSector: _str(j['SETTORE_CONTABILE']),
  );
}

/// "CODICE — Testo" del nodo CODIFICA (es. "STRC — STRUMENTALI CONTATORE").
String? _codiceConTesto(Map<String, dynamic>? codifica) {
  if (codifica == null) return null;
  final cod = _s(codifica['CODICE']);
  final testo = _s(codifica['TESTO_CODIFICA']);
  if (cod == null && testo == null) return null;
  if (cod != null && testo != null) return '$cod — $testo';
  return cod ?? testo;
}

// ─── AVVISO ─────────────────────────────────────────────────────────────────

NotificationAvviso avvisoFromCruscotto(Map<String, dynamic> j) {
  final codifica = _obj(j['CODIFICA']);
  final guasto = _obj(j['GUASTO']);
  return NotificationAvviso(
    numeroAvviso: _str(j['AVVISO']),
    descrizione: _str(j['DESCRIZIONE']),
    descrizioneEstesa: _s(codifica?['TESTO_LUNGO']),
    tipo: _str(j['TIPO_AVVISO']),
    priorita: _priorita(j['PRIORITA'], null),
    stato: _str(j['STATO']).isEmpty ? 'Creato' : _str(j['STATO']),
    statoSap: _s(j['STATO']),
    centroManut: _s(j['CENTRO_MANUT']),
    sedeTecnica: _s(j['SEDE_TECNICA']),
    ubicazioneTecnica: _s(j['DESC_SEDE']),
    equipment: _s(j['EQUIPMENT']),
    matricola: _s(j['N_SERIE']),
    creatoDa: _s(j['AUTORE']),
    // Codifica guasto/causa (nodo CODIFICA): codice + testo leggibile.
    codiceGuasto: _codiceConTesto(codifica),
    codiceCausa: _s(codifica?['GRUPPO_CODICI']),
    dataApertura: _date(j['DATA_AVVISO']),
    oraApertura: _s(j['ORA_AVVISO']),
    dataSegnalazione: _date(j['DATA_CREAZ']),
    oraSegnalazione: _s(j['ORA_AVVISO']),
    dataInizioGuasto: _date(guasto?['INIZIO_DATA']),
    dataFineGuasto: _date(guasto?['FINE_DATA']),
    address: _indirizzo(j['INDIRIZZO']) ?? const Address(),
    ordineDiLavoro: _s(j['ORDINE']),
  );
}

// ─── Liste paginate: { total, page, pageSize, items } ───────────────────────

List<Map<String, dynamic>> cruscottoItems(dynamic data) {
  if (data is Map && data['items'] is List) {
    return (data['items'] as List)
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
  }
  if (data is List) {
    return data.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }
  return const [];
}
