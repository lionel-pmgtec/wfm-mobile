// Implementazione REST verso il MIDDLEWARE (Dio). Attiva quando
// AppConfig.useMockData == false.
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

  @override
  Future<AppUser> login(String cid, String password) async {
    final r = await _dio.post(_login, data: {'cid': cid, 'password': password});
    final j = r.data as Map<String, dynamic>;
    return AppUser(
      cid: j['cid'] ?? cid.toUpperCase(),
      nome: j['nome'] ?? '',
      cognome: j['cognome'] ?? '',
      email: j['email'],
      role: UserRole.tecnico,
      workCenter: j['workCenter'] ?? '',
      squadra: j['squadra'],
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
  Future<String> submitEsito(Esito esito) async {
    // -> submitEsito (S13 + E55)
    final r = await _dio.post(_esiti, data: esitoToJson(esito));
    return r.data['esitoId']?.toString() ?? '';
  }

  @override
  Future<List<Attachment>> getAttachments(String workOrderCode) async {
    final r = await _dio.get('$_workOrders/$workOrderCode/attachments');
    // Mapping allegati lasciato al backend; per ora lista vuota se assente.
    final list = (r.data['attachments'] as List? ?? const []);
    return list.cast<Map<String, dynamic>>().map((j) {
      return Attachment(
        id: j['id']?.toString() ?? '',
        workOrderCode: workOrderCode,
        type: AttachmentType.documento,
        filePath: j['url'] ?? '',
        fileName: j['fileName'] ?? '',
        capturedAt: DateTime.tryParse(j['capturedAt'] ?? '') ?? DateTime.now(),
        author: j['author'] ?? '',
        uploadStatus: UploadStatus.uploaded,
      );
    }).toList();
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
    await _dio.post('$_esiti/attachments', data: form);
    return attachment.copyWith(uploadStatus: UploadStatus.uploaded);
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
}
