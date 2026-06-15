// Implementazione di test: dati in memoria con ritardi di rete simulati.

import '../../../domain/entities/entities.dart';
import '../../../domain/repositories/work_order_repository.dart';
import '../../mock/mock_data.dart';
import 'remote_data_source.dart';

class MockRemoteDataSource implements WfmRemoteDataSource {
  // Stato in memoria (simula il database SAP).
  final List<WorkOrder> _orders = MockData.workOrders();
  final List<NotificationAvviso> _avvisi = MockData.avvisi();
  int _seq = 90000000;

  Future<void> _delay([int ms = 600]) => Future.delayed(Duration(milliseconds: ms));

  @override
  Future<AppUser> login(String cid, String password) async {
    await _delay(900);
    if (cid.isEmpty || password.isEmpty) {
      throw Exception('Credenziali mancanti');
    }
    return AppUser(
      cid: cid.toUpperCase(),
      nome: 'Marco',
      cognome: 'Vaiotti',
      email: '${cid.toLowerCase()}@wfm.local',
      role: UserRole.tecnico,
      workCenter: 'WC01',
      squadra: 'Squadra Nord',
      tecnicoVV: 'VV-${cid.toUpperCase()}',
    );
  }

  @override
  Future<void> logout() async => _delay(200);

  @override
  Future<void> registerDeviceToken(String cid, String fcmToken) async {
    await _delay(150);
    // No-op in mock: il Cruscotto non esiste, il token viene "accettato".
  }

  @override
  Future<List<WorkOrder>> getWorkOrders(WorkOrderFilter filter) async {
    await _delay(700);
    Iterable<WorkOrder> r = _orders;
    if (filter.status != null) {
      r = r.where((o) => o.status == filter.status);
    }
    if (filter.query != null && filter.query!.trim().isNotEmpty) {
      final q = filter.query!.toLowerCase();
      r = r.where((o) =>
          o.externalCode.toLowerCase().contains(q) ||
          o.address.full.toLowerCase().contains(q) ||
          o.customer.fullName.toLowerCase().contains(q) ||
          o.woTypeDescription.toLowerCase().contains(q));
    }
    if (filter.date != null) {
      final d = filter.date!;
      r = r.where((o) =>
          o.appointmentDate != null &&
          o.appointmentDate!.year == d.year &&
          o.appointmentDate!.month == d.month &&
          o.appointmentDate!.day == d.day);
    }
    if (filter.squadra != null && filter.squadra!.isNotEmpty) {
      final sq = filter.squadra!.toLowerCase();
      r = r.where((o) => o.squadra.toLowerCase().contains(sq));
    }
    if (filter.centroLavoro != null && filter.centroLavoro!.isNotEmpty) {
      final cl = filter.centroLavoro!.toLowerCase();
      r = r.where((o) => o.centroLavoro.toLowerCase().contains(cl));
    }
    if (filter.tecnico != null && filter.tecnico!.isNotEmpty) {
      final t = filter.tecnico!.toLowerCase();
      r = r.where((o) => (o.cidAssegnato ?? '').toLowerCase().contains(t));
    }
    final list = r.toList()
      ..sort((a, b) => (a.appointmentDate ?? DateTime(2100))
          .compareTo(b.appointmentDate ?? DateTime(2100)));
    return list;
  }

  @override
  Future<WorkOrder> getWorkOrderDetail(String externalCode) async {
    await _delay(400);
    return _orders.firstWhere((o) => o.externalCode == externalCode,
        orElse: () => throw Exception('OdL non trovato'));
  }

  @override
  Future<WorkOrder> updateStatus(String code, WorkOrderStatus status,
      {String? reason, String? note, Geolocation? geolocation}) async {
    await _delay(500);
    final i = _orders.indexWhere((o) => o.externalCode == code);
    if (i < 0) throw Exception('OdL non trovato');
    // inPausa è locale: sul mock/server usa il sapCode (IN_ESECUZIONE).
    final serverStatus = status == WorkOrderStatus.inPausa
        ? WorkOrderStatus.inEsecuzione
        : status;
    final updated = _orders[i].copyWith(status: serverStatus, updatedAt: DateTime.now());
    _orders[i] = updated;
    return updated;
  }

  @override
  Future<WorkOrder> updateWorkOrder(WorkOrder order) async {
    await _delay(500);
    final i = _orders.indexWhere((o) => o.externalCode == order.externalCode);
    if (i >= 0) _orders[i] = order;
    return order;
  }

  @override
  Future<WorkOrder> createWorkOrder(WorkOrder order) async {
    await _delay(700);
    final created = order.externalCode.isEmpty
        ? _withCode(order, '${++_seq}')
        : order;
    _orders.add(created);
    return created;
  }

  WorkOrder _withCode(WorkOrder o, String code) => WorkOrder(
        externalCode: code,
        woType: o.woType,
        woTypeDescription: o.woTypeDescription,
        tam: o.tam,
        subTam: o.subTam,
        status: o.status,
        appointmentDate: o.appointmentDate,
        appointmentStartTime: o.appointmentStartTime,
        address: o.address,
        customer: o.customer,
        meter: o.meter,
        accountingSector: o.accountingSector,
        notes: o.notes,
        sedeTecnica: o.sedeTecnica,
        equipment: o.equipment,
        cidAssegnato: o.cidAssegnato,
        localStatus: o.localStatus,
        createdAt: DateTime.now(),
      );

