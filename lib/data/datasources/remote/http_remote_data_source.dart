// Implementazione REST verso il MIDDLEWARE (Dio). Unica sorgente dati dell'app.
//
// Ogni endpoint REST è tradotto dal middleware in una chiamata SOAP verso SAP
// (cfr. specifiche §8.1). Mapping endpoint -> WS SOAP indicato nei commenti.

import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';
import '../../../domain/entities/entities.dart';
import '../../../domain/repositories/work_order_repository.dart';
import '../../models/mappers.dart';
import 'remote_data_source.dart';

class HttpRemoteDataSource implements WfmRemoteDataSource {
  final DioClient client;
  HttpRemoteDataSource(this.client);

  Dio get _dio => client.dio;

  // ── Endpoint REST (middleware) ──────────────────────────────────────────
  static const _login = '/auth/login'; // -> WS-Security UsernameToken
  static const _logout = '/auth/logout';
  static const _devices = '/devices'; // registrazione token FCM presso Cruscotto
  static const _workOrders = '/work-orders'; // -> getWorkOrdersByTechnician
  static const _avvisi = '/notifications'; // -> getNotificationsByTechnician
  static const _esiti = '/esiti'; // -> submitEsito
  static const _materials = '/anagrafica/materials'; // -> getMaterials
  static const _warehouses = '/anagrafica/warehouses';
  static const _meterBrands = '/anagrafica/meter-brands';
  static const _tamCodes = '/anagrafica/tam-codes';
  static const _causes = '/anagrafica/causes';
  static const _solutions = '/anagrafica/solutions';
  static const _equipment = '/anagrafica/equipment';
  static const _tecnici = '/anagrafica/tecnici';

  @override
  Future<AuthSession> login(String cid, String password) async {
    final r = await _dio.post(_login, data: {'cid': cid, 'password': password});
    final j = r.data as Map<String, dynamic>;
    final user = AppUser(
      cid: j['cid'] ?? cid.toUpperCase(),
      nome: j['nome'] ?? '',
      cognome: j['cognome'] ?? '',
      email: j['email'],
      role: UserRole.tecnico,
      workCenter: j['workCenter'] ?? '',
      squadra: j['squadra'],
    );
    // Token di sessione emesso dal middleware (Bearer). Scadenza da `expiresAt`
    // (ISO 8601) o `expiresIn` (secondi); fallback alla durata configurata.
    final token = (j['token'] ?? j['accessToken'] ?? '').toString();
    final expiresAt = j['expiresAt'] != null
        ? DateTime.tryParse(j['expiresAt'].toString())
        : (j['expiresIn'] != null
            ? DateTime.now()
                .add(Duration(seconds: (j['expiresIn'] as num).toInt()))
            : null);
    return AuthSession(
      user: user,
      token: token,
      expiresAt:
          expiresAt ?? DateTime.now().add(client.config.sessionDuration),
    );
  }

  @override
  Future<void> logout() async => _dio.post(_logout);

  @override
  Future<void> registerDeviceToken(String cid, String fcmToken) async {
    await _dio.post(_devices, data: {
      'cid': cid,
      'fcmToken': fcmToken,
      'platform': 'android',
    });
  }

