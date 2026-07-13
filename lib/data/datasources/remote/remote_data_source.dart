// Contratto della sorgente dati remota (middleware REST/JSON).
// Unica implementazione: HttpRemoteDataSource (parla col Cruscotto/backend).

import '../../../domain/entities/entities.dart';
import '../../../domain/repositories/work_order_repository.dart';

abstract interface class WfmRemoteDataSource {
  // Auth (M1)
  Future<AuthSession> login(String cid, String password);
  Future<void> logout();

  /// Registrazione token push presso il Cruscotto.
  Future<void> registerDeviceToken(String cid, String fcmToken);

  // Work orders (M2/M3/M4/M10)
  Future<List<WorkOrder>> getWorkOrders(WorkOrderFilter filter);
  Future<WorkOrder> getWorkOrderDetail(String externalCode);
  Future<WorkOrder> updateStatus(String code, WorkOrderStatus status, {String? reason, String? note, Geolocation? geolocation});
  Future<WorkOrder> updateWorkOrder(WorkOrder order);
  Future<WorkOrder> createWorkOrder(WorkOrder order);
  Future<void> deleteWorkOrder(String externalCode);

  // Avvisi (M9)
  Future<List<NotificationAvviso>> getAvvisi({String? query});
  Future<NotificationAvviso> getAvvisoDetail(String numero);
  Future<NotificationAvviso> createAvviso(NotificationAvviso avviso);
  Future<WorkOrder> generateWorkOrderFromAvviso(String numero);
  Future<void> deleteAvviso(String numero);

  // Esito (M5)
  Future<String> submitEsito(Esito esito);

  // Attachments (M8)
  Future<List<Attachment>> getAttachments(String workOrderCode);
  Future<Attachment> uploadAttachment(Attachment attachment);
  Future<void> deleteAttachment(String workOrderCode, String attachmentId);

  // Anagrafiche (M7/M11)
  Future<List<MaterialItem>> getMaterials({String? query});
  Future<List<Warehouse>> getWarehouses();
  Future<List<String>> getMeterBrands();
  Future<List<String>> getTamCodes();
  Future<List<CodeLabel>> getCauseCodes();
  Future<List<CodeLabel>> getSolutionCodes();

  /// Ricerca equipment per matricola/barcode (Standalone).
  Future<Equipment?> getEquipment({String? matricola, String? barcode});

  /// Elenco/ricerca tecnici (Cambio CID, riassegnazione OdL).
  Future<List<AppUser>> getTechnicians({String? query});
}
