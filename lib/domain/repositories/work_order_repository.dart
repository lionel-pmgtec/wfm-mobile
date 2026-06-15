import '../../core/network/result.dart';
import '../entities/work_order.dart';
import '../entities/enums.dart';
import '../entities/value_objects.dart';

/// Filtri applicabili all'elenco OdL.
class WorkOrderFilter {
  final WorkOrderStatus? status;
  final String? query;       // numero, indirizzo, cliente
  final DateTime? date;      // filtro per data appuntamento
  final String? squadra;     // filtro per squadra
  final String? centroLavoro; // filtro per centro di lavoro
  final String? tecnico;     // filtro per CID tecnico assegnato

  const WorkOrderFilter({
    this.status,
    this.query,
    this.date,
    this.squadra,
    this.centroLavoro,
    this.tecnico,
  });

  WorkOrderFilter copyWith({
    WorkOrderStatus? status,
    String? query,
    DateTime? date,
    String? squadra,
    String? centroLavoro,
    String? tecnico,
    bool clearStatus = false,
    bool clearDate = false,
    bool clearSquadra = false,
    bool clearCentroLavoro = false,
    bool clearTecnico = false,
  }) {
    return WorkOrderFilter(
      status: clearStatus ? null : (status ?? this.status),
      query: query ?? this.query,
      date: clearDate ? null : (date ?? this.date),
      squadra: clearSquadra ? null : (squadra ?? this.squadra),
      centroLavoro: clearCentroLavoro ? null : (centroLavoro ?? this.centroLavoro),
      tecnico: clearTecnico ? null : (tecnico ?? this.tecnico),
    );
  }

  bool get isEmpty =>
      status == null &&
      (query == null || query!.isEmpty) &&
      date == null &&
      (squadra == null || squadra!.isEmpty) &&
      (centroLavoro == null || centroLavoro!.isEmpty) &&
      (tecnico == null || tecnico!.isEmpty);

  int get activeFilterCount {
    int count = 0;
    if (status != null) count++;
    if (query != null && query!.isNotEmpty) count++;
    if (date != null) count++;
    if (squadra != null && squadra!.isNotEmpty) count++;
    if (centroLavoro != null && centroLavoro!.isNotEmpty) count++;
    if (tecnico != null && tecnico!.isNotEmpty) count++;
    return count;
  }
}

abstract interface class WorkOrderRepository {
  Future<Result<List<WorkOrder>>> getWorkOrders({WorkOrderFilter filter});

  Future<Result<WorkOrder>> getWorkOrderDetail(String externalCode);

  /// Cambio di stato (Avvia/Sospendi/Riprendi/Concludi/Annulla) — M4.
  /// `geolocation` opzionale (es. Play/Stop OdL) — registrato dal server come
  /// timbratura di campo per audit/tracciabilità (specifiche §9.1).
  Future<Result<WorkOrder>> updateStatus(
    String externalCode,
    WorkOrderStatus newStatus, {
    String? reason,
    String? note,
    Geolocation? geolocation,
  });

  /// Pausa locale — non invia nulla al server (server vede ancora inEsecuzione).
  Future<Result<WorkOrder>> pauseLocally(String externalCode);

  /// Riprende dalla pausa locale — non invia nulla al server.
  Future<Result<WorkOrder>> resumeFromPause(String externalCode);

  /// Aggiornamento generico (note, ubicazione, materiali...).
  Future<Result<WorkOrder>> updateWorkOrder(WorkOrder order);

  /// Creazione OdL dal campo (M10).
  Future<Result<WorkOrder>> createWorkOrder(WorkOrder order);

  /// Statistiche per la dashboard home.
  Future<Result<Map<WorkOrderStatus, int>>> getStats();
}