  @override
  Future<List<WorkOrder>> getWorkOrders(WorkOrderFilter filter) async {
    final r = await _dio.get(_workOrders, queryParameters: {
      if (filter.status != null) 'status': filter.status!.sapCode,
      if (filter.query != null) 'q': filter.query,
      if (filter.date != null) 'date': filter.date!.toIso8601String(),
    });
    final list = (r.data['workOrders'] as List? ?? r.data as List);
    return list.map((e) => workOrderFromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<WorkOrder> getWorkOrderDetail(String externalCode) async {
    final r = await _dio.get('$_workOrders/$externalCode');
    return workOrderFromJson(r.data as Map<String, dynamic>);
  }

  @override
  Future<WorkOrder> updateStatus(String code, WorkOrderStatus status,
      {String? reason, String? note, Geolocation? geolocation}) async {
    // -> aggiornaStatoOrdineDiLavoro (S51/S13...)
    final r = await _dio.patch('$_workOrders/$code/status', data: {
      'status': status.sapCode,
      'reason': reason,
      'note': note,
      if (geolocation != null)
        'geolocation': {
          'lat': geolocation.latitude,
          'lon': geolocation.longitude,
          'accuracy': geolocation.accuracy,
          'capturedAt': geolocation.capturedAt.toIso8601String(),
        },
    });
    return workOrderFromJson(r.data as Map<String, dynamic>);
  }

  @override
  Future<WorkOrder> updateWorkOrder(WorkOrder order) async {
    final r = await _dio.patch('$_workOrders/${order.externalCode}',
        data: workOrderToJson(order));
    return workOrderFromJson(r.data as Map<String, dynamic>);
  }

  @override
  Future<WorkOrder> createWorkOrder(WorkOrder order) async {
    // -> createWorkOrderFromField (I4)
    final r = await _dio.post(_workOrders, data: workOrderToJson(order));
    return workOrderFromJson(r.data as Map<String, dynamic>);
  }

  @override
  Future<void> deleteWorkOrder(String externalCode) async {
    await _dio.delete('$_workOrders/$externalCode');
  }

  @override
  Future<List<NotificationAvviso>> getAvvisi({String? query}) async {
    final r = await _dio.get(_avvisi, queryParameters: {if (query != null) 'q': query});
    final list = (r.data['notifications'] as List? ?? r.data as List);
    return list.map((e) => avvisoFromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<NotificationAvviso> getAvvisoDetail(String numero) async {
    final r = await _dio.get('$_avvisi/$numero');
    return avvisoFromJson(r.data as Map<String, dynamic>);
  }

  @override
  Future<NotificationAvviso> createAvviso(NotificationAvviso avviso) async {
    // -> creaNotifica
    final r = await _dio.post(_avvisi, data: {
      'descrizione': avviso.descrizione,
      'tipo': avviso.tipo,
      'address': addressToJson(avviso.address),
    });
    return avvisoFromJson(r.data as Map<String, dynamic>);
  }

  @override
  Future<WorkOrder> generateWorkOrderFromAvviso(String numero) async {
    final r = await _dio.post('$_avvisi/$numero/generate-work-order');
    return workOrderFromJson(r.data as Map<String, dynamic>);
  }

  @override
  Future<void> deleteAvviso(String numero) async {
    await _dio.delete('$_avvisi/$numero');
  }

  @override
  Future<String> submitEsito(Esito esito) async {
    // -> submitEsito (S13 + E55)
    final r = await _dio.post(_esiti, data: esitoToJson(esito));
    return r.data['esitoId']?.toString() ?? '';
  }

  @override
  Future<List<Attachment>> getAttachments(String workOrderCode) async {
    final r = await _dio.get('$_workOrders/$workOrderCode/attachments');
    final list = (r.data['attachments'] as List? ?? const []);
    return list.cast<Map<String, dynamic>>().map((j) {
      // Il middleware restituisce una url relativa (/work-orders/.../file):
      // la rendiamo assoluta così Image.network può caricarla.
      final rawUrl = (j['url'] ?? '').toString();
      final fullUrl = rawUrl.isEmpty || rawUrl.startsWith('http')
          ? rawUrl
          : '${client.config.middlewareBaseUrl}$rawUrl';
      return Attachment(
        id: j['id']?.toString() ?? '',
        workOrderCode: workOrderCode,
        type: AttachmentType.documento,
        filePath: fullUrl,
        fileName: j['fileName'] ?? '',
        mimeType: (j['mimeType'] ?? 'image/jpeg').toString(),
        capturedAt: DateTime.tryParse(j['capturedAt'] ?? '') ?? DateTime.now(),
        author: j['author'] ?? '',
        uploadStatus: UploadStatus.uploaded,
      );
    }).toList();
  }

  @override
  Future<void> deleteAttachment(String workOrderCode, String attachmentId) async {
    await _dio.delete('$_workOrders/$workOrderCode/attachments/$attachmentId');
  }

  @override
  Future<Attachment> uploadAttachment(Attachment attachment) async {
    // -> inviaEsitoAllegato (MTOM/XOP lato middleware)
    final form = FormData.fromMap({
      'workOrderCode': attachment.workOrderCode,
      'type': attachment.type.sapCode,
      'file': await MultipartFile.fromFile(attachment.filePath,
          filename: attachment.fileName),
    });
    final r = await _dio.post('$_esiti/attachments', data: form);
    // Adotta l'id assegnato dal middleware così la copia locale e quella remota
    // coincidono (niente doppioni quando la lista fonde locale + remoto).
    final serverId = (r.data is Map) ? r.data['id']?.toString() : null;
    return attachment.copyWith(
      id: serverId ?? attachment.id,
      uploadStatus: UploadStatus.uploaded,
    );
  }

  @override
  Future<List<MaterialItem>> getMaterials({String? query}) async {
    final r = await _dio.get(_materials, queryParameters: {if (query != null) 'q': query});
    return (r.data as List).map((e) => materialItemFromJson(e)).toList();
  }

  @override
  Future<List<Warehouse>> getWarehouses() async {
    final r = await _dio.get(_warehouses);
    return (r.data as List).map((e) => warehouseFromJson(e)).toList();
  }

  @override
  Future<List<String>> getMeterBrands() async {
    final r = await _dio.get(_meterBrands);
    return (r.data as List).map((e) => e.toString()).toList();
  }

  @override
  Future<List<String>> getTamCodes() async {
    final r = await _dio.get(_tamCodes);
    return (r.data as List).map((e) => e.toString()).toList();
  }

  @override
  Future<List<CodeLabel>> getCauseCodes() async {
    final r = await _dio.get(_causes);
    return (r.data as List).map((e) => codeLabelFromJson(e)).toList();
  }

  @override
  Future<List<CodeLabel>> getSolutionCodes() async {
    final r = await _dio.get(_solutions);
    return (r.data as List).map((e) => codeLabelFromJson(e)).toList();
  }

  @override
  Future<Equipment?> getEquipment({String? matricola, String? barcode}) async {
    final r = await _dio.get(_equipment, queryParameters: {
      if (matricola != null && matricola.isNotEmpty) 'matricola': matricola,
      if (barcode != null && barcode.isNotEmpty) 'barcode': barcode,
    });
    if (r.data == null) return null;
    return equipmentFromJson(r.data as Map<String, dynamic>);
  }

  @override
  Future<List<AppUser>> getTechnicians({String? query}) async {
    final r = await _dio.get(_tecnici,
        queryParameters: {if (query != null && query.isNotEmpty) 'q': query});
    return (r.data as List).map((e) => technicianFromJson(e)).toList();
  }
}