  @override
  Future<List<NotificationAvviso>> getAvvisi({String? query}) async {
    await _delay(600);
    if (query == null || query.trim().isEmpty) return List.of(_avvisi);
    final q = query.toLowerCase();
    return _avvisi
        .where((a) =>
            a.numeroAvviso.toLowerCase().contains(q) ||
            a.descrizione.toLowerCase().contains(q) ||
            a.address.full.toLowerCase().contains(q))
        .toList();
  }

  @override
  Future<NotificationAvviso> getAvvisoDetail(String numero) async {
    await _delay(400);
    return _avvisi.firstWhere((a) => a.numeroAvviso == numero,
        orElse: () => throw Exception('Avviso non trovato'));
  }

  @override
  Future<NotificationAvviso> createAvviso(NotificationAvviso avviso) async {
    await _delay(600);
    _avvisi.add(avviso);
    return avviso;
  }

  @override
  Future<WorkOrder> generateWorkOrderFromAvviso(String numero) async {
    await _delay(800);
    final a = await getAvvisoDetail(numero);
    final now = DateTime.now();
    final cid = a.cidAssegnato ?? 'VAIOTTIM';
    // Tipo OdL derivato dal sottotipo dell'avviso (spec).
    final woType = a.tipo == 'PA'
        ? 'PA'
        : (a.tipo.startsWith('ZF') ? 'ZA01' : 'ZA02');
    // Template operazioni standard. Il tecnico le compila/aggiunge sul campo.
    final ops = <Operation>[
      Operation(
        id: 'OP-${now.millisecondsSinceEpoch}-1',
        number: '0010',
        codice: 'SOPR-001',
        testoBreve: 'Sopralluogo iniziale',
        cid: cid,
        description: 'Verifica del punto di intervento, valutazione tecnica '
            'e identificazione delle attivita necessarie.',
        workCenter: 'WC-AN-01',
        dataInizioPrevista: now,
        dataFinePrevista: now.add(const Duration(hours: 1)),
        plannedHours: 0.5,
      ),
      Operation(
        id: 'OP-${now.millisecondsSinceEpoch}-2',
        number: '0020',
        codice: 'EXEC-001',
        testoBreve: 'Esecuzione intervento',
        cid: cid,
        description: 'Esecuzione delle lavorazioni previste come da spec.',
        workCenter: 'WC-AN-01',
        dataInizioPrevista: now.add(const Duration(hours: 1)),
        dataFinePrevista: now.add(const Duration(hours: 3)),
        plannedHours: 2,
      ),
      Operation(
        id: 'OP-${now.millisecondsSinceEpoch}-3',
        number: '0030',
        codice: 'VRF-001',
        testoBreve: 'Verifica e chiusura',
        cid: cid,
        description: 'Verifica funzionalita, ripristino sito, chiusura OdL.',
        workCenter: 'WC-AN-01',
        dataInizioPrevista: now.add(const Duration(hours: 3)),
        dataFinePrevista: now.add(const Duration(hours: 4)),
        plannedHours: 0.5,
      ),
    ];
    final wo = WorkOrder(
      externalCode: '${++_seq}',
      notificationNumberSap: a.numeroAvviso,
      avvisoOrigine: a.numeroAvviso,
      woType: woType,
      woTypeDescription: a.descrizione,
      tam: woType,
      status: WorkOrderStatus.ricevuto,
      priorita: a.priorita.isEmpty ? 'Media' : a.priorita,
      creatoDa: 'wfm.mobile',
      appointmentDate: now,
      appointmentStartTime:
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
      address: a.address,
      customer: a.customer,
      codiceCliente: a.codiceCliente ?? a.customer.codCli,
      referente: a.referente ?? a.customer.fullName,
      telefonoCliente: a.customer.telefono,
      indirizzoOggetto: a.indirizzoOggetto,
      indirizzoIntervento: a.indirizzoLavoro ?? a.indirizzoOggetto,
      sedeTecnica: a.sedeTecnica ?? '',
      equipment: a.equipment ?? '',
      matricola: a.matricola,
      ubicazione: a.ubicazioneTecnica ?? '',
      impianto: a.impianto ?? '',
      operations: ops,
      accountingSector: 'POT - Servizio acqua potabile',
      cidAssegnato: cid,
      squadra: a.squadra ?? '',
      centroLavoro: a.centroLavoro ?? '',
      contratto: a.contratto,
      reperibilita: a.reperibilita,
      createdAt: now,
    );
    _orders.add(wo);
    return wo;
  }

  @override
  Future<String> submitEsito(Esito esito) async {
    await _delay(900);
    return 'ES-${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  Future<List<Attachment>> getAttachments(String workOrderCode) async {
    await _delay(300);
    return const [];
  }

  @override
  Future<Attachment> uploadAttachment(Attachment attachment) async {
    await _delay(700);
    return attachment.copyWith(uploadStatus: UploadStatus.uploaded);
  }

  @override
  Future<List<MaterialItem>> getMaterials({String? query}) async {
    await _delay(300);
    if (query == null || query.trim().isEmpty) return MockData.materials;
    final q = query.toLowerCase();
    return MockData.materials
        .where((m) =>
            m.materialCode.toLowerCase().contains(q) ||
            m.description.toLowerCase().contains(q) ||
            (m.barcode?.contains(q) ?? false))
        .toList();
  }

  @override
  Future<List<Warehouse>> getWarehouses() async => MockData.warehouses;

  @override
  Future<List<String>> getMeterBrands() async => MockData.meterBrands;

  @override
  Future<List<String>> getTamCodes() async => MockData.tamCodes;

  @override
  Future<List<CodeLabel>> getCauseCodes() async => MockData.causeCodes;

  @override
  Future<List<CodeLabel>> getSolutionCodes() async => MockData.solutionCodes;
}
